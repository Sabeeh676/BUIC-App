import 'package:buic_app/home_screen.dart';
import 'package:buic_app/splash_screen.dart';
import 'package:buic_app/teacher_management/teacher_home_screen.dart';
import 'package:buic_app/whoami.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String> _getUserRole(User user) async {
    // Check if the user is a teacher.
    // I am assuming the teacher's username is their UID in the 'teachers' collection.
    // The login logic for teachers uses a username, which might not be the UID.
    // This part might need adjustment based on the actual Firestore structure.
    // For now, I will check for the user's email in the 'teachers' collection,
    // as the teacher login logic fetches the email from there.

    final querySnapshot = await FirebaseFirestore.instance
        .collection('teachers')
        .where('email', isEqualTo: user.email)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return 'teacher';
    }

    // Add similar logic for students if needed, for now, default to student
    return 'student';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in, check their role
          return FutureBuilder<String>(
            future: _getUserRole(snapshot.data!),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              if (roleSnapshot.hasData) {
                if (roleSnapshot.data == 'teacher') {
                  return const TeacherHomePage();
                } else {
                  return const HomeScreen();
                }
              }

              // If role cannot be determined, fallback to role selection
              return const WhoAmI();
            },
          );
        } else {
          // User is not logged in
          return const WhoAmI();
        }
      },
    );
  }
}
