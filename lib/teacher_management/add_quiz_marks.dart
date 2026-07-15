import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddQuizMarksPage extends StatefulWidget {
  final String courseId;
  final String classId;
  final DocumentSnapshot quizDoc;

  const AddQuizMarksPage({
    super.key,
    required this.courseId,
    required this.classId,
    required this.quizDoc,
  });

  @override
  State<AddQuizMarksPage> createState() => _AddQuizMarksPageState();
}

class _AddQuizMarksPageState extends State<AddQuizMarksPage> {
  List<String> _students = [];
  Map<String, String> _studentNames = {};
  Map<String, TextEditingController> _marksControllers = {};
  bool _isLoadingStudents = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchStudentsAndMarks();
  }

  Future<void> _fetchStudentsAndMarks() async {
    setState(() => _isLoadingStudents = true);

    try {
      // Fetch students for the class
      final classDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('classes')
          .doc(widget.classId)
          .get();

      if (!classDoc.exists) {
        _showError('Class document not found!');
        setState(() => _isLoadingStudents = false);
        return;
      }

      final studentIds = List<String>.from(classDoc.data()?['students'] ?? []);
      if (studentIds.isEmpty) {
        setState(() => _isLoadingStudents = false);
        return; // No students in this class
      }

      _students = studentIds;

      // Fetch student names
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where(FieldPath.documentId, whereIn: _students)
          .get();
      for (var studentDoc in studentsSnapshot.docs) {
        _studentNames[studentDoc.id] = studentDoc.data()['name'] ?? 'Unknown';
      }

      // Initialize controllers for all students
      for (var studentId in _students) {
        _marksControllers[studentId] = TextEditingController();
      }

      // Fetch existing marks to pre-fill
      final submissions =
          await widget.quizDoc.reference.collection('submissions').get();
      for (var submission in submissions.docs) {
        final studentId = submission.id;
        if (_marksControllers.containsKey(studentId)) {
          _marksControllers[studentId]!.text =
              submission.data()['marksObtained']?.toString() ?? '';
        }
      }
    } catch (e) {
      _showError('Failed to fetch students: ${e.toString()}');
    } finally {
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _saveMarks() async {
    final totalMarks = widget.quizDoc['totalMarks'];
    final batch = FirebaseFirestore.instance.batch();
    bool hasError = false;

    _marksControllers.forEach((studentId, controller) {
      final marksText = controller.text;
      if (marksText.isNotEmpty) {
        final marks = int.tryParse(marksText);
        if (marks == null || marks < 0 || marks > totalMarks) {
          _showError(
            'Invalid marks for student ${_studentNames[studentId] ?? studentId}. Marks must be between 0 and $totalMarks.',
          );
          hasError = true;
          return;
        }

        final submissionRef =
            widget.quizDoc.reference.collection('submissions').doc(studentId);
        final studentName = _studentNames[studentId] ?? 'Unknown';

        batch.set(submissionRef, {
          'marksObtained': marks,
          'submittedAt': FieldValue.serverTimestamp(),
          'studentId': studentId,
          'studentName': studentName,
        });
      }
    });

    if (hasError) return;

    setState(() => _isSaving = true);
    try {
      await batch.commit();
      _showSuccess('Marks saved successfully!');
    } catch (e) {
      _showError('Failed to save marks: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _marksControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizTitle = widget.quizDoc['title'] ?? 'Quiz';
    final totalMarks = widget.quizDoc['totalMarks'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Marks for $quizTitle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Total Marks: $totalMarks',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (_isLoadingStudents)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_students.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No students found in this class.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final studentId = _students[index];
                    final studentName = _studentNames[studentId] ?? studentId;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(studentName),
                        subtitle: Text(studentId),
                        trailing: SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _marksControllers[studentId],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'Marks',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_students.isNotEmpty && !_isLoadingStudents)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMarks,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save All Marks'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
