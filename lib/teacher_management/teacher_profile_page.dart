import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({super.key});

  @override
  _TeacherProfilePageState createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  Map<String, dynamic> _teacherData = {};
  bool isLoading = false;
  bool _isPageLoading = true;
  String? _teacherDocId;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await _fetchUserDataFromCache();
    await _fetchUserDataFromFirestore();
  }

  Future<void> _fetchUserDataFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('teacher_profile_data');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _teacherData = json.decode(cachedData);
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserDataFromFirestore() async {
    if (_teacherData.isEmpty) {
      if (mounted) setState(() => _isPageLoading = true);
    }
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot teacherQuery = await FirebaseFirestore.instance
            .collection('teachers')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          final teacherDoc = teacherQuery.docs.first;
          _teacherDocId = teacherDoc.id;
          final data = teacherDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _teacherData = {
                'name': data['name'] ?? 'N/A',
                'email': data['email'] ?? 'N/A',
                'department': data['department'] ?? 'N/A',
                'employeeId': data['employeeId'] ?? 'N/A',
                'designation': data['designation'] ?? 'N/A',
                'officeLocation': data['officeLocation'] ?? 'N/A',
                'phoneNo': data['phoneNo'] ?? 'N/A',
                'specialization': data['specialization'] ?? 'N/A',
                'profileImageUrl': data['profileImageUrl'],
              };
            });
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'teacher_profile_data', json.encode(_teacherData));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching teacher data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_teacherDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile. Teacher ID not found.')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      Uint8List? fileBytes;
      if (kIsWeb) {
        FilePickerResult? result =
            await FilePicker.platform.pickFiles(type: FileType.image);
        if (result == null || result.files.isEmpty) {
          setState(() => isLoading = false);
          return;
        }
        fileBytes = result.files.first.bytes;
      } else {
        final XFile? image =
            await _picker.pickImage(source: ImageSource.gallery);
        if (image == null) {
          setState(() => isLoading = false);
          return;
        }
        fileBytes = await File(image.path).readAsBytes();
      }

      if (fileBytes == null) {
        setState(() => isLoading = false);
        return;
      }

      Reference storageRef =
          _storage.ref().child('profile_images/$_teacherDocId/profile.jpg');
      await storageRef.putData(fileBytes);
      String downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(_teacherDocId)
          .update({'profileImageUrl': downloadUrl});

      if (mounted) {
        setState(() {
          _teacherData['profileImageUrl'] = downloadUrl;
        });
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('teacher_profile_data', json.encode(_teacherData));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading profile image: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showEditIcon() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile Picture'),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadProfileImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
      ),
      body: _isPageLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildProfileDetails(),
                    ],
                  ),
                ),
                if (isLoading)
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: Row(
        children: [
          const Padding(padding: EdgeInsets.only(left: 35)),
          GestureDetector(
            onLongPress: _showEditIcon,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: _teacherData['profileImageUrl'] != null
                  ? CachedNetworkImageProvider(_teacherData['profileImageUrl'])
                  : null,
              child: _teacherData['profileImageUrl'] == null
                  ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _teacherData['name'] ?? 'N/A',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _teacherData['designation'] ?? 'Teacher',
                  style: const TextStyle(color: Colors.white),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          itemProfile('Employee ID', _teacherData['employeeId'] ?? 'N/A'),
          itemProfile('Email', _teacherData['email'] ?? 'N/A'),
          itemProfile('Department', _teacherData['department'] ?? 'N/A'),
          itemProfile('Specialization', _teacherData['specialization'] ?? 'N/A'),
          itemProfile('Phone No', _teacherData['phoneNo'] ?? 'N/A'),
          itemProfile('Office Location', _teacherData['officeLocation'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget itemProfile(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            color: Colors.teal.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
        tileColor: Colors.white,
      ),
    );
  }
}