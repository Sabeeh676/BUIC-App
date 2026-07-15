import 'package:buic_app/admin/add_edit_class_page.dart';
import 'package:buic_app/admin/class_details_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageCourseClassesPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const ManageCourseClassesPage({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<ManageCourseClassesPage> createState() =>
      _ManageCourseClassesPageState();
}

class _ManageCourseClassesPageState extends State<ManageCourseClassesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _navigateToAddEditPage({DocumentSnapshot? classDoc}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddEditClassPage(courseId: widget.courseId, classDoc: classDoc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Classes for ${widget.courseName}')),
      body: _buildClassesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditPage(),
        tooltip: 'Add Class',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildClassesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('courses')
          .doc(widget.courseId)
          .collection('classes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No classes found for this course.'));
        }

        final classes = snapshot.data!.docs;

        return ListView.builder(
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final classDoc = classes[index];
            final classData = classDoc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('Class: ${classDoc.id}'),
                subtitle: FutureBuilder<DocumentSnapshot>(
                  future: _firestore
                      .collection('teachers')
                      .doc(classData['teacher_id'])
                      .get(),
                  builder: (context, teacherSnapshot) {
                    if (!teacherSnapshot.hasData) {
                      return const Text('Loading teacher...');
                    }
                    final teacherName = (teacherSnapshot.data?.data()
                            as Map<String, dynamic>?)?['name'] ??
                        'N/A';
                    return Text(
                      'Teacher: $teacherName\nStudents: ${classData['students']?.length ?? 0}',
                    );
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClassDetailsPage(
                        courseId: widget.courseId,
                        classId: classDoc.id,
                      ),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _navigateToAddEditPage(classDoc: classDoc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _firestore
                            .collection('courses')
                            .doc(widget.courseId)
                            .collection('classes')
                            .doc(classDoc.id)
                            .delete();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
