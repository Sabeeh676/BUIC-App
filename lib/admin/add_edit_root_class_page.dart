import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEditRootClassPage extends StatefulWidget {
  final DocumentSnapshot? classDoc;

  const AddEditRootClassPage({super.key, this.classDoc});

  @override
  State<AddEditRootClassPage> createState() => _AddEditRootClassPageState();
}

class _AddEditRootClassPageState extends State<AddEditRootClassPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _classNameController;
  late TextEditingController _academicYearController;
  late TextEditingController _departmentController;
  late TextEditingController _coursesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final classData = widget.classDoc?.data() as Map<String, dynamic>?;

    _classNameController = TextEditingController(text: widget.classDoc?.id ?? '');
    _academicYearController =
        TextEditingController(text: classData?['academicYear'] ?? '');
    _departmentController =
        TextEditingController(text: classData?['department'] ?? '');
    _coursesController = TextEditingController(
        text: (classData?['courses'] as List<dynamic>?)?.join(', ') ?? '');
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _academicYearController.dispose();
    _departmentController.dispose();
    _coursesController.dispose();
    super.dispose();
  }

  Future<void> _saveClass() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final coursesList = _coursesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final classData = {
        'academicYear': _academicYearController.text,
        'department': _departmentController.text,
        'courses': coursesList,
      };

      try {
        final firestore = FirebaseFirestore.instance;
        final docId = _classNameController.text;

        if (widget.classDoc == null) {
          await firestore.collection('classes').doc(docId).set(classData);
        } else {
          await firestore.collection('classes').doc(docId).update(classData);
        }
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving class: ${e.toString()}')),
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
        title: Text(widget.classDoc == null ? 'Add Class' : 'Edit Class'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveClass,
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
                    TextFormField(
                      controller: _classNameController,
                      decoration: const InputDecoration(
                        labelText: 'Class Name (e.g., BSCS-8A)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a class name' : null,
                      enabled: widget.classDoc == null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _academicYearController,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year (e.g., 2024)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty
                          ? 'Please enter an academic year'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department (e.g., Computer Science)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a department' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _coursesController,
                      decoration: const InputDecoration(
                        labelText: 'Courses (comma-separated)',
                        hintText: 'e.g., CS101, MA203, EE301',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter course IDs' : null,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
