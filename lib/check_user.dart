import 'package:buic_app/home_screen.dart';
import 'package:buic_app/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class CheckUser extends StatefulWidget {
  const CheckUser({super.key});

  @override
  _CheckUserState createState() => _CheckUserState();
}

class _CheckUserState extends State<CheckUser> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        // Use FutureBuilder to determine the initial page based on user authentication.
        future: checkuser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Handle the possibility of snapshot.data being null
            return snapshot.data ??
                Container(); // Return a default widget or handle it accordingly
          } else {
            return const CircularProgressIndicator(); // Show loading indicator while checking user.
          }
        },
      ),
    );
  }

  Future<Widget?> checkuser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
