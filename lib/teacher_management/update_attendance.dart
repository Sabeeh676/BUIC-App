import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_class_selector.dart';

class UpdateAttendance extends StatefulWidget {
  const UpdateAttendance({super.key});

  @override
  State<UpdateAttendance> createState() => _UpdateAttendanceState();
}

class _UpdateAttendanceState extends State<UpdateAttendance> {
  String? _selectedCourseId;
  String? _selectedClassId;
  List<DocumentSnapshot> _attendanceDocs = [];
  DocumentSnapshot? _selectedRecord;
  Map<String, String> _studentAttendance = {};
  Map<String, String> _studentNames = {};
  bool _isLoading = false;
  bool _isUpdating = false;

  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _topicsController = TextEditingController();

  Future<void> _fetchAttendanceDates() async {
    if (_selectedCourseId == null || _selectedClassId == null) return;

    setState(() {
      _isLoading = true;
      _attendanceDocs = [];
      _selectedRecord = null;
      _studentAttendance = {};
      _studentNames = {};
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('classId', isEqualTo: _selectedClassId)
          .orderBy('date', descending: true)
          .get();
      setState(() {
        _attendanceDocs = snapshot.docs;
      });
    } catch (e) {
      _showError('Failed to fetch attendance dates.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAttendanceRecord(DocumentSnapshot record) async {
    setState(() {
      _isLoading = true;
      _selectedRecord = record;
      _studentAttendance = {};
      _studentNames = {};
    });

    try {
      final data = record.data() as Map<String, dynamic>;
      _remarksController.text = data['remarks'] ?? '';
      _topicsController.text = data['topicsCovered'] ?? '';
      _studentAttendance = Map<String, String>.from(data['students'] ?? {});

      if (_studentAttendance.isNotEmpty) {
        final studentIds = _studentAttendance.keys.toList();
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where(FieldPath.documentId, whereIn: studentIds)
            .get();
        for (var studentDoc in studentsSnapshot.docs) {
          _studentNames[studentDoc.id] = studentDoc.data()['name'] ?? 'Unknown';
        }
      }
    } catch (e) {
      _showError('Failed to load attendance record.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAttendance() async {
    if (_selectedRecord == null) return;

    setState(() => _isUpdating = true);

    try {
      await _selectedRecord!.reference.update({
        'students': _studentAttendance,
        'remarks': _remarksController.text,
        'topicsCovered': _topicsController.text,
      });
      _showSuccess('Attendance updated successfully!');
    } catch (e) {
      _showError('Failed to update attendance.');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Attendance')),
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
                  _fetchAttendanceDates();
                });
              },
            ),
            const Divider(height: 32),
            if (_attendanceDocs.isNotEmpty) _buildDateSelector(),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_selectedRecord != null && !_isLoading)
              Expanded(child: _buildAttendanceForm()),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return DropdownButtonFormField<DocumentSnapshot>(
      decoration: const InputDecoration(
        labelText: 'Select Attendance Date',
        border: OutlineInputBorder(),
      ),
      value: _selectedRecord,
      hint: const Text('Select a date'),
      onChanged: (DocumentSnapshot? newValue) {
        if (newValue != null) {
          _loadAttendanceRecord(newValue);
        }
      },
      items: _attendanceDocs.map((doc) {
        return DropdownMenuItem<DocumentSnapshot>(
          value: doc,
          child: Text(doc['date']),
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceForm() {
    return ListView(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: _remarksController,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _topicsController,
          decoration: const InputDecoration(
            labelText: 'Topics Covered',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Student Attendance:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        ..._studentAttendance.keys.map((studentId) {
          final studentName = _studentNames[studentId] ?? studentId;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(studentName, overflow: TextOverflow.ellipsis),
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'present',
                        groupValue: _studentAttendance[studentId],
                        onChanged: (value) {
                          setState(
                            () => _studentAttendance[studentId] = value!,
                          );
                        },
                      ),
                      const Text('P'),
                      Radio<String>(
                        value: 'absent',
                        groupValue: _studentAttendance[studentId],
                        onChanged: (value) {
                          setState(
                            () => _studentAttendance[studentId] = value!,
                          );
                        },
                      ),
                      const Text('A'),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateAttendance,
          child: _isUpdating
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Update Attendance'),
        ),
      ],
    );
  }
}
