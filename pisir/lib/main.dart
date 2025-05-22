import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_page.dart';
import 'screens/main_screen.dart';
import 'screens/recipe_detail_page.dart';
import 'screens/splash_screen.dart';
import 'animations/page_transitions.dart';

final ValueNotifier<bool> darkModeNotifier = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  darkModeNotifier.value = prefs.getBool('is_dark_mode') ?? false;
  
  // Firestore önbelleğini yapılandır
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // Firestore'u offline ilk modunda çalıştır
  try {
    await FirebaseFirestore.instance.disableNetwork();
    debugPrint('PIŞIR_DEBUG: Firestore network disabled, using offline mode first');
    
    // 3 saniye sonra network'ü tekrar aktifleştir
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await FirebaseFirestore.instance.enableNetwork();
        debugPrint('PIŞIR_DEBUG: Firestore network enabled after delay');
      } catch (e) {
        debugPrint('PIŞIR_DEBUG: Error enabling Firestore network: $e');
      }
    });
  } catch (e) {
    debugPrint('PIŞIR_DEBUG: Error configuring Firestore offline mode: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Pişir',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
            appBarTheme: AppBarTheme(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(
                color: isDark ? Colors.white : Colors.black,
              ),
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            cardColor: isDark ? Colors.grey[800] : Colors.white,
            textTheme: TextTheme(
              bodyLarge: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              bodyMedium: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              selectedItemColor: isDark ? Colors.deepPurple[200] : Colors.deepPurple,
              unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            switchTheme: SwitchThemeData(
              thumbColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.deepPurple;
                }
                return isDark ? Colors.grey[400]! : Colors.grey[600]!;
              }),
              trackColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return isDark ? Colors.deepPurple.withOpacity(0.5) : Colors.deepPurple.withOpacity(0.3);
                }
                return isDark ? Colors.grey[700]! : Colors.grey[300]!;
              }),
            ),
          ),
          home: const SplashScreen(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return PageTransitions.slideTransition(const LoginPage());
              case '/main':
                return PageTransitions.slideTransition(const MainScreen());
              case '/recipeDetail':
                final recipe = settings.arguments as Map<String, dynamic>;
                return PageTransitions.slideTransition(RecipeDetailPage(recipe: recipe));
              default:
                return PageTransitions.slideTransition(const SplashScreen());
            }
          },
        );
      },
    );
  }
}
