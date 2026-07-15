import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassDetailsPage extends StatefulWidget {
  final String courseId;
  final String classId;
  const ClassDetailsPage({
    super.key,
    required this.classId,
    required this.courseId,
  });

  @override
  State<ClassDetailsPage> createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends State<ClassDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference get _classDocRef => _firestore
      .collection('courses')
      .doc(widget.courseId)
      .collection('classes')
      .doc(widget.classId);

  Future<void> _showAddStudentsDialog() async {
    // Fetch all students and students already in this class
    final allStudentsSnapshot = await _firestore.collection('students').get();
    final classDoc = await _classDocRef.get();
    final studentsInClass = List<String>.from(
      (classDoc.data() as Map<String, dynamic>?)?['students'] ?? [],
    );

    final allStudents = allStudentsSnapshot.docs;
    List<DocumentSnapshot> unassignedStudents = allStudents
        .where((student) => !studentsInClass.contains(student.id))
        .toList();

    List<String> selectedStudentIds = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Students to Class'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: unassignedStudents.length,
                  itemBuilder: (context, index) {
                    final student = unassignedStudents[index];
                    final isSelected = selectedStudentIds.contains(student.id);
                    return CheckboxListTile(
                      title: Text(student['name']),
                      subtitle: Text(student.id),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedStudentIds.add(student.id);
                          } else {
                            selectedStudentIds.remove(student.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedStudentIds.isNotEmpty) {
                      await _classDocRef.update({
                        'students': FieldValue.arrayUnion(selectedStudentIds),
                      });
                      // Note: Updating student's 'class' field might be an oversimplification
                      // if a student can be in multiple classes for different courses.
                      // For now, this maintains existing logic.
                      for (String studentId in selectedStudentIds) {
                        await _firestore
                            .collection('students')
                            .doc(studentId)
                            .update({'class': widget.classId});
                      }
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Details for ${widget.classId}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Course: ${widget.courseId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Student Management Section
          _buildSectionHeader(title: 'Students', onAdd: _showAddStudentsDialog),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _classDocRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.data!.exists) {
                  return const Center(child: Text('Class not found.'));
                }
                final studentIds = List<String>.from(
                  (snapshot.data!.data()
                          as Map<String, dynamic>?)?['students'] ??
                      [],
                );
                if (studentIds.isEmpty) {
                  return const Center(
                    child: Text('No students enrolled in this class.'),
                  );
                }

                return ListView.builder(
                  itemCount: studentIds.length,
                  itemBuilder: (context, index) {
                    final studentId = studentIds[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('students')
                          .doc(studentId)
                          .get(),
                      builder: (context, studentSnapshot) {
                        if (!studentSnapshot.hasData) {
                          return ListTile(
                            title: Text(studentId),
                            subtitle: const Text('Loading...'),
                          );
                        }
                        if (!studentSnapshot.data!.exists) {
                          return ListTile(
                            title: Text(studentId),
                            subtitle: const Text('Student data not found.'),
                            trailing: const Icon(
                              Icons.error,
                              color: Colors.red,
                            ),
                          );
                        }
                        return ListTile(
                          title: Text(studentSnapshot.data!['name']),
                          subtitle: Text(studentId),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              // Remove from class's student array
                              await _classDocRef.update({
                                'students': FieldValue.arrayRemove([studentId]),
                              });
                              // Remove class from student document
                              await _firestore
                                  .collection('students')
                                  .doc(studentId)
                                  .update({'class': null});
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required VoidCallback onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Manage'),
          ),
        ],
      ),
    );
  }
}

extension AppBarSubheader on AppBar {
  AppBar copyWith({Widget? subheader}) {
    return AppBar(
      title: title,
      bottom: subheader != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(20.0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: subheader,
              ),
            )
          : null,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}
