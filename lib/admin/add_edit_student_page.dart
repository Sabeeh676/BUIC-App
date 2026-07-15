import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class AddEditStudentPage extends StatefulWidget {
  final DocumentSnapshot? student;

  const AddEditStudentPage({super.key, this.student});

  @override
  State<AddEditStudentPage> createState() => _AddEditStudentPageState();
}

class _AddEditStudentPageState extends State<AddEditStudentPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _enrollmentController;
  late TextEditingController _passwordController; // Added for new students
  late TextEditingController _programController;
  late TextEditingController _registrationNoController;
  late TextEditingController _degreeDurationController;
  late TextEditingController _intakeSemesterController;
  late TextEditingController _maxSemesterController;
  late TextEditingController _fatherNameController;
  late TextEditingController _phoneNoController;
  late TextEditingController _personalEmailController;
  late TextEditingController _currentAddressController;
  late TextEditingController _permanentAddressController;
  late TextEditingController _classController;
  late TextEditingController _registeredCoursesController;

  final _focusNodes = List.generate(15, (_) => FocusNode()); // Increased size
  bool _isLoading = false;
  Uint8List? _imageBytes;
  String? _profileImageUrl;
  bool get _isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    final studentData = widget.student?.data() as Map<String, dynamic>?;
    _nameController = TextEditingController(text: studentData?['name'] ?? '');
    _enrollmentController = TextEditingController(
      text: studentData?['enrollment'] ?? '',
    );
    _passwordController =
        TextEditingController(); // Initialize password controller
    _programController = TextEditingController(
      text: studentData?['program'] ?? '',
    );
    _registrationNoController = TextEditingController(
      text: studentData?['registrationNo'] ?? '',
    );
    _degreeDurationController = TextEditingController(
      text: studentData?['degreeDuration'] ?? '',
    );
    _intakeSemesterController = TextEditingController(
      text: studentData?['intakeSemester'] ?? '',
    );
    _maxSemesterController = TextEditingController(
      text: studentData?['maxSemester'] ?? '',
    );
    _fatherNameController = TextEditingController(
      text: studentData?['fatherName'] ?? '',
    );
    _phoneNoController = TextEditingController(
      text: studentData?['phoneNo'] ?? '',
    );
    _personalEmailController = TextEditingController(
      text: studentData?['personalEmail'] ?? '',
    );
    _currentAddressController = TextEditingController(
      text: studentData?['currentAddress'] ?? '',
    );
    _permanentAddressController = TextEditingController(
      text: studentData?['permanentAddress'] ?? '',
    );
    _classController = TextEditingController(text: studentData?['class'] ?? '');
    _registeredCoursesController = TextEditingController(
      text:
          (studentData?['registeredCourses'] as List<dynamic>?)?.join(', ') ??
              '',
    );
    _profileImageUrl = studentData?['profileImageUrl'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _enrollmentController.dispose();
    _passwordController.dispose();
    _programController.dispose();
    _registrationNoController.dispose();
    _degreeDurationController.dispose();
    _intakeSemesterController.dispose();
    _maxSemesterController.dispose();
    _fatherNameController.dispose();
    _phoneNoController.dispose();
    _personalEmailController.dispose();
    _currentAddressController.dispose();
    _permanentAddressController.dispose();
    _classController.dispose();
    _registeredCoursesController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _imageBytes = result.files.first.bytes;
          });
        }
      } else {
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          _imageBytes = await image.readAsBytes();
          setState(() {});
        }
      }
    } catch (e) {
      _showError('Error picking image: ${e.toString()}');
    }
  }

  Future<String?> _createAuthUser() async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('createUser');
    try {
      final result = await callable.call<Map<String, dynamic>>({
        'email': '${_enrollmentController.text.trim()}@buic.com',
        'password': _passwordController.text,
        'displayName': _nameController.text.trim(),
      });
      return result.data['uid'];
    } on FirebaseFunctionsException catch (e) {
      _showError('Failed to create auth user: ${e.message}');
      return null;
    } catch (e) {
      _showError('An unexpected error occurred: ${e.toString()}');
      return null;
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? uid;
      // Create auth user only if it's a new student
      if (!_isEditing) {
        uid = await _createAuthUser();
        if (uid == null) {
          setState(() => _isLoading = false);
          return; // Stop if user creation failed
        }
      }

      if (_imageBytes != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${_enrollmentController.text}.jpg');
        await ref.putData(_imageBytes!);
        _profileImageUrl = await ref.getDownloadURL();
      }

      final coursesList = _registeredCoursesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final studentData = {
        'name': _nameController.text,
        'enrollment': _enrollmentController.text,
        'program': _programController.text,
        'registrationNo': _registrationNoController.text,
        'degreeDuration': _degreeDurationController.text,
        'intakeSemester': _intakeSemesterController.text,
        'maxSemester': _maxSemesterController.text,
        'fatherName': _fatherNameController.text,
        'phoneNo': _phoneNoController.text,
        'personalEmail': _personalEmailController.text,
        'universityEmail': '${_enrollmentController.text}@buic.com',
        'currentAddress': _currentAddressController.text,
        'permanentAddress': _permanentAddressController.text,
        'class': _classController.text,
        'registeredCourses': coursesList,
        'profileImageUrl': _profileImageUrl,
        if (uid != null) 'uid': uid, // Add UID for new students
      };

      final firestore = FirebaseFirestore.instance;
      if (!_isEditing) {
        await firestore
            .collection('students')
            .doc(_enrollmentController.text)
            .set(studentData);
      } else {
        await firestore
            .collection('students')
            .doc(widget.student!.id)
            .update(studentData);
      }
      Navigator.of(context).pop();
    } catch (e) {
      _showError('Error saving student: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Student' : 'Add Student'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveStudent,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    return _buildTwoColumnLayout();
                  } else {
                    return _buildSingleColumnLayout();
                  }
                },
              ),
            ),
    );
  }

  Widget _buildSingleColumnLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: _buildFormFields()),
    );
  }

  Widget _buildTwoColumnLayout() {
    final fields = _buildFormFields();
    final midPoint = (fields.length / 2).ceil();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: fields.sublist(0, midPoint))),
          const SizedBox(width: 24),
          Expanded(child: Column(children: fields.sublist(midPoint))),
        ],
      ),
    );
  }

  List<Widget> _buildFormFields() {
    return [
      SizedBox(
        height: 120,
        child: Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: _imageBytes != null
                    ? MemoryImage(_imageBytes!)
                    : (_profileImageUrl != null
                            ? CachedNetworkImageProvider(_profileImageUrl!)
                            : null) as ImageProvider?,
                child: _imageBytes == null && _profileImageUrl == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _pickImage,
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      _buildTextField(
        controller: _nameController,
        label: 'Full Name',
        focusNode: _focusNodes[0],
        nextFocusNode: _focusNodes[1],
        validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
      ),
      _buildTextField(
        controller: _enrollmentController,
        label: 'Enrollment ID',
        focusNode: _focusNodes[1],
        nextFocusNode: _focusNodes[2],
        enabled: !_isEditing, // Cannot change enrollment ID after creation
        validator: (value) =>
            value!.isEmpty ? 'Please enter an enrollment ID' : null,
      ),
      // Only show password field for new students
      if (!_isEditing)
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          focusNode: _focusNodes[2],
          nextFocusNode: _focusNodes[3],
          obscureText: true,
          validator: (value) {
            if (value!.isEmpty) return 'Please enter a password';
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      _buildTextField(
        controller: _programController,
        label: 'Program',
        focusNode: _focusNodes[3],
        nextFocusNode: _focusNodes[4],
        validator: (value) => value!.isEmpty ? 'Please enter a program' : null,
      ),
      _buildTextField(
        controller: _registrationNoController,
        label: 'Registration No.',
        focusNode: _focusNodes[4],
        nextFocusNode: _focusNodes[5],
      ),
      _buildTextField(
        controller: _degreeDurationController,
        label: 'Degree Duration',
        focusNode: _focusNodes[5],
        nextFocusNode: _focusNodes[6],
      ),
      _buildTextField(
        controller: _intakeSemesterController,
        label: 'Intake Semester',
        focusNode: _focusNodes[6],
        nextFocusNode: _focusNodes[7],
      ),
      _buildTextField(
        controller: _maxSemesterController,
        label: 'Max Semester',
        focusNode: _focusNodes[7],
        nextFocusNode: _focusNodes[8],
      ),
      _buildTextField(
        controller: _fatherNameController,
        label: 'Father Name',
        focusNode: _focusNodes[8],
        nextFocusNode: _focusNodes[9],
      ),
      _buildTextField(
        controller: _phoneNoController,
        label: 'Phone No',
        focusNode: _focusNodes[9],
        nextFocusNode: _focusNodes[10],
        keyboardType: TextInputType.phone,
      ),
      _buildTextField(
        controller: _personalEmailController,
        label: 'Personal Email',
        focusNode: _focusNodes[10],
        nextFocusNode: _focusNodes[11],
        keyboardType: TextInputType.emailAddress,
      ),
      _buildTextField(
        controller: _currentAddressController,
        label: 'Current Address',
        focusNode: _focusNodes[11],
        nextFocusNode: _focusNodes[12],
      ),
      _buildTextField(
        controller: _permanentAddressController,
        label: 'Permanent Address',
        focusNode: _focusNodes[12],
        nextFocusNode: _focusNodes[13],
      ),
      _buildTextField(
        controller: _classController,
        label: 'Class (e.g., BSCS-8A)',
        focusNode: _focusNodes[13],
        nextFocusNode: _focusNodes[14],
      ),
      _buildTextField(
        controller: _registeredCoursesController,
        label: 'Registered Courses (comma-separated)',
        focusNode: _focusNodes[14],
      ),
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool obscureText = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[200],
        ),
        keyboardType: keyboardType,
        validator: validator,
        onFieldSubmitted: (_) {
          if (nextFocusNode != null) {
            FocusScope.of(context).requestFocus(nextFocusNode);
          }
        },
      ),
    );
  }
}