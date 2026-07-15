import 'package:buic_app/auth_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Enable Firestore persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // Enable persistence
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Optional: Set cache size
  );

  runApp(const ProviderScope(child: MyApp()));
}

// New Modern Color Palette
const Color primaryColor = Color(0xFF0D7E75); // A deep, modern teal
const Color secondaryColor = Color(0xFF2D3142); // A strong, neutral charcoal
const Color accentColor = Color(0xFF3E64FF); // A vibrant blue for accents
const Color backgroundColor = Color(0xFFF8F9FA); // A clean, light grey
const Color surfaceColor = Colors.white;
const Color primaryTextColor = Color(0xFF2D3142); // Charcoal for primary text
const Color secondaryTextColor = Color(
  0xFF4F5D75,
); // A softer grey for subtitles
const Color errorColor = Color(0xFFD90429); // A clear, strong red for errors

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        fontFamily: 'Poppins', // Using a modern, readable font
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 12,
          ),
          hintStyle: const TextStyle(color: secondaryTextColor, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor, width: 2.0),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
          headlineMedium: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
          bodyLarge: TextStyle(
            color: primaryTextColor,
            fontSize: 16,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: secondaryColor,
          error: errorColor,
          surface: surfaceColor,
          background: backgroundColor,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: primaryTextColor,
          onBackground: primaryTextColor,
          onError: Colors.white,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
