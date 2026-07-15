import 'package:flutter_riverpod/legacy.dart';

// This provider will hold the ID of the currently logged-in teacher.
// Other pages, like ViewAssignments, can listen to this provider
// to get the teacher's ID and fetch the relevant data.
final teacherIdProvider = StateProvider<String?>((ref) => null);
