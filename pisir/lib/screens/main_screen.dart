import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'pantry_page.dart';
import 'settings_page.dart';
import 'recipe_search_page.dart';
import 'favorites_page.dart';
import '../animations/page_transitions.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _previousIndex = 0;
  final List<int> _navigationHistory = [0]; // Navigasyon geçmişi

  final List<Widget> _pages = [
    const HomePage(),
    const RecipeSearchPage(),
    const FavoritesPage(),
    const PantryPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      // Her ziyaret edilen sayfayı geçmişe ekle
      _navigationHistory.add(_selectedIndex);
      
      // Geçmişi 5 sayfa ile sınırla (performans için)
      if (_navigationHistory.length > 5) {
        _navigationHistory.removeAt(0);
      }

      setState(() {
        _previousIndex = _selectedIndex;
        _selectedIndex = index;
      });
    }
  }

  int? _getPreviousPage() {
    // Geçmişten en son ziyaret edilen farklı sayfayı bul
    for (int i = _navigationHistory.length - 1; i >= 0; i--) {
      if (_navigationHistory[i] != _selectedIndex) {
        // Bu sayfayı geçmişten çıkar (geri gittiğimiz için)
        int previousPage = _navigationHistory.removeAt(i);
        return previousPage;
      }
    }
    // Geri gidilecek sayfa yok
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }

        // Geri gidilecek sayfa var mı kontrol et
        int? previousPage = _getPreviousPage();
        
        if (previousPage != null) {
          // Önceki sayfaya git
          setState(() {
            _selectedIndex = previousPage;
          });
          return;
        }

        // Geri gidilecek sayfa yok, çıkış onayı sor
        final bool? shouldPop = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Uygulamadan Çıkış'),
            content: const Text('Uygulamadan çıkmak istediğinize emin misiniz?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Hayır'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Evet'),
              ),
            ],
          ),
        );

        if (shouldPop ?? false) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              )),
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: _pages[_selectedIndex],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Tarif Ara',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favoriler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.kitchen),
              label: 'Mutfak Dolabı',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Ayarlar',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
} 