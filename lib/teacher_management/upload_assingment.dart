import 'package:buic_app/teacher_management/course_class_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:io';

class AssignmentUploadPage extends StatefulWidget {
  const AssignmentUploadPage({super.key});

  @override
  _AssignmentUploadPageState createState() => _AssignmentUploadPageState();
}

class _AssignmentUploadPageState extends State<AssignmentUploadPage> {
  bool isUploading = false;
  TextEditingController titleController = TextEditingController();
  TextEditingController totalMarksController = TextEditingController();
  DateTime? dueDate;
  PlatformFile? selectedFile;
  bool isTenMarks = false;
  String? _selectedCourseId;
  List<String> _selectedClassIds = [];

  Future<void> uploadAssignment() async {
    final courseId = _selectedCourseId;
    final classIds = _selectedClassIds;

    if (courseId == null || classIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course or Class not selected.')),
      );
      return;
    }

    if (selectedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No file selected.')));
      return;
    }

    try {
      setState(() => isUploading = true);

      final fileName = selectedFile!.name;
      final storageRef = FirebaseStorage.instance.ref().child(
        'assignments/$courseId/$fileName',
      );

      if (kIsWeb) {
        await storageRef.putData(selectedFile!.bytes!);
      } else {
        await storageRef.putFile(File(selectedFile!.path!));
      }

      final fileUrl = await storageRef.getDownloadURL();
      final int totalMarks = isTenMarks
          ? 10
          : int.tryParse(totalMarksController.text) ?? 0;

      final batch = FirebaseFirestore.instance.batch();
      for (final classId in classIds) {
        final assignmentRef = FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .collection('classes')
            .doc(classId)
            .collection('assignments')
            .doc();
        final assignmentData = {
          'title': titleController.text,
          'courseId': courseId,
          'classId': classId,
          'dueDate': dueDate,
          'fileUrl': fileUrl,
          'totalMarks': totalMarks,
          'uploadTime': FieldValue.serverTimestamp(),
        };
        batch.set(assignmentRef, assignmentData);
      }
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment uploaded successfully!')),
      );

      // Clear the form
      titleController.clear();
      totalMarksController.clear();
      setState(() {
        dueDate = null;
        selectedFile = null;
        isTenMarks = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading assignment: $e')));
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Assignment'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            CourseClassSelector(
              onSelectionChanged: (courseId, classIds) {
                setState(() {
                  _selectedCourseId = courseId;
                  _selectedClassIds = classIds;
                });
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: titleController,
                      label: 'Assignment Title',
                    ),
                    const SizedBox(height: 20),
                    _buildDatePicker(),
                    const SizedBox(height: 20),
                    _buildFilePicker(),
                    const SizedBox(height: 20),
                    _buildMarksInput(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16, color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Row(
      children: [
        Expanded(
          child: Text(
            dueDate != null
                ? 'Due Date: ${DateFormat('yyyy-MM-dd').format(dueDate!)}'
                : 'No Due Date Selected',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2026),
            );
            if (pickedDate != null) {
              setState(() => dueDate = pickedDate);
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Pick Date', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildFilePicker() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.attach_file, size: 28),
      title: Text(
        selectedFile != null
            ? 'File: ${selectedFile!.name}'
            : 'No File Selected',
        style: const TextStyle(fontSize: 16),
      ),
      trailing: ElevatedButton(
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'docx', 'pptx', 'ppt', 'doc'],
          );
          if (result != null) {
            setState(() => selectedFile = result.files.first);
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: const Text('Pick File', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildMarksInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Checkbox(
              value: isTenMarks,
              onChanged: (value) {
                setState(() {
                  isTenMarks = value!;
                  if (isTenMarks) totalMarksController.clear();
                });
              },
            ),
            const Text('Set Total Marks to 10', style: TextStyle(fontSize: 16)),
          ],
        ),
        if (!isTenMarks)
          SizedBox(
            width: 100,
            child: TextField(
              controller: totalMarksController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Marks',
                border: OutlineInputBorder(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return Center(
      child: ElevatedButton(
        onPressed: isUploading
            ? null
            : () async {
                if (titleController.text.isNotEmpty &&
                    dueDate != null &&
                    selectedFile != null &&
                    (isTenMarks ||
                        (totalMarksController.text.isNotEmpty &&
                            int.tryParse(totalMarksController.text) != null))) {
                  await uploadAssignment();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        child: isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Upload Assignment', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
