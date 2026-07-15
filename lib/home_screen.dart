import 'package:buic_app/whoami.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buic_app/pages/home_page.dart';
import 'package:buic_app/pages/leave_status_page.dart';
import 'package:buic_app/pages/my_courses_page.dart';
import 'package:buic_app/pages/fee_page.dart';
import 'package:buic_app/pages/transcript_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2;

  void _navigationBottomBar(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = [
    const LeaveStatusPage(),
    const MyCoursesPage(),
    const HomePage(),
    const FeePage(),
    const TranscriptPage(),
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WhoAmI()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(_selectedIndex)),
        backgroundColor: Colors.teal.shade700,
        centerTitle: true,
        leading: _selectedIndex != 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
              )
            : null,
        actions: [
          Icon(Icons.notifications_none_outlined),
          const SizedBox(width: 5),
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
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        unselectedItemColor: Colors.black38,
        showUnselectedLabels: true,
        selectedItemColor: Colors.teal.shade700,
        currentIndex: _selectedIndex,
        onTap: _navigationBottomBar,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Leave Status',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'My Courses',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home_max), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Fee'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transcript',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Leave Status';
      case 1:
        return 'My Courses';
      case 2:
        return 'BUIC';
      case 3:
        return 'Fee Status';
      case 4:
        return 'Transcript';
      default:
        return 'BUIC';
    }
  }
}
