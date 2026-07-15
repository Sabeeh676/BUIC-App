import 'package:buic_app/services/database_helper.dart';
import 'package:buic_app/services/timetable_service.dart';
import 'package:flutter/material.dart';

class TimeTable extends StatefulWidget {
  const TimeTable({super.key});

  @override
  State<TimeTable> createState() => _TimeTableState();
}

class _TimeTableState extends State<TimeTable>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TimetableService _timetableService = TimetableService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  Map<String, List<Map<String, dynamic>>> _schedule = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: days.length, vsync: this);
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    await _loadTimetableFromCache();
    // Trigger background sync
    _syncTimetable();
  }

  Future<void> _loadTimetableFromCache() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final cachedData = await _dbHelper.getCachedData('timetable');
      if (mounted) {
        setState(() {
          _schedule = _groupAndSortSchedule(cachedData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load timetable from cache: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncTimetable({bool force = false}) async {
    try {
      await _timetableService.syncFullTimetable(force: force);
      await _loadTimetableFromCache(); // Refresh UI from cache
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to sync timetable: ${e.toString()}")),
        );
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupAndSortSchedule(
      List<Map<String, dynamic>> scheduleList) {
    Map<String, List<Map<String, dynamic>>> tempSchedule = {
      for (var day in days) day.toLowerCase(): [],
    };

    for (var session in scheduleList) {
      final day = session['day']?.toString().toLowerCase();
      if (day != null && tempSchedule.containsKey(day)) {
        tempSchedule[day]!.add({
          'name': session['course_name'],
          'professor': session['professor'],
          'location': session['location'],
          'startTime': session['start_time'],
          'endTime': session['end_time'],
        });
      }
    }

    tempSchedule.forEach((day, classes) {
      classes.sort((a, b) =>
          (a['startTime'] as String).compareTo(b['startTime'] as String));
    });

    return tempSchedule;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _syncTimetable(force: true),
            tooltip: 'Refresh Timetable',
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, const Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Time Table'),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: days.map((day) => Tab(text: day)).toList(),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 15),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: days
            .map(
              (day) => RefreshIndicator(
                onRefresh: () => _syncTimetable(force: true),
                child: _buildDayView(day),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDayView(String day) {
    final dayKey = day.toLowerCase();
    final classes = _schedule[dayKey] ?? [];

    if (_isLoading && classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (classes.isEmpty) {
      return _buildEmptyState(day);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classData = classes[index];
        return _buildClassCard(
          context,
          classData['startTime'] as String,
          classData['endTime'] as String,
          classData['name'] as String,
          classData['professor'] as String,
          classData['location'] as String,
        );
      },
    );
  }

  Widget _buildEmptyState(String day) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/burbg.png', height: 200),
          const SizedBox(height: 20),
          Text(
            "You're free on $day!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "No classes scheduled. Enjoy your day!",
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(
    BuildContext context,
    String startTime,
    String endTime,
    String subject,
    String teacher,
    String location,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 10,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    startTime,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Text("to", style: TextStyle(color: Colors.grey)),
                  Text(
                    endTime,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.person_outline, teacher),
                    const SizedBox(height: 6),
                    _buildInfoRow(Icons.location_on_outlined, location),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}