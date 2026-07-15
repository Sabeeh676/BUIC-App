import 'package:buic_app/parent_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  _ParentLoginScreenState createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  bool _obscureText = true;
  IconData _suffixIcon = FontAwesomeIcons.eye;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
      _suffixIcon =
          _obscureText ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash;
    });
  }

  Future<void> _loginWithEmailAndPassword() async {
    if (_formKey.currentState?.validate() != true) return;

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ParentHomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Invalid student email or password. Please try again.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        default:
          message = 'An unexpected error occurred. Please try again later.';
      }
      if (mounted) {
        _showCustomSnackbar(context, message);
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackbar(
            context, 'An error occurred. Please check your connection.');
      }
    }
  }

  void _showCustomSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      duration: const Duration(seconds: 4),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(0, 150, 136, 1),
        centerTitle: true,
        title: const Text(
          'Parent Portal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 3),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Wavy background container
          Positioned.fill(child: CustomPaint(painter: WavyPainter())),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  // Logo positioned at the top
                  const SizedBox(height: 30),
                  Image.asset(
                    'assets/images/bu_logo.png',
                    width: 200,
                    height: 200,
                  ),
                  const SizedBox(height: 40),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'This Field is required.';
                            }
                            return null;
                          },
                          controller: _emailController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person),
                            hintText: 'Student Email',
                          ),
                          style: TextStyle(color: Colors.grey.shade900),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'This Field is required.';
                            }
                            return null;
                          },
                          controller: _passwordController,
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.password, size: 24),
                            hintText: 'Student Password',
                            suffixIcon: IconButton(
                              onPressed: _togglePasswordVisibility,
                              icon: FaIcon(_suffixIcon, size: 24),
                            ),
                          ),
                          style: TextStyle(color: Colors.grey.shade900),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              child: const Text(
                                'Use Student Credentials',
                                style: TextStyle(color: Colors.teal),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return const AlertDialog(
                                      content: Text(
                                        'Use your child\'s Admission Portal Credentials',
                                      ),
                                    );
                                  },
                                  barrierDismissible: true,
                                  barrierColor: Colors.black38,
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(
                                    0,
                                    150,
                                    136,
                                    1,
                                  ),
                                ),
                                onPressed: _loginWithEmailAndPassword,
                                child: const Text('Sign-In', style: TextStyle()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WavyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF008080)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.4,
        size.width,
        size.height * 0.2,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
