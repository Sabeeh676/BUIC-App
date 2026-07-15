import 'package:buic_app/services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimetableService {
  final dbHelper = DatabaseHelper();
  final List<String> days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  // Syncs the full week's timetable from Firestore to the local DB.
  // By default, it only syncs if the data is stale (older than 4 hours).
  // Set [force] to true to bypass the stale check and sync immediately.
  Future<void> syncFullTimetable({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('last_timetable_sync') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (!force &&
        (currentTime - lastSync < const Duration(hours: 4).inMilliseconds)) {
      print("Timetable sync skipped, data is fresh.");
      return;
    }

    print("Starting full timetable sync from new structure...");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final studentId = user.email!.split('@')[0];

    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();
      if (!studentDoc.exists) return;

      final studentData = studentDoc.data()!;
      final registeredCourses =
          List<String>.from(studentData['registeredCourses'] ?? []);
      if (registeredCourses.isEmpty) return;

      List<Map<String, dynamic>> sessionsToCache = [];

      for (String courseId in registeredCourses) {
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();
        final courseName = courseDoc.data()?['course_name'] ?? 'N/A';

        final classesSnapshot = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .collection('classes')
            .get();

        for (var classDoc in classesSnapshot.docs) {
          final classData = classDoc.data();
          final studentsInClass =
              List<String>.from(classData['students'] ?? []);

          if (studentsInClass.contains(studentId)) {
            final schedule =
                List<Map<String, dynamic>>.from(classData['schedule'] ?? []);

            for (var session in schedule) {
              final teacherId = session['teacher_id'] as String?;
              String teacherName = 'N/A';

              if (teacherId != null && teacherId != 'N/A') {
                final teacherDoc = await FirebaseFirestore.instance
                    .collection('teachers')
                    .doc(teacherId)
                    .get();
                if (teacherDoc.exists) {
                  teacherName = teacherDoc.data()?['name'] ?? 'N/A';
                }
              }

              sessionsToCache.add({
                'day': session['day'],
                'course_name': courseName,
                'start_time': session['start_time'],
                'end_time': session['end_time'],
                'professor': teacherName,
                'location': session['location'],
              });
            }
          }
        }
      }

      await dbHelper.cacheData('timetable', sessionsToCache);

      await prefs.setInt('last_timetable_sync', currentTime);
      print(
          "Full timetable sync completed successfully. Cached ${sessionsToCache.length} sessions.");
    } catch (e) {
      print("Error during full timetable sync: $e");
    }
  }

  // Syncs the teacher's schedule from Firestore to the local DB.
  Future<void> syncTeacherSchedule({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('last_teacher_schedule_sync') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (!force &&
        (currentTime - lastSync < const Duration(hours: 4).inMilliseconds)) {
      print("Teacher schedule sync skipped, data is fresh.");
      return;
    }

    print("Starting teacher schedule sync...");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      final teacherQuery = await FirebaseFirestore.instance
          .collection('teachers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (teacherQuery.docs.isEmpty) return;

      final teacherId = teacherQuery.docs.first.id;

      List<Map<String, dynamic>> scheduleToCache = [];

      final coursesSnapshot =
          await FirebaseFirestore.instance.collection('courses').get();

      for (var courseDoc in coursesSnapshot.docs) {
        final classesSnapshot =
            await courseDoc.reference.collection('classes').get();

        for (var classDoc in classesSnapshot.docs) {
          final classData = classDoc.data();
          final schedule =
              List<Map<String, dynamic>>.from(classData['schedule'] ?? []);

          for (var session in schedule) {
            if (session['teacher_id'] == teacherId) {
              final day = session['day']?.toString().toLowerCase();
              if (day != null) {
                scheduleToCache.add({
                  'day': day,
                  'courseName': courseDoc.data()['course_name'] ?? 'N/A',
                  'className': classDoc.id,
                  'location': session['location'] ?? 'N/A',
                  'startTime': session['start_time'] ?? '00:00',
                  'endTime': session['end_time'] ?? '00:00',
                });
              }
            }
          }
        }
      }

      await dbHelper.cacheData('teacher_schedule', scheduleToCache);

      await prefs.setInt('last_teacher_schedule_sync', currentTime);
      print(
          "Teacher schedule sync completed. Cached ${scheduleToCache.length} sessions.");
    } catch (e) {
      print("Error during teacher schedule sync: $e");
    }
  }
}
