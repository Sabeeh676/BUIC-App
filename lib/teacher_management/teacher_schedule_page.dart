import 'package:buic_app/services/database_helper.dart';
import 'package:buic_app/services/timetable_service.dart';
import 'package:flutter/material.dart';

class TeacherSchedulePage extends StatefulWidget {
  const TeacherSchedulePage({super.key});

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  final TimetableService _timetableService = TimetableService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, List<Map<String, dynamic>>> _schedule = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    await _loadScheduleFromCache();
    // Trigger a background sync, but don't wait for it.
    // The UI will update if new data is fetched.
    _syncSchedule();
  }

  Future<void> _loadScheduleFromCache() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final cachedData = await _dbHelper.getCachedData('teacher_schedule');
      if (mounted) {
        setState(() {
          _schedule = _groupAndSortSchedule(cachedData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load schedule from cache: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncSchedule({bool force = false}) async {
    try {
      await _timetableService.syncTeacherSchedule(force: force);
      // After syncing, reload from cache to update the UI
      await _loadScheduleFromCache();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to sync schedule: ${e.toString()}")),
        );
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupAndSortSchedule(
      List<Map<String, dynamic>> scheduleList) {
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    Map<String, List<Map<String, dynamic>>> tempSchedule = {
      for (var day in days) day: []
    };

    for (var session in scheduleList) {
      final day = session['day']?.toString().toLowerCase();
      if (day != null && tempSchedule.containsKey(day)) {
        tempSchedule[day]!.add(session);
      }
    }

    tempSchedule.forEach((day, classes) {
      classes.sort((a, b) =>
          (a['startTime'] as String).compareTo(b['startTime'] as String));
    });

    return tempSchedule;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('My Schedule'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _syncSchedule(force: true),
            tooltip: 'Refresh Schedule',
          ),
        ],
      ),
      body: _isLoading && _schedule.values.every((list) => list.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : _buildScheduleView(),
    );
  }

  Widget _buildScheduleView() {
    final List<Widget> scheduleWidgets = [];
    final orderedDays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];

    for (var day in orderedDays) {
      final classes = _schedule[day] ?? [];
      if (classes.isNotEmpty) {
        scheduleWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
            child: Text(
              day[0].toUpperCase() + day.substring(1),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
          ),
        );
        scheduleWidgets.addAll(classes.map((classData) => _buildClassCard(
              context,
              classData['startTime'] as String,
              classData['endTime'] as String,
              classData['courseName'] as String,
              classData['className'] as String,
              classData['location'] as String,
            )));
      }
    }

    if (scheduleWidgets.isEmpty) {
      return _buildEmptyState("the week");
    }

    return RefreshIndicator(
      onRefresh: () => _syncSchedule(force: true),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: scheduleWidgets,
      ),
    );
  }

  Widget _buildEmptyState(String scope) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            "No classes for $scope!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(
    BuildContext context,
    String startTime,
    String endTime,
    String courseName,
    String className,
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
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.only(
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
                      courseName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.class_, className),
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