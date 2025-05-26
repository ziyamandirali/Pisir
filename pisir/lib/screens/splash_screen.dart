import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // Splash screen'i en az 2 saniye göster
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    try {
      // Firebase Auth state'ini kontrol et
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      debugPrint('PIŞIR_DEBUG: Checking auth state - currentUser: ${currentUser?.uid}');
      
      if (currentUser != null) {
        // Kullanıcı giriş yapmış, direkt ana sayfaya yönlendir
        debugPrint('PIŞIR_DEBUG: User authenticated, redirecting to main screen');
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        // Kullanıcı giriş yapmamış, login sayfasına yönlendir
        debugPrint('PIŞIR_DEBUG: User not authenticated, redirecting to login screen');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('PIŞIR_DEBUG: Error checking auth state: $e');
      // Hata durumunda login sayfasına yönlendir
      Navigator.pushReplacementNamed(context, '/login');
    }
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
