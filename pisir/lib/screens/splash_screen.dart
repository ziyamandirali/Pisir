import 'package:flutter/material.dart';
import '../main.dart'; // darkModeNotifier için import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = darkModeNotifier.value; // isDark değişkenini burada tanımla
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      body: Center(
        child: Image.asset(
          'assets/pisirlogo.png', // Transparan logo kullanılmaya devam edilecek
          width: 200,
          height: 200,
        ),
      ),
    );
  }
}
