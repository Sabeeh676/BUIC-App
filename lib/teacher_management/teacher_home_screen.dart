import 'package:buic_app/home_page/news_event.dart';
import 'package:buic_app/teacher_management/teacher_profile_page.dart';
import 'package:buic_app/providers.dart';
import 'package:buic_app/teacher_management/leave_report.dart';
import 'package:buic_app/teacher_management/manage_midterm_page.dart';
import 'package:buic_app/teacher_management/manage_project_page.dart';
import 'package:buic_app/teacher_management/manage_quizzes_page.dart';
import 'package:buic_app/teacher_management/mark_attendance.dart';
import 'package:buic_app/teacher_management/request_leave.dart';
import 'package:buic_app/teacher_management/teacher_data_service.dart';
import 'package:buic_app/teacher_management/teacher_schedule_page.dart';
import 'package:buic_app/teacher_management/update_attendance.dart';
import 'package:buic_app/teacher_management/upload_lecture.dart';
import 'package:buic_app/teacher_management/upload_misc.dart';
import 'package:buic_app/teacher_management/view_assignments.dart';
import 'package:buic_app/teacher_management/view_attendance.dart';
import 'package:buic_app/to_do_list.dart';
import 'package:buic_app/whoami.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherHomePage extends ConsumerStatefulWidget {
  const TeacherHomePage({super.key});

  @override
  _TeacherHomePageState createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends ConsumerState<TeacherHomePage> {
  late String formattedDate = '';
  late String day = '';
  String teacherName = '';
  String userEmail = '';
  final TeacherDataService _dataService = TeacherDataService();
  String _teacherId = '';

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _updateDate();
    if (FirebaseAuth.instance.currentUser != null) {
      await _loadTeacherName();
    } else {
      _showError("User not logged in.");
    }
  }

  Future<void> _updateDate() async {
    DateTime dtnow = DateTime.now();
    setState(() {
      formattedDate = DateFormat('dd MMM yyyy').format(dtnow);
      day = _getDayOfWeek(dtnow.weekday);
    });
  }

  Future<void> _loadTeacherName() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedName = prefs.getString('teacherName');

      if (cachedName != null && cachedName.isNotEmpty) {
        setState(() {
          teacherName = cachedName;
        });
        // Also fetch data in background if not already loaded
        if (!_dataService.isDataLoaded) {
          await _fetchOnlyName();
        }
      } else {
        await _fetchOnlyName();
      }
    } catch (e) {
      _showError("Error loading teacher's name: $e");
    }
  }

  Future<void> _fetchOnlyName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      print("Current user: ${user?.email}");

      if (user != null) {
        String email = user.email!;

        QuerySnapshot<Map<String, dynamic>> querySnapshot =
            await FirebaseFirestore.instance
                .collection('teachers')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          _teacherId = doc.id;
          // Update the provider with the fetched teacher ID
          ref.read(teacherIdProvider.notifier).state = _teacherId;

          String name = doc.data()['name'] ?? 'Teacher';

          if (mounted) {
            setState(() {
              teacherName = name.isNotEmpty ? name : 'Sir...';
            });
          }

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('teacherName', name);

          // Load teacher's course and class data
          await _dataService.loadData(_teacherId);
        } else {
          _showError("Teacher's name not found.");
        }
      }
    } catch (e) {
      _showError("Error fetching teacher's name: $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WhoAmI()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BUIC Teacher Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {
              // Handle notification button press
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSectionHeader('Core Tasks'),
            _buildActionCard(
              title: 'Mark Attendance',
              subtitle: 'Record daily student attendance',
              icon: Icons.check_circle_outline,
              color: Colors.green,
              onTap: () => _navigateTo(const MarkAttendancePage()),
            ),
            _buildActionCard(
              title: 'Upload Lecture',
              subtitle: 'Share course materials and slides',
              icon: Icons.upload_file_outlined,
              color: Colors.blueAccent,
              onTap: () => _navigateTo(const LectureUploadPage()),
            ),
            _buildActionCard(
              title: 'Upload Miscellaneous',
              subtitle: 'Share books, outlines, etc.',
              icon: Icons.attach_file_outlined,
              color: Colors.deepPurpleAccent,
              onTap: () => _navigateTo(const UploadMisc()),
            ),
            _buildSectionHeader('Grading & Evaluations'),
            _buildActionCard(
              title: 'Manage Assignments',
              subtitle: 'Create, view, and grade assignments',
              icon: Icons.assignment_turned_in_outlined,
              color: Colors.orangeAccent,
              onTap: () => _navigateTo(const ViewAssignments()),
            ),
            _buildActionCard(
              title: 'Manage Quizzes',
              subtitle: 'Create quizzes and enter marks',
              icon: Icons.quiz_outlined,
              color: Colors.teal,
              onTap: () => _navigateTo(const ManageQuizzesPage()),
            ),
            _buildActionCard(
              title: 'Manage Midterm',
              subtitle: 'Set details and enter marks',
              icon: Icons.assessment_outlined,
              color: Colors.blue,
              onTap: () => _navigateTo(const ManageMidtermPage()),
            ),
            _buildActionCard(
              title: 'Manage Project',
              subtitle: 'Set details and enter marks',
              icon: Icons.group_work_outlined,
              color: Colors.purple,
              onTap: () => _navigateTo(const ManageProjectPage()),
            ),
            _buildSectionHeader('Records & Management'),
            _buildActionCard(
              title: 'View Attendance',
              subtitle: 'Review attendance records',
              icon: Icons.visibility_outlined,
              color: Colors.teal,
              onTap: () => _navigateTo(const ViewAttendance()),
            ),
            _buildActionCard(
              title: 'Update Attendance',
              subtitle: 'Modify existing attendance records',
              icon: Icons.edit_calendar_outlined,
              color: Colors.lightGreen,
              onTap: () => _navigateTo(const UpdateAttendance()),
            ),
            _buildSectionHeader('General Utilities'),
            _buildActionCard(
              title: 'Class Schedules',
              subtitle: 'View your weekly timetable',
              icon: Icons.calendar_month_outlined,
              color: Colors.purple,
              onTap: () => _navigateTo(const TeacherSchedulePage()),
            ),
            _buildActionCard(
              title: 'Leave Requests Report',
              subtitle: 'Check the status of leave requests',
              icon: Icons.calendar_view_day_outlined,
              color: Colors.red,
              onTap: () => _navigateTo(const LeaveReport()),
            ),
            _buildActionCard(
              title: 'Create Leave Request',
              subtitle: 'Apply for a leave of absence',
              icon: Icons.assignment_late_outlined,
              color: Colors.pink,
              onTap: () => _navigateTo(const RequestLeave()),
            ),
            _buildActionCard(
              title: 'News & Events',
              subtitle: 'Stay updated with campus news',
              icon: Icons.event_outlined,
              color: Colors.indigo,
              onTap: () => _navigateTo(const NewsEvents()),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ToDoList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome,',
                    style: TextStyle(fontSize: 22, color: Colors.white70),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Prof. ',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white70,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        TextSpan(
                          text: teacherName.isNotEmpty ? teacherName : 'Sir...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TeacherProfilePage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline, size: 20),
                    label: const Text('View Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wb_sunny, size: 40, color: Colors.white),
                const SizedBox(height: 5),
                Text(
                  day,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getDayOfWeek(int day) {
    switch (day) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }
}
