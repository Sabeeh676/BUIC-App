import 'package:buic_app/teacher_management/course_class_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

class UploadMisc extends ConsumerStatefulWidget {
  const UploadMisc({super.key});

  @override
  _UploadMiscState createState() => _UploadMiscState();
}

class _UploadMiscState extends ConsumerState<UploadMisc> {
  bool isUploading = false;
  PlatformFile? selectedFile;
  String? selectedCategory;
  final TextEditingController customTitleController = TextEditingController();
  String? _selectedCourseId;
  List<String> _selectedClassIds = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
        title: const Text(
          'Upload Miscellaneous',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  // File Picker
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedFile != null
                              ? 'File: ${selectedFile!.name}'
                              : 'No File Selected',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'pptx', 'docx'],
                          );
                          if (result != null) {
                            setState(() {
                              selectedFile = result.files.first;
                            });
                          }
                        },
                        child: const Text('Pick File'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Radio Buttons for Category
                  const Text('Select Category:'),
                  RadioListTile<String>(
                    title: const Text('Book'),
                    value: 'Book',
                    groupValue: selectedCategory,
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Course Outline'),
                    value: 'Course Outline',
                    groupValue: selectedCategory,
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Other'),
                    value: 'Other',
                    groupValue: selectedCategory,
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  if (selectedCategory == 'Other')
                    TextField(
                      controller: customTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Enter Title',
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Submit Button
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_selectedCourseId != null &&
                            _selectedClassIds.isNotEmpty &&
                            selectedFile != null &&
                            (selectedCategory != 'Other' ||
                                customTitleController.text.isNotEmpty)) {
                          setState(() {
                            isUploading = true;
                          });
                          await uploadMisc();
                          setState(() {
                            isUploading = false;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please complete all fields and select a course/class!',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUploading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Future<void> uploadMisc() async {
    final courseId = _selectedCourseId;
    final classIds = _selectedClassIds;

    if (courseId == null || classIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course and at least one class.'),
        ),
      );
      return;
    }

    try {
      final fileName = selectedFile!.name;

      final storageRef = FirebaseStorage.instance.ref().child(
        'misc/$courseId/$fileName',
      );
      if (kIsWeb) {
        await storageRef.putData(selectedFile!.bytes!);
      } else {
        await storageRef.putFile(File(selectedFile!.path!));
      }
      final fileUrl = await storageRef.getDownloadURL();

      final title = selectedCategory == 'Other'
          ? customTitleController.text
          : selectedCategory;

      final miscData = {'file_url': fileUrl, 'title': title};

      final batch = FirebaseFirestore.instance.batch();

      for (final classId in classIds) {
        final newMiscDocRef = FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .collection('classes')
            .doc(classId)
            .collection('misc')
            .doc();
        batch.set(newMiscDocRef, miscData);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miscellaneous uploaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    }
  }
}
