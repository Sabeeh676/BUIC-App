import 'package:buic_app/admin/admin_login.dart';
import 'package:buic_app/login_screen.dart';
import 'package:buic_app/parent_login.dart';
import 'package:buic_app/teacher_login.dart';
import 'package:flutter/material.dart';

class WhoAmI extends StatefulWidget {
  const WhoAmI({super.key});

  @override
  State<WhoAmI> createState() => _WhoAmIState();
}

class _WhoAmIState extends State<WhoAmI> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.blue.shade50
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Choose Your Role',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your role to proceed with the app',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TeacherLogin()),
                  ),
                  child: _buildRoleContainer(
                    context,
                    color: const Color(0xFF0D7E75), // Teal
                    text: 'Teacher',
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  ),
                  child: _buildRoleContainer(
                    context,
                    color: const Color(0xFF3E64FF), // Vibrant Blue
                    text: 'Student',
                    icon: Icons.school_outlined,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminLogin()),
                  ),
                  child: _buildRoleContainer(
                    context,
                    color: const Color(0xFF2D3142), // Charcoal
                    text: 'Admin',
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ParentLoginScreen()),
                  ),
                  child: _buildRoleContainer(
                    context,
                    color: Colors.grey.shade500,
                    text: 'Parent',
                    icon: Icons.family_restroom_outlined,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleContainer(
    BuildContext context, {
    required Color color,
    required String text,
    required IconData icon,
  }) {
    return Container(
      height: 140,
      width: 270,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
