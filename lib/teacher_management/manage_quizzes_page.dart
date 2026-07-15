import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'course_class_selector.dart';
import 'add_quiz_marks.dart'; // We'll reuse this for the detail view for now.

class ManageQuizzesPage extends StatefulWidget {
  const ManageQuizzesPage({super.key});

  @override
  State<ManageQuizzesPage> createState() => _ManageQuizzesPageState();
}

class _ManageQuizzesPageState extends State<ManageQuizzesPage> {
  String? _selectedCourseId;
  String? _selectedClassId;
  bool _isLoading = false;

  // Form controllers for creating a new quiz
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _marksController = TextEditingController();
  final _durationController = TextEditingController();
  DateTime? _dueDate;

  void _onSelectionChanged(String? courseId, List<String> classIds) {
    setState(() {
      _selectedCourseId = courseId;
      _selectedClassId = classIds.isNotEmpty ? classIds.first : null;
    });
  }

  Future<void> _showCreateQuizDialog() async {
    // Clear previous entries
    _titleController.clear();
    _marksController.clear();
    _durationController.clear();
    _dueDate = null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Quiz'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Quiz Title',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a title' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _marksController,
                        decoration: const InputDecoration(
                          labelText: 'Total Marks',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value!.isEmpty) return 'Please enter marks';
                          if (int.tryParse(value) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value!.isEmpty) return 'Please enter duration';
                          if (int.tryParse(value) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Due Date (Optional)',
                          suffixIcon: _dueDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _dueDate = null),
                                )
                              : const Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: _dueDate == null
                              ? ''
                              : DateFormat.yMMMd().format(_dueDate!),
                        ),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (pickedDate != null) {
                            setState(() => _dueDate = pickedDate);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: _createQuiz, child: const Text('Create')),
          ],
        );
      },
    );
  }

  Future<void> _createQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    Navigator.of(context).pop(); // Close the dialog

    try {
      final quizData = {
        'title': _titleController.text,
        'totalMarks': int.parse(_marksController.text),
        'durationInMinutes': int.parse(_durationController.text),
        'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .collection('classes')
          .doc(_selectedClassId)
          .collection('quizzes')
          .add(quizData);

      _showSuccess('Quiz created successfully!');
    } catch (e) {
      _showError('Failed to create quiz: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _marksController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Quizzes')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CourseClassSelector(
                  multiSelection: false,
                  onSelectionChanged: _onSelectionChanged,
                ),
                const SizedBox(height: 20),
                if (_selectedClassId != null)
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('courses')
                          .doc(_selectedCourseId)
                          .collection('classes')
                          .doc(_selectedClassId)
                          .collection('quizzes')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No quizzes found for this class.\nCreate one using the button below.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          );
                        }

                        final quizzes = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: quizzes.length,
                          itemBuilder: (context, index) {
                            final quiz = quizzes[index];
                            final title = quiz['title'];
                            final marks = quiz['totalMarks'];
                            final date =
                                (quiz['createdAt'] as Timestamp).toDate();
                            final formattedDate = DateFormat(
                              'MMM dd, yyyy',
                            ).format(date);

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Total Marks: $marks • Created on: $formattedDate',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddQuizMarksPage(
                                        courseId: _selectedCourseId!,
                                        classId: _selectedClassId!,
                                        quizDoc: quiz,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: _selectedClassId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isLoading ? null : _showCreateQuizDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Quiz'),
            ),
    );
  }
}
