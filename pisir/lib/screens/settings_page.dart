import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;

  Future<void> _signOut() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Önce Google oturumunu kapat
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      // Sonra Firebase oturumunu kapat
      await _auth.signOut();
      
      if (!mounted) return;
      
      // Tüm sayfaları temizle ve login sayfasına yönlendir
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Ayarlar'),
            ),
            body: const Center(
              child: Text('Kullanıcı bilgileri yüklenemedi'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ayarlar'),
          ),
          body: ListView(
            children: [
              const SizedBox(height: 20),
              // Profil Başlığı
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Hesap Bilgileri',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Profil Bilgileri
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.photoURL != null)
                        Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(user.photoURL!),
                          ),
                        ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Ad Soyad'),
                        subtitle: Text(user.displayName ?? 'Belirtilmemiş'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('E-posta'),
                        subtitle: Text(user.email ?? 'Belirtilmemiş'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Çıkış Yap Butonu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signOut,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Hesaptan Çıkış Yap'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
