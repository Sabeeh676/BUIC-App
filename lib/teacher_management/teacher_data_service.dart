import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherDataService extends ChangeNotifier {
  // Singleton pattern
  static final TeacherDataService _instance = TeacherDataService._internal();
  factory TeacherDataService() => _instance;
  TeacherDataService._internal();

  String? _teacherId;
  Map<String, String> _courses = {}; // courseId -> courseName
  Map<String, List<String>> _classCourses = {}; // classId -> [courseId]

  bool get isDataLoaded => _teacherId != null && _courses.isNotEmpty;

  Map<String, String> get courses => Map.from(_courses);

  List<String> getClassesForCourse(String courseId) {
    return _classCourses.entries
        .where((entry) => entry.value.contains(courseId))
        .map((entry) => entry.key)
        .toList();
  }

  Future<void> loadData(String teacherId) async {
    if (_teacherId == teacherId && isDataLoaded) {
      return;
    }

    _teacherId = teacherId;

    bool loadedFromCache = await _loadFromCache();
    if (loadedFromCache) {
      notifyListeners();
    }

    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (teacherDoc.exists) {
        final data = teacherDoc.data();
        final classCourseData =
            data?['class_course'] as Map<String, dynamic>? ?? {};

        _classCourses = classCourseData
            .map((key, value) => MapEntry(key, List<String>.from(value)));

        final allCourseIds =
            _classCourses.values.expand((courses) => courses).toSet().toList();

        Map<String, String> tempCoursesMap = {};
        for (String courseId in allCourseIds) {
          final courseDoc = await FirebaseFirestore.instance
              .collection('courses')
              .doc(courseId)
              .get();
          if (courseDoc.exists) {
            tempCoursesMap[courseId] =
                courseDoc.data()?['course_name'] ?? 'Unknown';
          }
        }
        _courses = tempCoursesMap;

        await _saveToCache();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading teacher data from Firestore: $e");
    }
  }

  Future<bool> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTeacherId = prefs.getString('teacher_id');

    if (cachedTeacherId != _teacherId) return false;

    final coursesJson = prefs.getString('teacher_courses');
    final classCoursesJson = prefs.getString('teacher_class_courses');

    if (coursesJson != null && classCoursesJson != null) {
      try {
        _courses = Map<String, String>.from(json.decode(coursesJson));
        _classCourses =
            Map<String, List<dynamic>>.from(json.decode(classCoursesJson))
                .map((key, value) => MapEntry(key, value.cast<String>()));
        return true;
      } catch (e) {
        debugPrint("Error parsing teacher data from cache: $e");
        await prefs.remove('teacher_courses');
        await prefs.remove('teacher_class_courses');
      }
    }
    return false;
  }

  Future<void> _saveToCache() async {
    if (_teacherId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_id', _teacherId!);
    await prefs.setString('teacher_courses', json.encode(_courses));
    await prefs.setString('teacher_class_courses', json.encode(_classCourses));
  }
}
