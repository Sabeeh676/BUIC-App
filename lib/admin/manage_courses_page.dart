import 'package:buic_app/admin/manage_course_classes_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageCoursesPage extends StatefulWidget {
  const ManageCoursesPage({super.key});

  @override
  State<ManageCoursesPage> createState() => _ManageCoursesPageState();
}

class _ManageCoursesPageState extends State<ManageCoursesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _showCourseDialog({DocumentSnapshot? course}) async {
    final _formKey = GlobalKey<FormState>();
    final _nameController =
        TextEditingController(text: course?['course_name'] ?? '');
    final _idController =
        TextEditingController(text: course?['course_id'] ?? '');
    final _creditsController =
        TextEditingController(text: course?['credit_hours']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(course == null ? 'Add Course' : 'Edit Course'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Course Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a name' : null,
                  ),
                  TextFormField(
                    controller: _idController,
                    decoration:
                        const InputDecoration(labelText: 'Course ID (e.g., CS101)'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a course ID' : null,
                  ),
                  TextFormField(
                    controller: _creditsController,
                    decoration:
                        const InputDecoration(labelText: 'Credit Hours'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return 'Please enter credit hours';
                      if (int.tryParse(value) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final courseData = {
                    'course_name': _nameController.text,
                    'course_id': _idController.text,
                    'credit_hours': int.parse(_creditsController.text),
                  };

                  try {
                    if (course == null) {
                      // Create new course
                      await _firestore
                          .collection('courses')
                          .doc(_idController.text)
                          .set(courseData);
                    } else {
                      // Update existing course
                      await _firestore
                          .collection('courses')
                          .doc(course.id)
                          .update(courseData);
                    }
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Error saving course: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Courses'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('courses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No courses found.'));
          }

          final courses = snapshot.data!.docs;

          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(course['course_name']),
                  subtitle: Text(
                      '${course['course_id']} - ${course['credit_hours']} Credit Hours'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageCourseClassesPage(
                          courseId: course.id,
                          courseName: course['course_name'],
                        ),
                      ),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showCourseDialog(course: course),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _firestore
                              .collection('courses')
                              .doc(course.id)
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCourseDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Course',
      ),
    );
  }
}