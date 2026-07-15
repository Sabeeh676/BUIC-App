import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_class_selector.dart';

class ViewAttendance extends StatefulWidget {
  const ViewAttendance({super.key});

  @override
  State<ViewAttendance> createState() => _ViewAttendanceState();
}

class _ViewAttendanceState extends State<ViewAttendance> {
  String? _selectedCourseId;
  String? _selectedClassId;
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = false;

  Future<void> _fetchAttendanceRecords() async {
    if (_selectedCourseId == null || _selectedClassId == null) {
      setState(() => _attendanceRecords = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('classId', isEqualTo: _selectedClassId)
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> records = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final studentStatusMap = Map<String, String>.from(
          data['students'] ?? {},
        );

        // Fetch student names
        Map<String, String> studentNames = {};
        if (studentStatusMap.isNotEmpty) {
          final studentIds = studentStatusMap.keys.toList();
          final studentsSnapshot = await FirebaseFirestore.instance
              .collection('students')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get();
          for (var studentDoc in studentsSnapshot.docs) {
            studentNames[studentDoc.id] =
                studentDoc.data()['name'] ?? 'Unknown';
          }
        }

        records.add({
          'id': doc.id,
          'date': data['date'],
          'hours': data['hours'],
          'topicsCovered': data['topicsCovered'],
          'students': studentStatusMap,
          'studentNames': studentNames,
        });
      }

      setState(() {
        _attendanceRecords = records;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching attendance: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CourseClassSelector(
              multiSelection: false,
              onSelectionChanged: (courseId, classIds) {
                setState(() {
                  _selectedCourseId = courseId;
                  _selectedClassId = classIds.isNotEmpty
                      ? classIds.first
                      : null;
                  _fetchAttendanceRecords();
                });
              },
            ),
            const Divider(height: 32),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_attendanceRecords.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _attendanceRecords.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceRecords[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text(
                          'Date: ${record['date']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${record['hours']} hour(s) - ${record['students'].length} students',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Topics Covered: ${record['topicsCovered'] ?? 'N/A'}',
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Student Status:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                ...record['students'].entries.map((entry) {
                                  final studentId = entry.key;
                                  final status = entry.value;
                                  final studentName =
                                      record['studentNames'][studentId] ??
                                      studentId;
                                  return ListTile(
                                    title: Text(studentName),
                                    trailing: Text(
                                      status,
                                      style: TextStyle(
                                        color: status == 'present'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Please select a course and class to view attendance, or no records found.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
