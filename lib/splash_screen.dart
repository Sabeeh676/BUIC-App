import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation1;
  late Animation<double> _animation2;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation1 = Tween<double>(
      begin: 0,
      end: 200,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _animation2 = Tween<double>(
      begin: 0,
      end: 150,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal, Colors.teal, Colors.blue, Colors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 6),
            Image.asset('assets/images/bu_logo.png', width: 150, height: 150),
            const SizedBox(height: 20),
            const Text(
              'Bahria University Islamabad Campus',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _animation1,
              builder: (context, child) {
                return Center(
                  child: Container(
                    width: _animation1.value,
                    height: 3,
                    color: Colors.red,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _animation2,
              builder: (context, child) {
                return Center(
                  child: Container(
                    width: _animation2.value,
                    height: 3,
                    color: Colors.red,
                  ),
                );
              },
            ),
            const Spacer(),
            Image.asset('assets/images/bue.png'),
          ],
        ),
      ),
    );
  }
}
