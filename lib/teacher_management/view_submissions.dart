import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewSubmissions extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String classId;

  const ViewSubmissions({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.classId,
  });

  @override
  State<ViewSubmissions> createState() => _ViewSubmissionsState();
}

class _ViewSubmissionsState extends State<ViewSubmissions> {
  late Future<Map<String, dynamic>> dataFuture;
  final Map<String, TextEditingController> marksControllers = {};

  @override
  void initState() {
    super.initState();
    dataFuture = fetchAssignmentAndSubmissions(
      widget.courseId,
      widget.classId,
      widget.assignmentId,
    );
  }

  @override
  void dispose() {
    for (var controller in marksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> fetchAssignmentAndSubmissions(
    String courseId,
    String classId,
    String assignmentId,
  ) async {
    try {
      final assignmentDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .collection('assignments')
          .doc(assignmentId)
          .get();

      if (!assignmentDoc.exists) {
        throw Exception('Assignment document not found.');
      }

      final totalMarks = assignmentDoc.data()?['totalMarks'] ?? 100;

      final submissionsQuery = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .collection('assignments')
          .doc(assignmentId)
          .collection('submissions')
          .get();

      final submissions = submissionsQuery.docs.map((doc) {
        final data = doc.data();
        final studentId = doc.id;

        // Initialize controller for each submission
        marksControllers[studentId] = TextEditingController(
          text: data['marksObtained']?.toString() ?? '',
        );

        return {
          'studentId': studentId,
          'fileUrl': data['fileUrl'] ?? '',
          'fileName': data['fileName'] ?? 'No name',
          'studentName': data['studentName'] ?? 'Unknown Student',
          'submittedAt': data['submittedAt'], // Keep as Timestamp or null
          'marksObtained': data['marksObtained'],
        };
      }).toList();

      // Sort by submission time, newest first
      submissions.sort((a, b) {
        final aTime = a['submittedAt'] as Timestamp?;
        final bTime = b['submittedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return {'totalMarks': totalMarks, 'submissions': submissions};
    } catch (e) {
      print("Error fetching submissions data: $e");
      // Rethrow a more user-friendly error to be caught by the FutureBuilder
      throw Exception('Failed to load submission data.');
    }
  }

  Future<void> downloadFile(String fileUrl) async {
    final Uri url = Uri.parse(fileUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not download file')));
    }
  }

  Future<void> saveMarksToFirestore() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var studentId in marksControllers.keys) {
        final marksText = marksControllers[studentId]!.text;
        final marks = num.tryParse(marksText); // Use num for flexibility

        // Only update if there's a valid number
        if (marks != null) {
          final submissionRef = FirebaseFirestore.instance
              .collection('courses')
              .doc(widget.courseId)
              .collection('classes')
              .doc(widget.classId)
              .collection('assignments')
              .doc(widget.assignmentId)
              .collection('submissions')
              .doc(studentId);

          batch.update(submissionRef, {'marksObtained': marks});
        }
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marks saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error saving marks: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save marks: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Submissions'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 50),
                  const SizedBox(height: 10),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No data available.'));
          }

          final data = snapshot.data!;
          final totalMarks = data['totalMarks'];
          final submissions = data['submissions'] as List<Map<String, dynamic>>;

          if (submissions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No submissions yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header with total marks
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Text(
                  'Total Marks: $totalMarks',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              // Submissions list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final submission = submissions[index];
                    return _buildSubmissionCard(submission, totalMarks);
                  },
                ),
              ),
              // Save button bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton.icon(
                    onPressed: saveMarksToFirestore,
                    icon: const Icon(Icons.save),
                    label: const Text('Save All Marks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission, num totalMarks) {
    final marksController = marksControllers[submission['studentId']]!;
    final submittedAt = submission['submittedAt'] as Timestamp?;
    final formattedDate = submittedAt != null
        ? DateFormat('MMM dd, yyyy hh:mm a').format(submittedAt.toDate())
        : 'Not available';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_outline, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission['studentName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'ID: ${submission['studentId']}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'Submitted: $formattedDate',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () => downloadFile(submission['fileUrl']),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      submission['fileName'],
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  flex: 2,
                  child: TextField(
                    controller: marksController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Marks',
                      suffixText: '/ $totalMarks',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
