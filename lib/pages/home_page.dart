import 'package:buic_app/home_page/assignments.dart';
import 'package:buic_app/home_page/chatbot_page.dart';
import 'package:buic_app/home_page/lectures.dart';
import 'package:buic_app/home_page/news_event.dart';
import 'package:buic_app/home_page/profile.dart';
import 'package:buic_app/home_page/projects_page.dart';
import 'package:buic_app/home_page/quiz.dart';
import 'package:buic_app/home_page/result.dart';
import 'package:buic_app/home_page/time_table.dart';
import 'package:buic_app/pages/downloads_page.dart';
import 'package:buic_app/services/database_helper.dart';
import 'package:buic_app/services/timetable_service.dart';
import 'package:buic_app/to_do_list.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _todayClasses = [];
  bool _isLoadingClasses = true;

  late String formattedDate = '';
  late String day = '';
  String studentName = 'Student';

  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Quiz', 'icon': Icons.quiz_outlined, 'page': const QuizPage()},
    {
      'title': 'Lectures',
      'icon': Icons.menu_book_outlined,
      'page': const LecturesPage(),
    },
    {
      'title': 'Assignments',
      'icon': Icons.assignment_turned_in_outlined,
      'page': const AssignmentsPage(),
    },
    {
      'title': 'Result',
      'icon': Icons.school_outlined,
      'page': const ResultPage(),
    },
    {
      'title': 'News & Events',
      'icon': Icons.campaign_outlined,
      'page': const NewsEvents(),
    },
    {
      'title': 'Projects',
      'icon': Icons.lightbulb_outline,
      'page': const ProjectsPage(),
    },
    {
      'title': 'Downloads',
      'icon': Icons.download_for_offline_outlined,
      'page': const DownloadsPage(),
    },
    {
      'title': 'BU Assistant',
      'icon': Icons.smart_toy_outlined,
      'page': const ChatbotPage(),
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateDate();
    _loadHomePageData();
  }

  void _updateDate() {
    DateTime dtnow = DateTime.now();
    formattedDate = DateFormat('dd MMM yyyy').format(dtnow);
    day = DateFormat('EEEE').format(dtnow);
  }

  Future<void> _loadHomePageData() async {
    // First, load all data from cache for a fast startup.
    await _loadName();
    await _fetchTodayClassesFromCache();

    // After loading from cache, trigger a background sync.
    // This runs in the background and doesn't block the UI.
    TimetableService().syncFullTimetable();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('student_name');
    if (cachedName != null && mounted) {
      setState(() {
        studentName = cachedName;
      });
    }
    // Also fetch from Firestore to get the latest name in the background.
    _fetchNameFromFirestore();
  }

  Future<void> _fetchNameFromFirestore() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String docId = user.email!.split('@')[0];
        DocumentSnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('students')
                .doc(docId)
                .get();

        if (snapshot.exists && mounted) {
          final fetchedName = snapshot.data()?['name'] ?? 'Student';
          if (studentName != fetchedName) {
            setState(() {
              studentName = fetchedName;
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('student_name', fetchedName);
          }
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> _fetchTodayClassesFromCache() async {
    if (!mounted) return;
    setState(() {
      _isLoadingClasses = true;
    });
    try {
      String today = DateFormat('EEEE').format(DateTime.now()).toLowerCase();
      final db = await dbHelper.database;
      final classes = await db.query(
        'timetable',
        where: 'day = ?',
        whereArgs: [today],
        orderBy: 'start_time ASC',
      );
      if (mounted) {
        setState(() {
          _todayClasses = classes
              .map(
                (c) => {
                  'startTime': c['start_time'] as String,
                  'endTime': c['end_time'] as String,
                  'name': c['course_name'] as String,
                  'professor': c['professor'] as String,
                },
              )
              .toList();
          _isLoadingClasses = false;
        });
      }
    } catch (e) {
      print("Error fetching today's classes from cache: $e");
      if (mounted) {
        setState(() {
          _isLoadingClasses = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatbotPage()),
        ),
        backgroundColor: const Color(0xFF00695C),
        icon: const Text('🎓', style: TextStyle(fontSize: 20)),
        label: const Text(
          'BU Assistant',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        elevation: 6,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildTimetableCard(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Text(
                  "Explore Services",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              _buildMenuGrid(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ToDoList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, const Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${studentName.isNotEmpty ? studentName.split(' ')[0] : 'Student'}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$day, $formattedDate',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              child: Text(
                studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TimeTable()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: (_isLoadingClasses && _todayClasses.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : _todayClasses.isEmpty
                  ? _buildNoClassesView()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Today's Classes",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        ..._todayClasses.map((classData) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: buildClassRow(
                              context,
                              classData['startTime'] as String,
                              classData['endTime'] as String,
                              classData['name'] as String,
                              classData['professor'] as String,
                            ),
                          );
                        }).toList(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildNoClassesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Schedule",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Icon(Icons.done_all, color: Colors.green, size: 40),
                const SizedBox(height: 10),
                const Text(
                  "No classes today!",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget buildClassRow(
    BuildContext context,
    String startTime,
    String endTime,
    String subject,
    String teacher,
  ) {
    // Helper to format time string from "HH:mm" to "hh:mm a"
    String formatTimeString(String time) {
      try {
        final timeParts = time.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final dateTime = DateTime(2023, 1, 1, hour, minute); // Dummy date
        return DateFormat('hh:mm a').format(dateTime);
      } catch (e) {
        return time; // Fallback to original string if format is unexpected
      }
    }

    final String formattedTime =
        "${formatTimeString(startTime)} - ${formatTimeString(endTime)}";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            formattedTime,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Color(0xFF555555),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Icon(Icons.fiber_manual_record, color: Colors.teal, size: 12),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                teacher,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _menuItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        return _buildMenuCard(
          title: item['title'],
          icon: item['icon'],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => item['page']),
          ),
          index: index,
        );
      },
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required int index,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(
                icon,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }
}