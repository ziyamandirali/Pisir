import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // Kullanıcının daha önce giriş yapıp yapmadığını kontrol et
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final deviceId = prefs.getString('device_id');
      
      debugPrint('PIŞIR_DEBUG: Checking login status - isLoggedIn: $isLoggedIn, deviceId: $deviceId');
      
      if (isLoggedIn && deviceId != null && deviceId.isNotEmpty) {
        // Kullanıcı daha önce giriş yapmış, direkt ana sayfaya yönlendir
        debugPrint('PIŞIR_DEBUG: User already logged in, redirecting to main screen');
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        // Kullanıcı daha önce giriş yapmamış, login sayfasına yönlendir
        debugPrint('PIŞIR_DEBUG: User not logged in, redirecting to login screen');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('PIŞIR_DEBUG: Error checking login status: $e');
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
