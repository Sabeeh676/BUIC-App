import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:dotted_border/dotted_border.dart';

class AddProject extends StatefulWidget {
  const AddProject({super.key});

  @override
  State<AddProject> createState() => _AddProjectState();
}

class _AddProjectState extends State<AddProject> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _githubLinkController = TextEditingController();
  final _demoLinkController = TextEditingController();
  final _tagController = TextEditingController();
  final _teamMemberController = TextEditingController();

  final List<String> _tags = [];
  final List<String> _teamMembers = [];
  final List<File> _images = [];
  final List<Uint8List> _imageBytesList = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _githubLinkController.dispose();
    _demoLinkController.dispose();
    _tagController.dispose();
    _teamMemberController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_images.length + _imageBytesList.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload a maximum of 5 images.')),
      );
      return;
    }

    if (kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (file.bytes != null) {
              _imageBytesList.add(file.bytes!);
            }
          }
        });
      }
    } else {
      final List<XFile> pickedFiles = await ImagePicker().pickMultiImage();
      setState(() {
        _images.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (kIsWeb) {
        _imageBytesList.removeAt(index);
      } else {
        _images.removeAt(index);
      }
    });
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty && _imageBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one project image.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      List<String> imageUrls = await _uploadImages(user);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.email!.split('@')[0])
          .get();

      String userName = "Unknown User";
      String? userProfilePic;

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        userName = data['name'] ?? "Unknown User";
        userProfilePic = data['profileImageUrl'];
      }

      final projectData = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'imageUrls': imageUrls,
        'githubUrl': _githubLinkController.text.trim(),
        'demoUrl': _demoLinkController.text.trim(),
        'tags': _tags,
        'team': [..._teamMembers, user.email!.split('@')[0]],
        'reactions': {
          'insightful': 0,
          'innovative': 0,
          'wellExecuted': 0,
          'love': 0,
        },
        'reactedBy': {},
        'ownerId': user.email!.split('@')[0],
        'ownerName': userName,
        'ownerProfilePic': userProfilePic,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('projects').add(projectData);

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<String>> _uploadImages(User user) async {
    List<Future<String>> uploadTasks = [];
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('project_images')
        .child(user.uid);

    if (kIsWeb) {
      for (int i = 0; i < _imageBytesList.length; i++) {
        final ref = storageRef.child(
          '${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        uploadTasks.add(
          ref.putData(_imageBytesList[i]).then((_) => ref.getDownloadURL()),
        );
      }
    } else {
      for (int i = 0; i < _images.length; i++) {
        final ref = storageRef.child(
          '${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        uploadTasks.add(
          ref.putFile(_images[i]).then((_) => ref.getDownloadURL()),
        );
      }
    }
    return await Future.wait(uploadTasks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add New Project', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Project Details'),
              _buildTextField(_titleController, 'Project Title', Icons.title_rounded),
              const SizedBox(height: 16),
              _buildTextField(
                _descController,
                'Description',
                Icons.description_outlined,
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Project Links'),
              _buildTextField(
                _githubLinkController,
                'GitHub URL (Optional)',
                Icons.code_rounded,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _demoLinkController,
                'Live Demo URL (Optional)',
                Icons.public_rounded,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Technologies & Skills (Max 5)'),
              _buildChipInput(_tagController, 'Add a tag (e.g., Flutter)', _tags, 5),
              const SizedBox(height: 24),
              _buildSectionHeader('Team Members (Max 4)'),
              _buildChipInput(
                _teamMemberController,
                'Add member by ID',
                _teamMembers,
                4,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Project Images (Max 5)'),
              const SizedBox(height: 8),
              _buildImagePicker(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final imageCount = kIsWeb ? _imageBytesList.length : _images.length;
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: imageCount > 0
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageCount + 1,
                  itemBuilder: (context, index) {
                    if (index == imageCount) {
                      return imageCount < 5
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: _buildAddImageButton(),
                            )
                          : const SizedBox();
                    }
                    return _buildImageThumbnail(index);
                  },
                )
              : _buildAddImageButton(isPrimary: true),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                fit: BoxFit.cover,
                image: kIsWeb
                    ? MemoryImage(_imageBytesList[index])
                    : FileImage(_images[index]) as ImageProvider,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton({bool isPrimary = false}) {
    return GestureDetector(
      onTap: _pickImages,
      child: isPrimary
          ? DottedBorder(
              borderType: BorderType.RRect,
              radius: const Radius.circular(12),
              color: Colors.grey.shade400,
              strokeWidth: 2,
              dashPattern: const [8, 4],
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 50,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload images',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 40, color: Colors.grey.shade500),
                  const SizedBox(height: 8),
                  Text('Add more', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (label.contains('Optional')) return null;
        if (value == null || value.trim().isEmpty) {
          return 'This field is required.';
        }
        return null;
      },
    );
  }

  Widget _buildChipInput(
    TextEditingController controller,
    String hint,
    List<String> list,
    int limit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (list.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: list
                .map(
                  (item) => Chip(
                    label: Text(item),
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    labelStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w500),
                    onDeleted: () => setState(() => list.remove(item)),
                    deleteIconColor: Colors.teal.withOpacity(0.7),
                  ),
                )
                .toList(),
          ),
        if (list.length < limit)
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).primaryColor,
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    setState(() {
                      list.add(controller.text.trim());
                      controller.clear();
                    });
                  }
                },
              ),
            ),
            onFieldSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                setState(() {
                  list.add(value.trim());
                  controller.clear();
                });
              }
            },
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitProject,
        icon: _isLoading
            ? Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2.0),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.publish_rounded),
        label: const Text('Submit Project'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}