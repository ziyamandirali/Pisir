import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  bool _isDarkMode = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _isDarkMode = darkModeNotifier.value;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists && mounted) {
          setState(() {
            _userProfile = userDoc.data();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _signOut() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase Auth'dan çıkış yap
      await FirebaseAuth.instance.signOut();
      
      // Google Sign-In'den de çıkış yap (eğer Google ile giriş yapılmışsa)
      await GoogleSignIn().signOut();
      
      if (!mounted) return;
      
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      debugPrint('Sign out error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çıkış yapılırken bir hata oluştu'),
            duration: Duration(seconds: 2),
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

  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    darkModeNotifier.value = value;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', value);
    } catch (e) {
      // If saving fails, revert the change
      setState(() {
        _isDarkMode = !value;
      });
      darkModeNotifier.value = !value;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tema değiştirilemedi. Lütfen tekrar deneyin.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getDisplayName() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    
    // Önce Firestore'dan gelen displayName'i kontrol et
    if (_userProfile?['displayName'] != null && _userProfile!['displayName'].toString().isNotEmpty) {
      return _userProfile!['displayName'];
    }
    
    // Sonra Firebase Auth'dan gelen displayName'i kontrol et
    if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
      return currentUser.displayName!;
    }
    
    // Eğer firstName ve lastName varsa bunları birleştir
    if (_userProfile?['firstName'] != null && _userProfile?['lastName'] != null) {
      return '${_userProfile!['firstName']} ${_userProfile!['lastName']}';
    }
    
    // Son olarak e-posta adresini kullan
    return currentUser?.email ?? 'Kullanıcı';
  }

  String _getInitials() {
    final displayName = _getDisplayName();
    if (displayName == 'Kullanıcı' || displayName.contains('@')) {
      return 'K';
    }
    
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    
    return 'K';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Bilinmiyor';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Bilinmiyor';
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Bilinmiyor';
    }
  }

  Widget _buildProfileInfo(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = darkModeNotifier.value;
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          'Ayarlar',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          
          // Profil Bilgileri Bölümü
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil Bilgileri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Profil Fotoğrafı ve İsim
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurple,
                      backgroundImage: _userProfile?['photoURL'] != null 
                          ? NetworkImage(_userProfile!['photoURL'])
                          : null,
                      child: _userProfile?['photoURL'] == null
                          ? Text(
                              _getInitials(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDisplayName(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userProfile?['email'] ?? 'E-posta yok',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Ek Profil Bilgileri
                if (_userProfile?['firstName'] != null) ...[
                  _buildProfileInfo('Ad', _userProfile!['firstName'], isDark),
                  const SizedBox(height: 8),
                ],
                if (_userProfile?['lastName'] != null) ...[
                  _buildProfileInfo('Soyad', _userProfile!['lastName'], isDark),
                  const SizedBox(height: 8),
                ],
                if (_userProfile?['created_at'] != null) ...[
                  _buildProfileInfo(
                    'Üyelik Tarihi', 
                    _formatDate(_userProfile!['created_at']), 
                    isDark
                  ),
                  const SizedBox(height: 8),
                ],
                if (_userProfile?['last_login'] != null) ...[
                  _buildProfileInfo(
                    'Son Giriş', 
                    _formatDate(_userProfile!['last_login']), 
                    isDark
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          SwitchListTile(
            title: Text(
              'Koyu Tema',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              'Uygulamayı koyu temada kullan',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            value: _isDarkMode,
            onChanged: _toggleTheme,
            activeColor: Colors.deepPurple,
          ),
          const Divider(),
          
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
              label: const Text('Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
