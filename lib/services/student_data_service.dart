import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentDataService {
  static final StudentDataService _instance = StudentDataService._internal();
  factory StudentDataService() => _instance;
  StudentDataService._internal();

  Map<String, dynamic>? _studentDoc;
  Map<String, String>? _courseNames;
  bool _isFetching = false;
  DateTime? _lastFetchTime;

  // Fetches data only if cache is empty or older than 5 minutes.
  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (_isFetching) return;

    final now = DateTime.now();
    if (!forceRefresh &&
        _studentDoc != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 5) {
      return; // Use cached data if it's recent
    }

    _isFetching = true;
    _studentDoc = {};
    _courseNames = {};

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final studentId = user.email!.split('@')[0];

      final studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();
      if (!studentSnapshot.exists) return;
      _studentDoc = studentSnapshot.data();
      _studentDoc!['id'] = studentId;

      List<String> registeredCourses =
          List<String>.from(_studentDoc!['registeredCourses'] ?? [])
              .where((c) => c.isNotEmpty)
              .toList();
      if (registeredCourses.isEmpty) {
        _courseNames = {};
        return;
      }

      _courseNames = {};
      List<List<String>> courseChunks = [];
      for (var i = 0; i < registeredCourses.length; i += 10) {
        courseChunks.add(
          registeredCourses.sublist(
            i,
            i + 10 > registeredCourses.length
                ? registeredCourses.length
                : i + 10,
          ),
        );
      }
      for (final chunk in courseChunks) {
        final snapshot = await FirebaseFirestore.instance
            .collection('courses')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (var doc in snapshot.docs) {
          _courseNames![doc.id] = doc['course_name'] as String;
        }
      }
      _lastFetchTime = now;
    } catch (e) {
      print("Error fetching student data: $e");
      // Don't block future fetches if one fails
    } finally {
      _isFetching = false;
    }
  }

  Future<Map<String, dynamic>?> getStudentData({bool forceRefresh = false}) async {
    if (_studentDoc == null || forceRefresh) {
      await _fetchData(forceRefresh: forceRefresh);
    }
    return _studentDoc;
  }

  Future<Map<String, String>?> getCourseNames({bool forceRefresh = false}) async {
    if (_courseNames == null || forceRefresh) {
      await _fetchData(forceRefresh: forceRefresh);
    }
    return _courseNames;
  }

  void clearCache() {
    _studentDoc = null;
    _courseNames = null;
    _lastFetchTime = null;
  }
}
