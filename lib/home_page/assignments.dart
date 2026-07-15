import 'package:buic_app/services/student_data_service.dart';
import 'package:buic_app/services/download_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  final _studentDataService = StudentDataService();
  Map<String, List<Map<String, dynamic>>> courseAssignments = {};
  Map<String, String> courseNames = {};
  Map<String, bool> assignmentSubmissions = {};
  List registeredCourses = [];
  bool isLoading = true;
  String classId = '';
  String studentId = '';

  @override
  void initState() {
    super.initState();
    fetchAssignments();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No due date';
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy h:mm a').format(date);
  }

  Future<void> fetchAssignments({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final studentData = await _studentDataService.getStudentData(
        forceRefresh: forceRefresh,
      );
      if (studentData == null ||
          studentData.isEmpty ||
          (studentData['id'] ?? '').isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      studentId = studentData['id'];
      classId = studentData['class'];
      final registeredCourses = List<String>.from(
        studentData['registeredCourses'] ?? [],
      );

      if (studentId.isEmpty || classId.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      if (registeredCourses.isEmpty) {
        setState(() {
          courseAssignments = {};
          isLoading = false;
        });
        return;
      }

      final newCourseNames =
          await _studentDataService.getCourseNames(
            forceRefresh: forceRefresh,
          ) ??
          {};

      // Fetch all assignments for all courses
      final assignmentSnapshots = await Future.wait(
        registeredCourses.map((courseId) {
          return FirebaseFirestore.instance
              .collection('courses')
              .doc(courseId)
              .collection('classes')
              .doc(classId)
              .collection('assignments')
              .orderBy('uploadTime', descending: true)
              .get();
        }),
      );

      // Collect all assignment IDs first
      final allAssignmentIds = <String>[];
      for (var snapshot in assignmentSnapshots) {
        for (var doc in snapshot.docs) {
          allAssignmentIds.add(doc.id);
        }
      }

      // Fetch submission statuses for all assignments in parallel
      final newAssignmentSubmissions = <String, bool>{};
      if (allAssignmentIds.isNotEmpty) {
        final submissionChecks = <Future<Map<String, bool>>>{};

        for (
          var courseIndex = 0;
          courseIndex < registeredCourses.length;
          courseIndex++
        ) {
          final courseId = registeredCourses[courseIndex];
          final snapshot = assignmentSnapshots[courseIndex];

          for (var assignmentDoc in snapshot.docs) {
            submissionChecks.add(
              FirebaseFirestore.instance
                  .collection('courses')
                  .doc(courseId)
                  .collection('classes')
                  .doc(classId)
                  .collection('assignments')
                  .doc(assignmentDoc.id)
                  .collection('submissions')
                  .doc(studentId)
                  .get()
                  .then(
                    (submissionDoc) => {
                      assignmentDoc.id: submissionDoc.exists,
                    },
                  ),
            );
          }
        }

        final results = await Future.wait(submissionChecks);
        for (final result in results) {
          if (result.values.first) {
            newAssignmentSubmissions[result.keys.first] = true;
          }
        }
      }

      // Process assignments
      final newCourseAssignments = <String, List<Map<String, dynamic>>>{};
      for (var course in registeredCourses) {
        newCourseAssignments[course] = [];
      }

      for (var snapshot in assignmentSnapshots) {
        for (var doc in snapshot.docs) {
          final courseId = doc.reference.parent.parent!.parent.parent!.id;
          newCourseAssignments[courseId]!.add({
            'id': doc.id,
            'title': doc['title'],
            'dueDate': doc['dueDate'],
            'totalMarks': doc['totalMarks'],
            'fileUrl': doc['fileUrl'],
            'courseId': courseId,
            'classId': classId,
          });
        }
      }

      // Sort and update state
      var sortedEntries = newCourseAssignments.entries.toList()
        ..sort((a, b) {
          bool aHasAssignments = a.value.isNotEmpty;
          bool bHasAssignments = b.value.isNotEmpty;
          if (aHasAssignments && !bHasAssignments) return -1;
          if (!aHasAssignments && bHasAssignments) return 1;
          return 0;
        });
      setState(() {
        courseNames = newCourseNames;
        courseAssignments = Map.fromEntries(sortedEntries);
        assignmentSubmissions = newAssignmentSubmissions;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching assignments: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching assignments: ${e.toString()}'),
          ),
        );
      }
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

  Future<void> submitAssignment(Map<String, dynamic> assignment) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'ppt', 'pptx', 'doc'],
      );

      if (result != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D7E75)),
            );
          },
        );

        final platformFile = result.files.first;
        final filePath = platformFile.path;

        if (filePath == null) {
          // Handle the error case where the file path is not available
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get file path. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final fileToUpload = File(filePath);
        final storageRef = FirebaseStorage.instance.ref().child(
          'submissions/${assignment['courseId']}/${assignment['id']}/$studentId/${platformFile.name}',
        );
        await storageRef.putFile(fileToUpload);
        final fileUrl = await storageRef.getDownloadURL();

        final studentData = await _studentDataService.getStudentData();
        final studentName = studentData?['name'] ?? 'Unknown Student';

        // Save submission in Firestore
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(assignment['courseId'])
            .collection('classes')
            .doc(assignment['classId'])
            .collection('assignments')
            .doc(assignment['id'])
            .collection('submissions')
            .doc(studentId)
            .set({
              'fileUrl': fileUrl,
              'fileName': platformFile.name,
              'submittedAt': FieldValue.serverTimestamp(),
              'studentId': studentId,
              'studentName': studentName,
              'marksObtained': null, // Initialize marks as null
            });

        // Close loading dialog
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Update submission status
        setState(() {
          assignmentSubmissions[assignment['id']] = true;
        });
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting assignment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String getRemainingTime(Timestamp? dueDate) {
    if (dueDate == null) return '';

    final now = DateTime.now();
    final due = dueDate.toDate();

    if (now.isAfter(due)) {
      return 'Overdue';
    }

    final difference = due.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} left';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes != 1 ? 's' : ''} left';
    }
  }

  Color getStatusColor(Timestamp? dueDate, bool submitted) {
    if (submitted) return Colors.green;
    if (dueDate == null) return Colors.grey;

    final now = DateTime.now();
    final due = dueDate.toDate();

    if (now.isAfter(due)) {
      return Colors.red;
    }

    final difference = due.difference(now);

    if (difference.inDays <= 1) {
      return Colors.orange;
    } else {
      return const Color(0xFF0D7E75);
    }
  }

  // New state variables for downloads
  final DownloadService _downloadService = DownloadService();
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloaded = {};

  Future<void> _checkIfDownloaded(
      String courseName, String fileName, String assignmentId) async {
    final path = await _downloadService.getDownloadPath(
        courseName, 'Assignments', fileName);
    final exists = await _downloadService.fileExists(path);
    setState(() {
      _isDownloaded[assignmentId] = exists;
    });
  }

  Future<void> _downloadAssignment(
      String url, String courseName, String assignmentId) async {
    final fileName =
        '${assignmentId}_${url.split('/').last.split('?').first}';
    final path = await _downloadService.getDownloadPath(
        courseName, 'Assignments', fileName);

    if (await _downloadService.fileExists(path)) {
      OpenFile.open(path);
      return;
    }

    setState(() {
      _downloadProgress[assignmentId] = 0.0;
    });

    try {
      await _downloadService.downloadFile(
        url: url,
        courseName: courseName,
        category: 'Assignments',
        fileName: fileName,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[assignmentId] = progress;
          });
        },
      );
      setState(() {
        _downloadProgress.remove(assignmentId);
        _isDownloaded[assignmentId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      OpenFile.open(path);
    } catch (e) {
      setState(() {
        _downloadProgress.remove(assignmentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Assignments',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        backgroundColor: const Color(0xFF0D7E75),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => fetchAssignments(forceRefresh: true),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D7E75)),
            )
          : RefreshIndicator(
              color: const Color(0xFF0D7E75),
              onRefresh: () => fetchAssignments(forceRefresh: true),
              child: courseAssignments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No courses available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: courseAssignments.entries.length,
                      itemBuilder: (context, index) {
                        final entry = courseAssignments.entries.elementAt(
                          index,
                        );
                        final courseId = entry.key;
                        final courseName =
                            courseNames[courseId] ?? "Unnamed Course";
                        final assignments = entry.value;

                        // Calculate stats
                        int totalAssignments = assignments.length;
                        int submittedCount = 0;
                        int lateCount = 0;

                        for (var assignment in assignments) {
                          final bool submitted =
                              assignmentSubmissions[assignment['id']] ?? false;
                          final bool overdue =
                              assignment['dueDate'] != null &&
                              DateTime.now().isAfter(
                                (assignment['dueDate'] as Timestamp).toDate(),
                              );

                          if (submitted) {
                            submittedCount++;
                          } else if (overdue) {
                            lateCount++;
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.15),
                                spreadRadius: 2,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Course header
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF0D7E75),
                                        const Color(
                                          0xFF0D7E75,
                                        ).withOpacity(0.8),
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              courseName,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$totalAssignments Assignment${totalAssignments != 1 ? 's' : ''}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (totalAssignments > 0) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _buildProgressIndicator(
                                              'Submitted',
                                              submittedCount,
                                              totalAssignments,
                                              Colors.green,
                                            ),
                                            const SizedBox(width: 12),
                                            _buildProgressIndicator(
                                              'Pending',
                                              totalAssignments -
                                                  submittedCount -
                                                  lateCount,
                                              totalAssignments,
                                              const Color(0xFF0D7E75),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildProgressIndicator(
                                              'Late',
                                              lateCount,
                                              totalAssignments,
                                              Colors.red,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Assignments content
                                assignments.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(20),
                                        alignment: Alignment.center,
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.assignment_outlined,
                                              size: 50,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'No assignments available yet',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        itemCount: assignments.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: Color(0xFFEEEEEE),
                                            ),
                                        itemBuilder: (context, assignmentIndex) {
                                          final assignment =
                                              assignments[assignmentIndex];
                                          final dueDate =
                                              assignment['dueDate']
                                                  as Timestamp?;
                                          final isOverdue =
                                              dueDate != null &&
                                              DateTime.now().isAfter(
                                                dueDate.toDate(),
                                              );
                                          final hasSubmission =
                                              assignmentSubmissions[assignment['id']] ??
                                              false;

                                          final remainingTime =
                                              getRemainingTime(dueDate);
                                          final statusColor = getStatusColor(
                                            dueDate,
                                            hasSubmission,
                                          );

                                          return ExpansionTile(
                                            tilePadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 8,
                                                ),
                                            leading: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  hasSubmission
                                                      ? Icons.check_circle
                                                      : isOverdue
                                                      ? Icons.warning_rounded
                                                      : Icons.assignment,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              assignment['title'],
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2D3142),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              'Due: ${formatTimestamp(dueDate)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isOverdue
                                                    ? Colors.red
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    hasSubmission
                                                        ? 'Submitted'
                                                        : isOverdue
                                                        ? 'Overdue'
                                                        : remainingTime,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Marks: ${assignment['totalMarks']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            childrenPadding:
                                                const EdgeInsets.only(
                                                  left: 20,
                                                  right: 20,
                                                  bottom: 20,
                                                ),
                                            children: [
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildDownloadButton(
                                                      assignment,
                                                      courseName,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              if (!isOverdue && !hasSubmission)
                                                ElevatedButton.icon(
                                                  onPressed: () =>
                                                      submitAssignment(
                                                        assignment,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF3E64FF),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    minimumSize: const Size(
                                                      double.infinity,
                                                      50,
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.upload_file,
                                                  ),
                                                  label: const Text(
                                                    'Submit Assignment',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                )
                                              else if (hasSubmission)
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.green
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.check_circle,
                                                        color: Colors.green,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      const Expanded(
                                                        child: Text(
                                                          'You have submitted this assignment',
                                                          style: TextStyle(
                                                            color: Colors.green,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else if (isOverdue)
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.red
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.warning_rounded,
                                                        color: Colors.red,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      const Expanded(
                                                        child: Text(
                                                          'Deadline has passed. Contact your instructor if you still need to submit.',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildProgressIndicator(
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '$count/$total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                height: 4,
                width: percentage > 0
                    ? (percentage / 100) *
                          (MediaQuery.of(context).size.width - 76) /
                          3
                    : 0,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
      Map<String, dynamic> assignment, String courseName) {
    final assignmentId = assignment['id'] as String;
    final isDownloading = _downloadProgress.containsKey(assignmentId);
    final isDownloaded = _isDownloaded[assignmentId] ?? false;

    // Check download status when building the widget
    _checkIfDownloaded(courseName,
        '${assignmentId}_${assignment['fileUrl'].split('/').last.split('?').first}',
        assignmentId);

    if (isDownloading) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: _downloadProgress[assignmentId],
            backgroundColor: Colors.grey[300],
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF0D7E75)),
          ),
          const SizedBox(height: 8),
          Text(
              'Downloading... ${(_downloadProgress[assignmentId]! * 100).toStringAsFixed(0)}%'),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _downloadAssignment(
          assignment['fileUrl'], courseName, assignmentId),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDownloaded ? Colors.green : const Color(0xFF0D7E75),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
      ),
      icon: Icon(isDownloaded ? Icons.open_in_new : Icons.download_rounded),
      label: Text(
        isDownloaded ? 'Open File' : 'Download Assignment',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
