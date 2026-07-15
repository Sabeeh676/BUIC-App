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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _userData = {};
  bool isLoading = false;
  bool _isPageLoading = true;

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
    final cachedData = prefs.getString('user_profile_data');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _userData = json.decode(cachedData);
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserDataFromFirestore() async {
    if (_userData.isEmpty) {
      if (mounted) setState(() => _isPageLoading = true);
    }
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String enrollmentId = user.email!.split('@')[0];
        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(enrollmentId)
            .get();

        if (studentDoc.exists) {
          final data = studentDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _userData = {
                'name': data['name'] ?? 'N/A',
                'enrollment': data['enrollment'] ?? 'N/A',
                'program': data['program'] ?? 'N/A',
                'registrationNo': data['registrationNo'] ?? 'N/A',
                'degreeDuration': data['degreeDuration'] ?? 'N/A',
                'intakeSemester': data['intakeSemester'] ?? 'N/A',
                'maxSemester': data['maxSemester'] ?? 'N/A',
                'fatherName': data['fatherName'] ?? 'N/A',
                'phoneNo': data['phoneNo'] ?? 'N/A',
                'personalEmail': data['personalEmail'] ?? 'N/A',
                'universityEmail': data['universityEmail'] ?? 'N/A',
                'currentAddress': data['currentAddress'] ?? 'N/A',
                'permanentAddress': data['permanentAddress'] ?? 'N/A',
                'profileImageUrl': data['profileImageUrl'],
              };
            });
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_profile_data', json.encode(_userData));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user data: $e')),
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
    setState(() => isLoading = true);
    try {
      Uint8List? fileBytes;
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
        if (result == null || result.files.isEmpty) return;
        fileBytes = result.files.first.bytes;
      } else {
        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
        fileBytes = await File(image.path).readAsBytes();
      }

      if (fileBytes == null) return;

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String enrollmentId = user.email!.split('@')[0];
        Reference storageRef = _storage.ref().child('profile_images/$enrollmentId/profile.jpg');
        await storageRef.putData(fileBytes);
        String downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('students')
            .doc(enrollmentId)
            .update({'profileImageUrl': downloadUrl});

        if (mounted) {
          setState(() {
            _userData['profileImageUrl'] = downloadUrl;
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile_data', json.encode(_userData));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully!')),
        );
      }
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
              backgroundImage: _userData['profileImageUrl'] != null
                  ? CachedNetworkImageProvider(_userData['profileImageUrl'])
                  : null,
              child: _userData['profileImageUrl'] == null
                  ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userData['name'] ?? 'N/A',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                _userData['program'] ?? 'N/A',
                style: const TextStyle(color: Colors.white),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                children: [
                  itemProfile('Enrollment', _userData['enrollment'] ?? 'N/A'),
                  itemProfile('Registration No.', _userData['registrationNo'] ?? 'N/A'),
                  itemProfile('Intake Semester', _userData['intakeSemester'] ?? 'N/A'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  itemProfile('Program', _userData['program'] ?? 'N/A'),
                  itemProfile('Degree Duration', _userData['degreeDuration'] ?? 'N/A'),
                  itemProfile('Max Semester', _userData['maxSemester'] ?? 'N/A'),
                ],
              ),
            ),
          ],
        ),
        itemProfile('Father Name', _userData['fatherName'] ?? 'N/A'),
        itemProfile('Phone No', _userData['phoneNo'] ?? 'N/A'),
        itemProfile('Personal Email', _userData['personalEmail'] ?? 'N/A'),
        itemProfile('University Email', _userData['universityEmail'] ?? 'N/A'),
        itemProfile('Current Address', _userData['currentAddress'] ?? 'N/A'),
        itemProfile('Permanent Address', _userData['permanentAddress'] ?? 'N/A'),
      ],
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
        title: Text(title),
        subtitle: Text(subtitle),
        tileColor: Colors.white,
      ),
    );
  }
}