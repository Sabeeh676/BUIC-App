import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEditSemesterPage extends StatefulWidget {
  final String studentId;
  final DocumentSnapshot? semesterDoc;

  const AddEditSemesterPage({
    super.key,
    required this.studentId,
    this.semesterDoc,
  });

  @override
  State<AddEditSemesterPage> createState() => _AddEditSemesterPageState();
}

class _AddEditSemesterPageState extends State<AddEditSemesterPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _semesterNameController;
  late TextEditingController _gpaController;
  late TextEditingController _cgpaController;
  late TextEditingController _codesController;
  late TextEditingController _titlesController;
  late TextEditingController _creditsController;
  late TextEditingController _gradePointsController;
  late TextEditingController _gradesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final semesterData = widget.semesterDoc?.data() as Map<String, dynamic>?;

    _semesterNameController = TextEditingController(text: widget.semesterDoc?.id ?? '');
    _gpaController = TextEditingController(text: semesterData?['GPA']?.toString() ?? '');
    _cgpaController = TextEditingController(text: semesterData?['CGPA']?.toString() ?? '');
    _codesController = TextEditingController(text: (semesterData?['Code'] as List<dynamic>?)?.join(', ') ?? '');
    _titlesController = TextEditingController(text: (semesterData?['Title'] as List<dynamic>?)?.join(', ') ?? '');
    _creditsController = TextEditingController(text: (semesterData?['CreditHours'] as List<dynamic>?)?.join(', ') ?? '');
    _gradePointsController = TextEditingController(text: (semesterData?['GradePoints'] as List<dynamic>?)?.join(', ') ?? '');
    _gradesController = TextEditingController(text: (semesterData?['Grade'] as List<dynamic>?)?.join(', ') ?? '');
  }

  @override
  void dispose() {
    _semesterNameController.dispose();
    _gpaController.dispose();
    _cgpaController.dispose();
    _codesController.dispose();
    _titlesController.dispose();
    _creditsController.dispose();
    _gradePointsController.dispose();
    _gradesController.dispose();
    super.dispose();
  }

  List<String> _parseList(String text) {
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _saveSemester() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final semesterData = {
        'GPA': double.tryParse(_gpaController.text) ?? 0.0,
        'CGPA': double.tryParse(_cgpaController.text) ?? 0.0,
        'Code': _parseList(_codesController.text),
        'Title': _parseList(_titlesController.text),
        'CreditHours': _parseList(_creditsController.text).map((e) => int.tryParse(e) ?? 0).toList(),
        'GradePoints': _parseList(_gradePointsController.text).map((e) => double.tryParse(e) ?? 0.0).toList(),
        'Grade': _parseList(_gradesController.text),
      };

      try {
        final collection = FirebaseFirestore.instance
            .collection('transcripts')
            .doc(widget.studentId)
            .collection('semesters');

        if (widget.semesterDoc == null) {
          await collection.doc(_semesterNameController.text).set(semesterData);
        } else {
          await collection.doc(widget.semesterDoc!.id).update(semesterData);
        }
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving semester: ${e.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.semesterDoc == null ? 'Add Semester' : 'Edit Semester'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSemester,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildTextField(controller: _semesterNameController, label: 'Semester Name (e.g., Spring-2024)', enabled: widget.semesterDoc == null),
                    _buildTextField(controller: _gpaController, label: 'GPA', keyboardType: TextInputType.number),
                    _buildTextField(controller: _cgpaController, label: 'CGPA', keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    const Text('Enter course details, separated by commas'),
                    _buildTextField(controller: _codesController, label: 'Course Codes'),
                    _buildTextField(controller: _titlesController, label: 'Course Titles'),
                    _buildTextField(controller: _creditsController, label: 'Credit Hours'),
                    _buildTextField(controller: _gradePointsController, label: 'Grade Points'),
                    _buildTextField(controller: _gradesController, label: 'Grades'),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: (value) => value!.isEmpty ? 'Please enter a value' : null,
      ),
    );
  }
}
