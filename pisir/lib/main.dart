import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_page.dart';
import 'screens/main_screen.dart';
import 'screens/recipe_detail_page.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
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
    return MaterialApp(
      title: 'Pişir',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/main': (context) => const MainScreen(),
        '/recipeDetail': (context) {
          final recipe = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return RecipeDetailPage(recipe: recipe);
        },
      },
    );
  }
}
