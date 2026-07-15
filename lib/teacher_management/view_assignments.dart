import 'package:buic_app/providers.dart';
import 'package:buic_app/teacher_management/view_submissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewAssignments extends ConsumerStatefulWidget {
  const ViewAssignments({super.key});

  @override
  _ViewAssignmentsState createState() => _ViewAssignmentsState();
}

class _ViewAssignmentsState extends ConsumerState<ViewAssignments> {
  Map<String, List<Map<String, dynamic>>> assignmentsByCourse = {};
  Map<String, String> courseNames =
      {}; // To store courseId to course_name mapping
  bool isLoading = true; // Track loading state

  Future<void> fetchAllAssignments() async {
    final teacherId = ref.read(teacherIdProvider);

    if (teacherId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Fetch teacher's class-course map
    final teacherDoc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .get();

    if (!teacherDoc.exists) {
      setState(() {
        isLoading = false; // Stop loading
      });
      return;
    }

    final classCourseMap =
        teacherDoc.data()?['class_course'] as Map<String, dynamic>?;
    if (classCourseMap == null || classCourseMap.isEmpty) {
      setState(() {
        isLoading = false; // Stop loading
      });
      return;
    }

    Map<String, List<Map<String, dynamic>>> tempAssignmentsByCourse = {};

    for (String classSection in classCourseMap.keys) {
      List<String> courseIds = List<String>.from(classCourseMap[classSection]);

      for (String courseId in courseIds) {
        final assignmentSnapshot = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .collection('classes')
            .doc(classSection)
            .collection('assignments')
            .orderBy('uploadTime', descending: true)
            .get();

        // Fetch course details if not already fetched
        if (!courseNames.containsKey(courseId)) {
          final courseDoc = await FirebaseFirestore.instance
              .collection('courses')
              .doc(courseId)
              .get();

          if (courseDoc.exists) {
            courseNames[courseId] =
                courseDoc.data()?['course_name'] ?? 'Unknown Course';
          }
        }

        for (var doc in assignmentSnapshot.docs) {
          Map<String, dynamic> assignmentData = doc.data();
          assignmentData['id'] = doc.id;
          assignmentData['course_id'] = courseId;
          assignmentData['class_section'] = classSection;

          // Add assignment to the course
          if (!tempAssignmentsByCourse.containsKey(courseId)) {
            tempAssignmentsByCourse[courseId] = [];
          }
          tempAssignmentsByCourse[courseId]?.add(assignmentData);
        }
      }
    }

    setState(() {
      assignmentsByCourse = tempAssignmentsByCourse;
      isLoading = false; // Stop loading
    });
  }

  Future<void> editAssignment(Map<String, dynamic> assignment) async {
    final titleController = TextEditingController(text: assignment['title']);
    final totalMarksController = TextEditingController(
      text: assignment['totalMarks'].toString(),
    );
    final dueDateController = TextEditingController(
      text: assignment['dueDate'] != null
          ? DateFormat(
              'yyyy-MM-dd',
            ).format((assignment['dueDate'] as Timestamp).toDate())
          : '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Assignment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                style: TextStyle(color: Colors.black),
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                style: TextStyle(color: Colors.black),
                controller: totalMarksController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Marks',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                style: TextStyle(color: Colors.black),
                controller: dueDateController,
                decoration: const InputDecoration(
                  labelText: 'Due Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final updatedData = {
                'title': titleController.text,
                'totalMarks': int.tryParse(totalMarksController.text) ?? 0,
                'dueDate': dueDateController.text.isNotEmpty
                    ? Timestamp.fromDate(DateTime.parse(dueDateController.text))
                    : null,
                'uploadTime': Timestamp.now(), // Update upload time
              };

              // Update in Firestore
              await FirebaseFirestore.instance
                  .collection('courses')
                  .doc(assignment['course_id'])
                  .collection('classes')
                  .doc(assignment['class_section'])
                  .collection('assignments')
                  .doc(assignment['id'])
                  .update(updatedData);

              fetchAllAssignments();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteAssignment(Map<String, dynamic> assignment) async {
    final confirmation = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: const Text('Are you sure you want to delete this assignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmation == true) {
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(assignment['course_id'])
          .collection('classes')
          .doc(assignment['class_section'])
          .collection('assignments')
          .doc(assignment['id'])
          .delete();

      fetchAllAssignments();
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

  @override
  void initState() {
    super.initState();
    fetchAllAssignments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
        title: const Text(
          'View Assignments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : assignmentsByCourse.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined,
                          size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No assignments found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: assignmentsByCourse.keys.length,
                  itemBuilder: (context, index) {
                    final courseId = assignmentsByCourse.keys.elementAt(index);
                    final courseAssignments = assignmentsByCourse[courseId]!;
                    final courseName = courseNames[courseId] ?? 'Unknown Course';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              color: Colors.teal.withOpacity(0.1),
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                courseName,
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...courseAssignments.map((assignment) {
                              return _buildAssignmentTile(assignment);
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildAssignmentTile(Map<String, dynamic> assignment) {
    final dueDate = assignment['dueDate'] as Timestamp?;
    final formattedDueDate = dueDate != null
        ? DateFormat('MMM dd, yyyy').format(dueDate.toDate())
        : 'No due date';

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment['title'] ?? 'Untitled Assignment',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Due: $formattedDueDate',
          ),
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.score_outlined,
            'Marks: ${assignment['totalMarks']}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewSubmissions(
                          courseId: assignment['course_id'],
                          classId: assignment['class_section'],
                          assignmentId: assignment['id'],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Submissions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Action buttons
              IconButton(
                icon: const Icon(Icons.download_outlined, color: Colors.green),
                onPressed: () => downloadFile(assignment['fileUrl']),
                tooltip: 'Download Assignment',
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                onPressed: () => editAssignment(assignment),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => deleteAssignment(assignment),
                tooltip: 'Delete',
              ),
            ],
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 14, color: Colors.grey[800]),
        ),
      ],
    );
  }
}
