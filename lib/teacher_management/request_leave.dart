import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestLeave extends ConsumerStatefulWidget {
  const RequestLeave({super.key});

  @override
  RequestLeaveState createState() => RequestLeaveState();
}

class RequestLeaveState extends ConsumerState<RequestLeave> {
  final int totalLeaveAllowed = 8;
  int usedLeaveDays = 0;
  int availableLeaveDays = 8;

  String? selectedSubject;
  List<DateTime?> _selectedDates = [];

  final TextEditingController _purposeController = TextEditingController();

  final List<String> leaveSubjects = [
    'Sick Leave',
    'Casual Leave',
    'Earned Leave',
    'Maternity Leave',
    'Paternity Leave',
    'Unpaid Leave',
  ];

  Future<void> storeLeaveRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _showSnackBar('You must be logged in.', isError: true);
      return;
    }

    if (selectedSubject == null ||
        _selectedDates.length < 2 ||
        _selectedDates[0] == null ||
        _selectedDates[1] == null ||
        _purposeController.text.isEmpty) {
      _showSnackBar('Please fill all fields correctly.', isError: true);
      return;
    }

    if (availableLeaveDays < 0) {
      _showSnackBar('You have exceeded your leave balance.', isError: true);
      return;
    }

    try {
      final teacherQuery = await FirebaseFirestore.instance
          .collection('teachers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (teacherQuery.docs.isEmpty) {
        throw Exception("Teacher data not found for the logged-in user.");
      }
      final teacherDoc = teacherQuery.docs.first;
      final teacherId = teacherDoc.id;
      final teacherName = teacherDoc.data()['name'] ?? 'N/A';

      DateTime startDate = _selectedDates[0]!;
      DateTime endDate = _selectedDates[1]!;

      Map<String, dynamic> leaveRequestData = {
        'teacherId': teacherId,
        'teacherName': teacherName,
        'subject': selectedSubject,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'purpose': _purposeController.text,
        'status': 'Pending',
        'requestedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('leaveRequests')
          .add(leaveRequestData);

      _showSnackBar('Leave request submitted successfully!', isError: false);

      setState(() {
        selectedSubject = null;
        _selectedDates = [];
        _purposeController.clear();
        usedLeaveDays = 0;
        availableLeaveDays = totalLeaveAllowed;
      });
    } catch (e) {
      _showSnackBar('Error submitting leave request: $e', isError: true);
    }
  }

  void _calculateLeaveDays() {
    if (_selectedDates.length == 2 &&
        _selectedDates[0] != null &&
        _selectedDates[1] != null) {
      DateTime startDate = _selectedDates[0]!;
      DateTime endDate = _selectedDates[1]!;
      usedLeaveDays = endDate.difference(startDate).inDays + 1;
      availableLeaveDays = totalLeaveAllowed - usedLeaveDays;
    } else {
      usedLeaveDays = 0;
      availableLeaveDays = totalLeaveAllowed;
    }
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Request Leave'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Leave Balance Summary Card
                Container(
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
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLeaveStatItem(
                        icon: Icons.event_available,
                        value: '$totalLeaveAllowed',
                        label: 'Total Days',
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _buildLeaveStatItem(
                        icon: Icons.event_busy,
                        value: '$usedLeaveDays',
                        label: 'Used',
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _buildLeaveStatItem(
                        icon: Icons.event_note,
                        value: '$availableLeaveDays',
                        label: 'Available',
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Leave Type Selection
                _buildSectionCard(
                  title: 'Leave Type',
                  icon: Icons.category_outlined,
                  child: DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: InputDecoration(
                      hintText: 'Select leave type',
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: leaveSubjects.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedSubject = newValue;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Date Selection
                _buildSectionCard(
                  title: 'Select Dates',
                  icon: Icons.date_range,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: CalendarDatePicker2(
                          config: CalendarDatePicker2Config(
                            calendarType: CalendarDatePicker2Type.range,
                            selectedDayHighlightColor: availableLeaveDays >= 0
                                ? Colors.teal.shade600
                                : Colors.red.shade600,
                            weekdayLabels: [
                              'Sun',
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                            ],
                            weekdayLabelTextStyle: TextStyle(
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            firstDayOfWeek: 1,
                            controlsHeight: 50,
                            controlsTextStyle: TextStyle(
                              color: Colors.teal.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            dayTextStyle: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.normal,
                            ),
                            disabledDayTextStyle: const TextStyle(
                              color: Colors.grey,
                            ),
                            selectableDayPredicate: (day) => !day.isBefore(
                              DateTime.now().subtract(const Duration(days: 1)),
                            ),
                          ),
                          value: _selectedDates,
                          onValueChanged: (dates) {
                            setState(() {
                              _selectedDates = dates;
                              _calculateLeaveDays();
                            });
                          },
                        ),
                      ),
                      if (_selectedDates.length == 2 &&
                          _selectedDates[0] != null &&
                          _selectedDates[1] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: availableLeaveDays >= 0
                                ? Colors.teal.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: availableLeaveDays >= 0
                                  ? Colors.teal.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: availableLeaveDays >= 0
                                    ? Colors.teal.shade700
                                    : Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'From ${_selectedDates[0]!.toLocal().toString().split(' ')[0]} to ${_selectedDates[1]!.toLocal().toString().split(' ')[0]}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: availableLeaveDays >= 0
                                        ? Colors.teal.shade900
                                        : Colors.red.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Approver Information
                _buildSectionCard(
                  title: 'Approver',
                  icon: Icons.person_outline,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To. Head of Department',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Chief Executive Officer',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Purpose Field
                _buildSectionCard(
                  title: 'Purpose / Comments',
                  icon: Icons.comment_outlined,
                  child: TextField(
                    controller: _purposeController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Please provide reason for leave request...',
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
                  ),
                ),

                const SizedBox(height: 32),

                // Submit Button
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
                    onPressed: storeLeaveRequest,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Submit Request',
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
    );
  }

  Widget _buildLeaveStatItem({
    required IconData icon,
    required String value,
    required String label,
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 26 : 24,
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

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }
}
