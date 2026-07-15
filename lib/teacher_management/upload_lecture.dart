import 'package:buic_app/teacher_management/course_class_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class LectureUploadPage extends StatefulWidget {
  const LectureUploadPage({super.key});

  @override
  _LectureUploadPageState createState() => _LectureUploadPageState();
}

class _LectureUploadPageState extends State<LectureUploadPage> {
  bool isUploading = false;
  TextEditingController titleController = TextEditingController();
  TextEditingController externalLinksController = TextEditingController();
  PlatformFile? selectedFile;
  String? _selectedCourseId;
  List<String> _selectedClassIds = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Lecture'), centerTitle: true),
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
                      label: 'Lecture Title',
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: externalLinksController,
                      label: 'Reference Links (comma-separated)',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    _buildFilePicker(),
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
            allowedExtensions: ['pdf', 'docx', 'pptx', 'ppt'],
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

  Widget _buildUploadButton() {
    return Center(
      child: ElevatedButton(
        onPressed: isUploading
            ? null
            : () async {
                if (titleController.text.isNotEmpty && selectedFile != null) {
                  setState(() => isUploading = true);
                  await uploadLecture();
                  setState(() => isUploading = false);
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
            : const Text('Upload Lecture', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Future<void> uploadLecture() async {
    final courseId = _selectedCourseId;
    final classIds = _selectedClassIds;

    if (courseId == null || classIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course or Class not selected.')),
      );
      return;
    }

    try {
      final fileName = selectedFile!.name;

      // Upload file to a shared course directory in Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'lectures/$courseId/$fileName',
      );
      if (kIsWeb) {
        await storageRef.putData(selectedFile!.bytes!);
      } else {
        await storageRef.putFile(File(selectedFile!.path!));
      }
      final fileUrl = await storageRef.getDownloadURL();

      // External links handling
      final externalLinksText = externalLinksController.text.trim();
      final externalLinks = externalLinksText.isNotEmpty
          ? externalLinksText.split(',').map((link) => link.trim()).toList()
          : null;

      // Use a batch write to create a document for each class
      final batch = FirebaseFirestore.instance.batch();

      for (final classId in classIds) {
        final lectureRef = FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .collection('classes')
            .doc(classId)
            .collection('lectures')
            .doc();
        final lectureData = {
          'title': titleController.text,
          'courseId': courseId,
          'classId': classId,
          'externalLinks': externalLinks,
          'fileUrl': fileUrl,
          'uploadTime': FieldValue.serverTimestamp(),
        };
        batch.set(lectureRef, lectureData);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lecture uploaded successfully!')),
      );

      // Clear the form
      titleController.clear();
      externalLinksController.clear();
      setState(() => selectedFile = null);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading lecture: $e')));
    }
  }
}
