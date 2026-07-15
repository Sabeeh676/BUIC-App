import 'package:buic_app/admin/add_edit_semester_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageStudentTranscriptPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const ManageStudentTranscriptPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ManageStudentTranscriptPage> createState() =>
      _ManageStudentTranscriptPageState();
}

class _ManageStudentTranscriptPageState
    extends State<ManageStudentTranscriptPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _navigateToAddEditPage({DocumentSnapshot? semesterDoc}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSemesterPage(
          studentId: widget.studentId,
          semesterDoc: semesterDoc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transcript for ${widget.studentName}"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('transcripts')
            .doc(widget.studentId)
            .collection('semesters')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No transcript data found for this student.'));
          }

          final semesterDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: semesterDocs.length,
            itemBuilder: (context, index) {
              final semesterDoc = semesterDocs[index];
              final semesterData = semesterDoc.data() as Map<String, dynamic>;
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(semesterDoc.id),
                  subtitle: Text(
                      'GPA: ${semesterData['GPA']} - CGPA: ${semesterData['CGPA']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _navigateToAddEditPage(semesterDoc: semesterDoc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _firestore
                              .collection('transcripts')
                              .doc(widget.studentId)
                              .collection('semesters')
                              .doc(semesterDoc.id)
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
        onPressed: () => _navigateToAddEditPage(),
        child: const Icon(Icons.add),
        tooltip: 'Add Semester',
      ),
    );
  }
}
