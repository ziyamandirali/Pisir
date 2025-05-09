import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    if (_isInitialized) return;

    try {
      // Önce Firebase oturumunu kapat
      await _auth.signOut();
      
      // Sonra Google oturumunu kapat
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      print('Error initializing auth: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading || !_isInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Google ile giriş yap
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google ile giriş iptal edildi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Google kimlik bilgilerini al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Firebase kimlik bilgilerini oluştur
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase ile giriş yap
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Token'ı yenile
        await userCredential.user?.getIdToken(true);
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        throw Exception('Kullanıcı bilgileri alınamadı');
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      String errorMessage = 'Giriş yapılırken bir hata oluştu';
      
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'Bu e-posta adresi başka bir giriş yöntemiyle kullanılıyor';
          break;
        case 'invalid-credential':
          errorMessage = 'Geçersiz kimlik bilgileri';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google ile giriş etkin değil';
          break;
        case 'user-disabled':
          errorMessage = 'Bu hesap devre dışı bırakılmış';
          break;
        case 'user-not-found':
          errorMessage = 'Kullanıcı bulunamadı';
          break;
        case 'wrong-password':
          errorMessage = 'Hatalı şifre';
          break;
        case 'invalid-verification-code':
          errorMessage = 'Geçersiz doğrulama kodu';
          break;
        case 'invalid-verification-id':
          errorMessage = 'Geçersiz doğrulama kimliği';
          break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Google sign in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Giriş yapılırken bir hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pişir'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: Image.asset(
                  'assets/google_logo.png',
                  height: 24,
                ),
                label: const Text('Google ile Giriş Yap'),
              ),
          ],
        ),
      ),
    );
  }
}