import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = false;
  bool _loadingMore = false;
  String? _deviceId;
  List<Map<String, dynamic>> _matchingRecipes = [];
  List<Map<String, dynamic>> _displayedRecipes = [];
  Map<String, List<String>> _pantryIngredients = {};
  List<Map<String, dynamic>> _localRecipes = []; // Yerel tarif verileri
  int _currentRecipeIndex = 0; // İşlenecek tarif indeksi
  
  final int _maxTotalRecipes = 50; // Maksimum eşleşecek tarif sayısı
  final int _initialDisplayCount = 20; // Başlangıçta gösterilecek tarif sayısı
  final int _loadMoreCount = 10; // Daha fazla butonu ile yüklenecek tarif sayısı
  final int _batchSize = 50; // Bir seferde işlenecek tarif sayısı
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _testFirestore();
    _loadDeviceId();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Mevcut Firestore test fonksiyonu
  Future<void> _testFirestore() async {
    try {
      final testDoc = await FirebaseFirestore.instance
          .collection('test')
          .doc('test')
          .get(GetOptions(source: Source.serverAndCache));
      
      if (testDoc.exists) {
        // Test belgesi mevcut
      } else {
        // Test belgesini oluştur
        try {
          await FirebaseFirestore.instance
              .collection('test')
              .doc('test')
              .set({'timestamp': FieldValue.serverTimestamp()});
        } catch (e) {
          // Test belgesi oluşturulamadı
        }
      }
      
      final recipesSnapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .limit(5)
          .get();
      
    } catch (e) {
      // Firestore testi başarısız
    }
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id');
    });
    if (_deviceId != null) {
      await _loadPantryIngredients();
      await _loadLocalRecipes(); // Yerel tarifleri yükle
      await _matchLocalRecipes(); // Yerel tarifleri karşılaştır
    }
  }

  Future<void> _loadPantryIngredients() async {
    if (_deviceId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_deviceId)
          .get(GetOptions(source: Source.serverAndCache));

      if (userDoc.exists && userDoc.data()!.containsKey('pantry')) {
        final pantryData = userDoc.data()?['pantry'];
        if (pantryData is Map) {
          setState(() {
            _pantryIngredients = Map<String, List<String>>.from(
              (pantryData as Map).map((key, value) => MapEntry(
                key.toString(),
                List<String>.from(value as List),
              )),
            );
          });
        }
      }
    } catch (e) {
      // Mutfak dolabı yüklenirken hata
    }
  }
  
  // YENİ FONKSIYON: Yerel tarif dosyasını oku
  Future<void> _loadLocalRecipes() async {
    setState(() {
      _isLoading = true;
      _matchingRecipes = [];
    });
    
    try {
      // recipes.txt dosyasını oku
      final String data = await rootBundle.loadString('assets/recipes.txt');
      final List<String> lines = data.split('\n');
      
      _localRecipes = [];
      
      // Her satırı ayrıştır
      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          // Format: document_id:{ingredientsOnly}{imageUrl}{prepTime+cookTime}{title}
          final int idEndIndex = line.indexOf(':');
          if (idEndIndex == -1) continue;
          
          final String docId = line.substring(0, idEndIndex);
          String content = line.substring(idEndIndex + 1);
          
          // İçeriği süslü parantezlerle ayır
          List<String> parts = [];
          int startIndex = 0;
          for (int i = 0; i < 4; i++) {
            final int openBrace = content.indexOf('{', startIndex);
            if (openBrace == -1) break;
            
            final int closeBrace = content.indexOf('}', openBrace + 1);
            if (closeBrace == -1) break;
            
            parts.add(content.substring(openBrace + 1, closeBrace));
            startIndex = closeBrace + 1;
          }
          
          if (parts.length == 4) {
            _localRecipes.add({
              'id': docId,
              'ingredientsOnly': parts[0],
              'imageUrl': parts[1],
              'totalTime': int.tryParse(parts[2]) ?? 0,
              'title': parts[3],
            });
          }
        } catch (e) {
          // Bu satırı ayrıştırırken hata oluştu, sonraki satıra geç
          continue;
        }
      }
      
    } catch (e) {
      // Dosya okuma hatası
    }
  }
  
  // YENİ FONKSIYON: Yerel tarifleri pantry ile karşılaştır
  Future<void> _matchLocalRecipes() async {
    if (_pantryIngredients.isEmpty || _localRecipes.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Pantry malzemelerini düz liste haline getir
    final List<String> allPantryIngredients = _pantryIngredients.values
        .expand((ingredients) => ingredients)
        .map((ingredient) => ingredient.toLowerCase().trim())
        .toList();
    
    // Tarifleri belirli aralıklarla işle (UI'ı bloklamayı önlemek için)
    await _processNextBatchOfRecipes(allPantryIngredients);
  }
  
  // YENİ FONKSIYON: Tarifleri gruplar halinde işle
  Future<void> _processNextBatchOfRecipes(List<String> allPantryIngredients) async {
    if (_currentRecipeIndex >= _localRecipes.length || 
        _matchingRecipes.length >= _maxTotalRecipes) {
      // İşlem tamamlandı veya maksimum tarif sayısına ulaşıldı
      _finishRecipeProcessing();
      return;
    }
    
    final int endIndex = _currentRecipeIndex + _batchSize;
    final int actualEndIndex = endIndex > _localRecipes.length ? 
        _localRecipes.length : endIndex;
    
    for (int i = _currentRecipeIndex; 
         i < actualEndIndex && _matchingRecipes.length < _maxTotalRecipes; 
         i++) {
      final recipe = _localRecipes[i];
      final String ingredientsOnly = recipe['ingredientsOnly'] as String;
      
      final List<String> recipeIngredients = ingredientsOnly
          .split(',')
          .map((ingredient) => ingredient.trim().toLowerCase())
          .where((ingredient) => ingredient.isNotEmpty)
          .toList();
      
      bool allIngredientsInPantry = true;
      List<String> matchedIngredients = [];
      
      for (String recipeIngredient in recipeIngredients) {
        bool foundInPantry = allPantryIngredients.contains(recipeIngredient);
        
        if (foundInPantry) {
          matchedIngredients.add('"$recipeIngredient" (✓)');
        } else {
          allIngredientsInPantry = false;
          break;
        }
      }
      
      if (allIngredientsInPantry) {
        debugPrint('PIŞIR_DEBUG: [13] ✅ BAŞARILI EŞLEŞME: ${recipe['title']} | Tüm malzemeler mevcut: ${matchedIngredients.join(", ")}');
        _matchingRecipes.add(recipe);
      }
    }
    
    _currentRecipeIndex = actualEndIndex;
    
    // Daha fazla işlenecek tarif varsa, UI'ı güncelleyip sonraki grubu işle
    if (_currentRecipeIndex < _localRecipes.length && 
        _matchingRecipes.length < _maxTotalRecipes) {
      // UI'ı güncelle ve sonraki grubu işle
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 10));
      await _processNextBatchOfRecipes(allPantryIngredients);
    } else {
      // İşlem tamamlandı
      _finishRecipeProcessing();
    }
  }
  
  // YENİ FONKSIYON: Tarif işlemesini tamamla
  void _finishRecipeProcessing() {
    setState(() {
      _isLoading = false;
      // Başlangıçta belirlenen sayıda tarifi göster
      if (_matchingRecipes.isNotEmpty) {
        // İlk _initialDisplayCount kadar tarifi göster veya daha az varsa hepsini
        _displayedRecipes = _matchingRecipes.take(_initialDisplayCount).toList();
      }
    });
  }

  // Daha fazla tarif gösterme fonksiyonu
  void _loadMoreDisplayedRecipes() {
    if (_matchingRecipes.length > _displayedRecipes.length) {
      setState(() {
        _loadingMore = true; // Daha fazla yükleme durumunu true yap
      });
      
      // Yükleme efekti için kısa bir gecikme
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() {
          final nextBatch = _matchingRecipes
              .skip(_displayedRecipes.length)
              .take(_loadMoreCount)
              .toList();
          _displayedRecipes.addAll(nextBatch);
          _loadingMore = false; // Yükleme tamamlandı
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = darkModeNotifier.value;
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 110,
        title: Image.asset(
          'assets/pisirlogo.png',
          width: 115,
          height: 115,
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) // Tariflerin ilk yüklenmesi
          : _matchingRecipes.isEmpty
              ? const Center(
                  child: Text(
                    'Mutfak dolabınızdaki malzemelerle yapabileceğiniz tarif bulunamadı',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _displayedRecipes.length + (_matchingRecipes.length > _displayedRecipes.length ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Son öğe ve daha fazla tarif varsa "Daha Fazla" butonu veya loading göster
                    if (index == _displayedRecipes.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: _loadingMore 
                            ? const CircularProgressIndicator() // Yükleme göstergesi
                            : ElevatedButton(
                                onPressed: _loadMoreDisplayedRecipes,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Daha Fazla Tarif Göster'),
                              ),
                        ),
                      );
                    }
                    
                    final recipe = _displayedRecipes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/recipeDetail',
                            arguments: recipe,
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Recipe Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: recipe['imageUrl'] != null
                                    ? Image.network(
                                        recipe['imageUrl'],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 100,
                                            height: 100,
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              size: 30,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.restaurant,
                                          size: 30,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              // Recipe Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe['title'] ?? 'İsimsiz Tarif',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      recipe['ingredientsOnly'] ?? 'Malzemeler belirtilmemiş',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (recipe['totalTime'] != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.timer_outlined,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Hazırlanma süresi: ${recipe['totalTime']} dakika',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
