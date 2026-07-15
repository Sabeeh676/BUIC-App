import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';

final assignmentsProvider =
    StateNotifierProvider<
      AssignmentsNotifier,
      AsyncValue<List<Map<String, dynamic>>>
    >((ref) => AssignmentsNotifier());

class AssignmentsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  AssignmentsNotifier() : super(const AsyncValue.loading()) {
    fetchAssignments();
  }

  Future<void> fetchAssignments() async {
    try {
      state = const AsyncValue.loading(); // Set loading state
      List<Map<String, dynamic>> allAssignments = [];

      // Fetch logic (e.g., teacher ID and assignments)
      final teacherId = await getTeacherId();
      final teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (teacherDoc.exists) {
        final classCourses = teacherDoc.data()?['class_course'] ?? {};

        for (String classSection in classCourses.keys) {
          List<String> courseIds = List<String>.from(
            classCourses[classSection],
          );

          for (String courseId in courseIds) {
            final assignmentSnapshot = await FirebaseFirestore.instance
                .collection('courses')
                .doc(courseId)
                .collection('classes')
                .doc(classSection)
                .collection('assignments')
                .get();

            for (var doc in assignmentSnapshot.docs) {
              Map<String, dynamic> assignmentData = doc.data();
              assignmentData['course_id'] = courseId;
              assignmentData['class_section'] = classSection;
              allAssignments.add(assignmentData);
            }
          }
        }
      }

      state = AsyncValue.data(allAssignments); // Set data state
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current); // Set error state
    }
  }

  Future<String> getTeacherId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final querySnapshot = await FirebaseFirestore.instance
        .collection('teachers')
        .where('email', isEqualTo: user.email)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    } else {
      throw Exception('Teacher data not found');
    }
  }
}
