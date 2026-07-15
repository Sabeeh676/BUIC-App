import 'package:buic_app/services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class LeaveStatusPage extends StatefulWidget {
  const LeaveStatusPage({super.key});

  @override
  State<LeaveStatusPage> createState() => _LeaveStatusPageState();
}

class _LeaveStatusPageState extends State<LeaveStatusPage> {
  List<Map<String, dynamic>> attendanceData = [];
  bool isLoading = true;
  String classId = '';
  final dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    await _fetchAttendanceFromCache();
    await fetchAttendanceData();
  }

  Future<void> _fetchAttendanceFromCache() async {
    final cachedData = await dbHelper.getCachedData('attendance');
    if (cachedData.isNotEmpty && mounted) {
      setState(() {
        attendanceData = cachedData;
        isLoading = false;
      });
    }
  }

  Future<void> fetchAttendanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String studentId = user.email!.split('@')[0];
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) return;

      List<String> registeredCourses = List<String>.from(
        studentDoc['registeredCourses'],
      );
      if (registeredCourses.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      classId = studentDoc['class'];

      // Fetch course names and attendance data in parallel
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('courses')
            .where(FieldPath.documentId, whereIn: registeredCourses)
            .get(),
        FirebaseFirestore.instance
            .collection('attendance')
            .where('classId', isEqualTo: classId)
            .where('courseId', whereIn: registeredCourses)
            .get(),
      ]);

      final coursesSnapshot = results[0] as QuerySnapshot;
      final attendanceSnapshot = results[1] as QuerySnapshot;

      final courseNames = {
        for (var doc in coursesSnapshot.docs)
          doc.id: doc['course_name'] ?? 'Unknown Course',
      };

      List<Map<String, dynamic>> fetchedData = [];
      for (var courseId in registeredCourses) {
        final courseName = courseNames[courseId]!;
        int presentHours = 0;
        int absentHours = 0;
        int totalHours = 0;

        for (var doc in attendanceSnapshot.docs) {
          if (doc['courseId'] == courseId) {
            Map<String, dynamic> students = doc['students'];
            String status = students[studentId] ?? 'Unknown';
            int hours = doc['hours'] ?? 0;

            if (status == 'present') {
              presentHours += hours;
            } else if (status == 'absent') {
              absentHours += hours;
            }
            totalHours += hours;
          }
        }

        double attendancePercentage = totalHours > 0
            ? (presentHours / totalHours) * 100
            : 0;

        fetchedData.add({
          'courseId': courseId,
          'subject': courseName,
          'shortName': _getShortName(courseName),
          'presentHours': presentHours,
          'absentHours': absentHours,
          'totalHours': totalHours,
          'attendancePercentage': attendancePercentage,
        });
      }

      if (mounted) {
        setState(() {
          attendanceData = fetchedData;
          isLoading = false;
        });
      }

      await dbHelper.cacheData('attendance', fetchedData);
    } catch (e) {
      print("Error fetching attendance data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getShortName(String courseName) {
    if (courseName.contains('(') && courseName.contains(')')) {
      return courseName.split('(')[1].split(')')[0];
    }
    List<String> words = courseName.split(' ');
    if (words.length > 1) {
      return words.take(3).map((word) => word[0].toUpperCase()).join('');
    }
    return courseName.length > 6 ? courseName.substring(0, 6) : courseName;
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage > 90) return Colors.teal;
    if (percentage > 80) return Colors.green.shade400;
    if (percentage >= 75) return Colors.orange.shade600;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : attendanceData.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: fetchAttendanceData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildChartSection(),
                      _buildAttendanceList(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No attendance records available",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your attendance data will appear here once recorded",
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Subject-wise Attendance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Icon(Icons.bar_chart, color: Colors.grey[600], size: 20),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: attendanceData.length * 50.0,
                child: BarChart(
                  BarChartData(
                    maxY: 101,
                    alignment: BarChartAlignment.center,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final record = attendanceData[group.x.toInt()];
                          return BarTooltipItem(
                            '${record['subject']}\n',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: '${rod.toY.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          interval: 25,
                          getTitlesWidget: (value, meta) {
                            if (value > 100 || value % 25 != 0) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                '${value.toInt()}%',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < attendanceData.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  attendanceData[value.toInt()]['shortName'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (value) =>
                          FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                    ),
                    barGroups: attendanceData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final record = entry.value;
                      final color = _getAttendanceColor(
                        record['attendancePercentage'],
                      );
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: record['attendancePercentage'],
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.7), color],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 25,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(6),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Course Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Icon(Icons.list_alt, color: Colors.grey[600], size: 20),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attendanceData.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[100],
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final record = attendanceData[index];
              return InkWell(
                onTap: () => _showDetailsDialog(context, record['courseId']),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record['subject'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B1B1B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Course ID: ${record['courseId']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getAttendanceColor(
                                    record['attendancePercentage'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${record['attendancePercentage'].toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _getAttendanceColor(
                                      record['attendancePercentage'],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: record['attendancePercentage'] / 100,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getAttendanceColor(
                                record['attendancePercentage'],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatChip(
                            'Present',
                            '${record['presentHours']}h',
                            Colors.green[100]!,
                            Colors.green[700]!,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            'Absent',
                            '${record['absentHours']}h',
                            Colors.red[100]!,
                            Colors.red[700]!,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            'Total',
                            '${record['totalHours']}h',
                            Colors.blue[100]!,
                            Colors.blue[700]!,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    String label,
    String value,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, String courseId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final studentId = user.email!.split('@')[0];

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('courseId', isEqualTo: courseId)
          .get();

      Navigator.pop(context);

      if (attendanceSnapshot.docs.isEmpty) {
        _showInfoDialog(
          context,
          'No Records Found',
          'No attendance records available for this course.',
          Icons.info_outline,
          Colors.blue,
        );
        return;
      }

      List<Map<String, dynamic>> studentAttendanceRecords = [];
      for (var doc in attendanceSnapshot.docs) {
        Map<String, dynamic> students = doc['students'];
        String status = students[studentId] ?? 'Unknown';
        if (status != 'Unknown') {
          studentAttendanceRecords.add({
            'date': doc['date'] ?? 'Unknown Date',
            'hall': doc['hall'] ?? 'N/A',
            'hours': doc['hours'] ?? 0,
            'status': status,
            'remarks': doc['remarks'] ?? 'N/A',
            'topicsCovered': doc['topicsCovered'] ?? 'N/A',
          });
        }
      }

      studentAttendanceRecords.sort((a, b) {
        return b['date'].toString().compareTo(a['date'].toString());
      });

      _showAttendanceDetailsDialog(context, courseId, studentAttendanceRecords);
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      print('Error fetching attendance details: $e');
      _showInfoDialog(
        context,
        'Error',
        'An error occurred while fetching attendance records. Please try again.',
        Icons.error_outline,
        Colors.red,
      );
    }
  }

  void _showInfoDialog(
    BuildContext context,
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAttendanceDetailsDialog(
    BuildContext context,
    String courseId,
    List<Map<String, dynamic>> records,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attendance Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            courseId,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final isPresent = record['status'] == 'present';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPresent
                              ? Colors.green[200]!
                              : Colors.red[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isPresent ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  record['status'].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${record['hours']} hrs',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow('Date', record['date']),
                          _buildDetailRow('Hall', record['hall']),
                          _buildDetailRow('Topics', record['topicsCovered']),
                          if (record['remarks'] != 'N/A')
                            _buildDetailRow('Remarks', record['remarks']),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
