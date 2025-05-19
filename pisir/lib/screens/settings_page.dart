import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _isDarkMode = darkModeNotifier.value;
  }

  Future<void> _signOut() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      
      if (!mounted) return;
      
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
        ],
      ),
    );
  }
}
