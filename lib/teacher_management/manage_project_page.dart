import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_class_selector.dart';

class ManageProjectPage extends StatefulWidget {
  const ManageProjectPage({super.key});

  @override
  State<ManageProjectPage> createState() => _ManageProjectPageState();
}

class _ManageProjectPageState extends State<ManageProjectPage> {
  String? _selectedCourseId;
  String? _selectedClassId;
  List<String> _students = [];
  Map<String, String> _studentNames = {};
  Map<String, TextEditingController> _marksControllers = {};
  final TextEditingController _totalMarksController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _detailsSet = false;

  void _onSelectionChanged(String? courseId, List<String> classIds) {
    setState(() {
      _selectedCourseId = courseId;
      _selectedClassId = classIds.isNotEmpty ? classIds.first : null;
      _students = [];
      _studentNames = {};
      _marksControllers.forEach((_, controller) => controller.dispose());
      _marksControllers = {};
      _totalMarksController.clear();
      _detailsSet = false;
      if (_selectedCourseId != null && _selectedClassId != null) {
        _fetchProjectDetails();
      }
    });
  }

  Future<void> _fetchProjectDetails() async {
    setState(() => _isLoading = true);
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .collection('classes')
          .doc(_selectedClassId)
          .collection('project')
          .doc('details')
          .get();

      if (projectDoc.exists) {
        _totalMarksController.text =
            projectDoc.data()?['totalMarks']?.toString() ?? '';
        if (_totalMarksController.text.isNotEmpty) {
          _detailsSet = true;
          await _fetchStudentsAndMarks();
        }
      }
    } catch (e) {
      _showError('Failed to fetch project details.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setProjectDetails() async {
    final totalMarks = int.tryParse(_totalMarksController.text);
    if (totalMarks == null || totalMarks <= 0) {
      _showError('Please enter valid total marks.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .collection('classes')
          .doc(_selectedClassId)
          .collection('project')
          .doc('details')
          .set({'totalMarks': totalMarks});
      
      _detailsSet = true;
      await _fetchStudentsAndMarks();
      _showSuccess('Project details saved.');
    } catch (e) {
      _showError('Failed to save details.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentsAndMarks() async {
    // Fetch students for the class
    final classDoc = await FirebaseFirestore.instance
        .collection('courses')
        .doc(_selectedCourseId)
        .collection('classes')
        .doc(_selectedClassId)
        .get();

    if (!classDoc.exists) {
      _showError('Class document not found!');
      return;
    }

    final studentIds = List<String>.from(classDoc.data()?['students'] ?? []);
    if (studentIds.isEmpty) return;

    _students = studentIds;

    // Fetch student names
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where(FieldPath.documentId, whereIn: _students)
        .get();
    _studentNames = {
      for (var doc in studentsSnapshot.docs) doc.id: doc.data()['name'] ?? 'Unknown'
    };

    // Initialize controllers
    _marksControllers = {
      for (var id in _students) id: TextEditingController()
    };

    // Fetch existing marks
    final submissions = await FirebaseFirestore.instance
        .collection('courses')
        .doc(_selectedCourseId)
        .collection('classes')
        .doc(_selectedClassId)
        .collection('project')
        .doc('details')
        .collection('submissions')
        .get();

    for (var sub in submissions.docs) {
      if (_marksControllers.containsKey(sub.id)) {
        _marksControllers[sub.id]!.text =
            sub.data()['marksObtained']?.toString() ?? '';
      }
    }
    setState(() {});
  }

  Future<void> _saveMarks() async {
    final totalMarks = int.tryParse(_totalMarksController.text);
    if (totalMarks == null) return;

    final batch = FirebaseFirestore.instance.batch();
    bool hasError = false;

    _marksControllers.forEach((studentId, controller) {
      final marksText = controller.text;
      if (marksText.isNotEmpty) {
        final marks = int.tryParse(marksText);
        if (marks == null || marks < 0 || marks > totalMarks) {
          _showError(
              'Invalid marks for ${_studentNames[studentId]}. Must be between 0 and $totalMarks.');
          hasError = true;
          return;
        }

        final subRef = FirebaseFirestore.instance
            .collection('courses')
            .doc(_selectedCourseId)
            .collection('classes')
            .doc(_selectedClassId)
            .collection('project')
            .doc('details')
            .collection('submissions')
            .doc(studentId);
        
        batch.set(subRef, {
          'marksObtained': marks,
          'studentId': studentId,
          'studentName': _studentNames[studentId] ?? 'Unknown',
        });
      }
    });

    if (hasError) return;

    setState(() => _isSaving = true);
    try {
      await batch.commit();
      _showSuccess('Marks saved successfully!');
    } catch (e) {
      _showError('Failed to save marks.');
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
    _totalMarksController.dispose();
    _marksControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Project Marks')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CourseClassSelector(
              multiSelection: false,
              onSelectionChanged: _onSelectionChanged,
            ),
            const SizedBox(height: 16),
            if (_selectedClassId != null) _buildMarksEntry(),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildMarksEntry() {
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _totalMarksController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Project Marks',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_detailsSet,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _detailsSet ? null : _setProjectDetails,
                child: const Text('Set'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_detailsSet)
            Expanded(
              child: _students.isEmpty
                  ? const Center(child: Text('No students in this class.'))
                  : ListView.builder(
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final studentId = _students[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(_studentNames[studentId] ?? studentId),
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
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          if (_detailsSet && _students.isNotEmpty)
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
    );
  }
}
