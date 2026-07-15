import 'package:buic_app/custom_dropdown.dart';
import 'package:buic_app/teacher_management/course_class_selector.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  _MarkAttendancePageState createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedHall;
  int selectedHours = 1;
  String remarks = "";
  String topicsCovered = "";
  Map<String, String> studentAttendance = {};
  List<String> studentIds = [];
  bool _isFetchingStudents = false;

  String? _selectedCourseId;
  List<String> _selectedClassIds = [];

  final List<String> halls = ["HL-9", "HL-11", "HL-17", "NC-16"];

  Future<void> fetchStudents() async {
    if (_selectedCourseId == null || _selectedClassIds.isEmpty) {
      setState(() {
        studentIds = [];
        studentAttendance = {};
      });
      return;
    }

    setState(() => _isFetchingStudents = true);

    final classId = _selectedClassIds.first;
    final courseId = _selectedCourseId;

    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists && classDoc.data()!.containsKey('students')) {
        final studentList = List<String>.from(classDoc.data()!['students']);
        setState(() {
          studentIds = studentList;
          studentAttendance = {for (var id in studentIds) id: "absent"};
        });
      } else {
        setState(() {
          studentIds = [];
          studentAttendance = {};
        });
      }
    } catch (e) {
      _showSnackBar('Error fetching students!', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isFetchingStudents = false);
      }
    }
  }

  Future<void> saveAttendance() async {
    if (_selectedCourseId == null || _selectedClassIds.isEmpty) {
      _showSnackBar('Please select course and class.', isError: true);
      return;
    }

    if (selectedHall == null) {
      _showSnackBar('Please select a hall.', isError: true);
      return;
    }

    if (topicsCovered.isEmpty) {
      _showSnackBar('Please enter topics covered.', isError: true);
      return;
    }

    final date = DateTime.now().toIso8601String().split('T')[0];
    final courseId = _selectedCourseId;
    final classId = _selectedClassIds.first;

    try {
      final attendanceData = {
        'date': date,
        'hall': selectedHall,
        'hours': selectedHours,
        'remarks': remarks,
        'topicsCovered': topicsCovered,
        'students': studentAttendance,
        'courseId': courseId,
        'classId': classId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('attendance')
          .add(attendanceData);

      _showSnackBar('Attendance saved successfully!', isError: false);

      // Reset form
      setState(() {
        selectedHall = null;
        selectedHours = 1;
        remarks = "";
        topicsCovered = "";
        studentAttendance = {};
        studentIds = [];
        _selectedCourseId = null;
        _selectedClassIds = [];
      });
    } catch (e) {
      _showSnackBar('Error saving attendance: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _markAllPresent() {
    setState(() {
      for (var id in studentIds) {
        studentAttendance[id] = "present";
      }
    });
  }

  void _markAllAbsent() {
    setState(() {
      for (var id in studentIds) {
        studentAttendance[id] = "absent";
      }
    });
  }

  int get _presentCount =>
      studentAttendance.values.where((v) => v == "present").length;
  int get _absentCount =>
      studentAttendance.values.where((v) => v == "absent").length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Course & Class Selection
                  _buildSectionCard(
                    title: 'Course & Class',
                    icon: Icons.school_outlined,
                    child: CourseClassSelector(
                      multiSelection: false,
                      onSelectionChanged: (courseId, classIds) {
                        setState(() {
                          _selectedCourseId = courseId;
                          _selectedClassIds = classIds;
                          fetchStudents();
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Session Details Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildSectionCard(
                          title: 'Hall',
                          icon: Icons.meeting_room_outlined,
                          child: CustomDropdown(
                            items: halls,
                            hint: 'Select Hall',
                            onSelected: (value) {
                              setState(() {
                                selectedHall = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSectionCard(
                          title: 'Duration',
                          icon: Icons.access_time_outlined,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: selectedHours,
                                isExpanded: true,
                                items: [1, 2, 3].map((hour) {
                                  return DropdownMenuItem<int>(
                                    value: hour,
                                    child: Text(
                                      '$hour Hour${hour > 1 ? 's' : ''}',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedHours = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Topics Covered
                  _buildSectionCard(
                    title: 'Topics Covered',
                    icon: Icons.topic_outlined,
                    child: TextField(
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Enter topics discussed in class...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.teal.shade600,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        topicsCovered = value;
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Remarks (Optional)
                  _buildSectionCard(
                    title: 'Remarks (Optional)',
                    icon: Icons.note_outlined,
                    child: TextField(
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Any additional comments...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.teal.shade600,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 2,
                      onChanged: (value) {
                        remarks = value;
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Student Attendance Section
                  if (_isFetchingStudents)
                    Container(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Colors.teal.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading students...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (studentIds.isNotEmpty) ...[
                    // Attendance Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade600, Colors.teal.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAttendanceStat(
                            icon: Icons.people_outline,
                            value: '${studentIds.length}',
                            label: 'Total',
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildAttendanceStat(
                            icon: Icons.check_circle_outline,
                            value: '$_presentCount',
                            label: 'Present',
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildAttendanceStat(
                            icon: Icons.cancel_outlined,
                            value: '$_absentCount',
                            label: 'Absent',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _markAllPresent,
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Mark All Present'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal.shade700,
                              side: BorderSide(color: Colors.teal.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _markAllAbsent,
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('Mark All Absent'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Students List
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.how_to_reg,
                                  color: Colors.teal.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Mark Student Attendance',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: studentIds.length,
                            separatorBuilder: (context, index) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final studentId = studentIds[index];
                              final isPresent =
                                  studentAttendance[studentId] == "present";

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isPresent
                                      ? Colors.teal.shade100
                                      : Colors.red.shade100,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isPresent
                                          ? Colors.teal.shade700
                                          : Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  studentId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildAttendanceChip(
                                      label: 'Present',
                                      isSelected: isPresent,
                                      color: Colors.teal,
                                      onTap: () {
                                        setState(() {
                                          studentAttendance[studentId] =
                                              "present";
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildAttendanceChip(
                                      label: 'Absent',
                                      isSelected: !isPresent,
                                      color: Colors.red,
                                      onTap: () {
                                        setState(() {
                                          studentAttendance[studentId] =
                                              "absent";
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else if (_selectedCourseId != null &&
                      _selectedClassIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Students Found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This class has no enrolled students',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: Colors.teal.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: studentIds.isNotEmpty ? saveAttendance : null,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Save Attendance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.teal.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAttendanceStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceChip({
    required String label,
    required bool isSelected,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color.shade600 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
