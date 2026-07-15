import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class AddEditTeacherPage extends StatefulWidget {
  final DocumentSnapshot? teacher;

  const AddEditTeacherPage({super.key, this.teacher});

  @override
  State<AddEditTeacherPage> createState() => _AddEditTeacherPageState();
}

class _AddEditTeacherPageState extends State<AddEditTeacherPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController; // Added for new teachers
  late TextEditingController _departmentController;
  late TextEditingController _employeeIdController;
  late TextEditingController _designationController;
  late TextEditingController _officeLocationController;
  late TextEditingController _phoneNoController;
  late TextEditingController _specializationController;

  final _focusNodes = List.generate(9, (_) => FocusNode()); // Increased size
  bool _isLoading = false;
  Uint8List? _imageBytes;
  String? _profileImageUrl;
  Map<String, List<dynamic>> _classCourse = {};
  bool get _isEditing => widget.teacher != null;

  @override
  void initState() {
    super.initState();
    final teacherData = widget.teacher?.data() as Map<String, dynamic>?;
    _nameController = TextEditingController(text: teacherData?['name'] ?? '');
    _emailController = TextEditingController(text: teacherData?['email'] ?? '');
    _passwordController = TextEditingController(); // Initialize password controller
    _departmentController = TextEditingController(
      text: teacherData?['department'] ?? '',
    );
    _employeeIdController = TextEditingController(
      text: teacherData?['employeeId'] ?? '',
    );
    _designationController = TextEditingController(
      text: teacherData?['designation'] ?? '',
    );
    _officeLocationController = TextEditingController(
      text: teacherData?['officeLocation'] ?? '',
    );
    _phoneNoController = TextEditingController(
      text: teacherData?['phoneNo'] ?? '',
    );
    _specializationController = TextEditingController(
      text: teacherData?['specialization'] ?? '',
    );
    _profileImageUrl = teacherData?['profileImageUrl'];
    if (teacherData?['class_course'] != null) {
      _classCourse = (teacherData!['class_course'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<dynamic>.from(value)),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _departmentController.dispose();
    _employeeIdController.dispose();
    _designationController.dispose();
    _officeLocationController.dispose();
    _phoneNoController.dispose();
    _specializationController.dispose();
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
        'email': _emailController.text.trim(),
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

  Future<void> _saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? uid;
      // Create auth user only if it's a new teacher
      if (!_isEditing) {
        uid = await _createAuthUser();
        if (uid == null) {
          setState(() => _isLoading = false);
          return; // Stop if user creation failed
        }
      }

      final teacherData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'department': _departmentController.text,
        'employeeId': _employeeIdController.text,
        'designation': _designationController.text,
        'officeLocation': _officeLocationController.text,
        'phoneNo': _phoneNoController.text,
        'specialization': _specializationController.text,
        'profileImageUrl': _profileImageUrl,
        'class_course': _classCourse,
        if (uid != null) 'uid': uid, // Add UID for new teachers
      };

      final firestore = FirebaseFirestore.instance;
      DocumentReference teacherRef;

      if (!_isEditing) {
        // Use employeeId as document ID for new teachers for predictability
        teacherRef =
            firestore.collection('teachers').doc(_employeeIdController.text);
        await teacherRef.set(teacherData);
      } else {
        teacherRef = firestore.collection('teachers').doc(widget.teacher!.id);
        await teacherRef.update(teacherData);
      }

      if (_imageBytes != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${teacherRef.id}.jpg');
        await ref.putData(_imageBytes!);
        final downloadUrl = await ref.getDownloadURL();
        await teacherRef.update({'profileImageUrl': downloadUrl});
      }

      Navigator.of(context).pop();
    } catch (e) {
      _showError('Error saving teacher: ${e.toString()}');
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
        title: Text(_isEditing ? 'Edit Teacher' : 'Add Teacher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveTeacher,
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
        controller: _employeeIdController,
        label: 'Employee ID (Used as Username)',
        focusNode: _focusNodes[1],
        nextFocusNode: _focusNodes[2],
        enabled: !_isEditing, // Cannot change employee ID after creation
        validator: (value) =>
            value!.isEmpty ? 'Please enter an employee ID' : null,
      ),
      _buildTextField(
        controller: _emailController,
        label: 'Email',
        focusNode: _focusNodes[2],
        nextFocusNode: _focusNodes[3],
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value!.isEmpty) return 'Please enter an email';
          if (!value.contains('@')) return 'Enter a valid email';
          return null;
        },
      ),
      // Only show password field for new teachers
      if (!_isEditing)
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          focusNode: _focusNodes[3],
          nextFocusNode: _focusNodes[4],
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
        controller: _departmentController,
        label: 'Department',
        focusNode: _focusNodes[4],
        nextFocusNode: _focusNodes[5],
        validator: (value) =>
            value!.isEmpty ? 'Please enter a department' : null,
      ),
      _buildTextField(
        controller: _designationController,
        label: 'Designation (e.g., Professor)',
        focusNode: _focusNodes[5],
        nextFocusNode: _focusNodes[6],
      ),
      _buildTextField(
        controller: _officeLocationController,
        label: 'Office Location',
        focusNode: _focusNodes[6],
        nextFocusNode: _focusNodes[7],
      ),
      _buildTextField(
        controller: _phoneNoController,
        label: 'Phone No',
        focusNode: _focusNodes[7],
        nextFocusNode: _focusNodes[8],
        keyboardType: TextInputType.phone,
      ),
      _buildTextField(
        controller: _specializationController,
        label: 'Specialization',
        focusNode: _focusNodes[8],
      ),
      _buildCourseAssignmentSection(),
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

  Widget _buildCourseAssignmentSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Course Assignments',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: () => _showAssignmentDialog(),
              ),
            ],
          ),
          const Divider(),
          if (_classCourse.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('No courses assigned.'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _classCourse.keys.length,
              itemBuilder: (context, index) {
                String classId = _classCourse.keys.elementAt(index);
                List<dynamic> courseIds = _classCourse[classId]!;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('Class: $classId'),
                    subtitle: Text('Courses: ${courseIds.join(', ')}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAssignmentDialog(
                            classId: classId,
                            courseIds: courseIds.cast<String>(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _classCourse.remove(classId);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showAssignmentDialog({
    String? classId,
    List<String>? courseIds,
  }) async {
    final classController = TextEditingController(text: classId ?? '');
    final coursesController = TextEditingController(
      text: courseIds?.join(', ') ?? '',
    );
    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(classId == null ? 'Add Assignment' : 'Edit Assignment'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: classController,
                  decoration: const InputDecoration(
                    labelText: 'Class ID (e.g., BSCS-8A)',
                  ),
                  readOnly: classId != null,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a class ID' : null,
                ),
                TextFormField(
                  controller: coursesController,
                  decoration: const InputDecoration(
                    labelText: 'Course IDs (comma-separated)',
                    hintText: 'e.g., CS101, MA203',
                  ),
                  validator: (value) => value!.isEmpty
                      ? 'Please enter at least one course ID'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  final newClassId = classController.text.trim();
                  final newCourseIds = coursesController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  setState(() {
                    _classCourse[newClassId] = newCourseIds;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}