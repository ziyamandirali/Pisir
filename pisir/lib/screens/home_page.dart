import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // Sayfalandırma için değişkenler
  DocumentSnapshot? _lastDocument;
  bool _hasMoreRecipes = true;
  final int _recipesPerPage = 2000; // Tarif sayfa boyutu
  final int _maxTotalRecipes = 50; // Maksimum toplam tarif sayısı
  final int _displayPerPage = 10; // Sayfa başına gösterilecek tarif sayısı
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _testFirestore();
    _loadDeviceId();
    // Kaydırma olayını dinle
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Kaydırma olayı dinleyicisi
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading && 
        !_loadingMore && 
        _hasMoreRecipes) {
      _loadMoreRecipes();
    }
  }

  Future<void> _testFirestore() async {
    try {
      // Basit bir get işlemi ile kontrol
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
      
      // Mevcut recipes koleksiyonunu kontrol et
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
      await _loadMatchingRecipes();
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

  Future<void> _loadMatchingRecipes() async {
    if (_deviceId == null) return;

    setState(() {
      _isLoading = true;
      _lastDocument = null;
      _hasMoreRecipes = true;
      _matchingRecipes = [];
    });
    
    await Future.delayed(const Duration(milliseconds: 100));
    await _loadMoreRecipes();
  }

  Future<void> _loadMoreRecipes() async {
    if (_deviceId == null || _loadingMore || !_hasMoreRecipes) return;

    // Maksimum tarif sayısına ulaşıldı mı kontrol et
    if (_matchingRecipes.length >= _maxTotalRecipes) {
      setState(() {
        _hasMoreRecipes = false;
        _loadingMore = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final List<String> allPantryIngredients = _pantryIngredients.values
          .expand((ingredients) => ingredients)
          .map((ingredient) => ingredient.toLowerCase().trim())
          .toList();

      Query recipesQuery = FirebaseFirestore.instance
          .collection('recipes')
          .limit(_recipesPerPage);

      if (_lastDocument != null) {
        recipesQuery = recipesQuery.startAfterDocument(_lastDocument!);
      }

      final recipesSnapshot = await recipesQuery.get(GetOptions(source: Source.serverAndCache));

      if (recipesSnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreRecipes = false;
          _loadingMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = recipesSnapshot.docs.last;
      final List<Map<String, dynamic>> newMatchingRecipes = [];
      
      for (var recipeDoc in recipesSnapshot.docs) {
        final recipeData = recipeDoc.data() as Map<String, dynamic>;
        final String recipeId = recipeDoc.id;
        final String recipeTitle = recipeData['title'] ?? 'İsimsiz Tarif';
        final ingredientsOnly = recipeData['ingredientsOnly'] as String?;
        
        if (ingredientsOnly == null) continue;
        
        final List<String> recipeIngredients = ingredientsOnly
            .split(',')
            .map((ingredient) => ingredient.trim().toLowerCase())
            .where((ingredient) => ingredient.isNotEmpty)
            .toList();
        
        bool allIngredientsInPantry = true;
        List<String> matchedIngredients = [];
        List<String> missingIngredients = [];
        
        for (int i = 0; i < recipeIngredients.length; i++) {
          final String recipeIngredient = recipeIngredients[i];
          bool foundInPantry = false;
          String? matchedPantryIngredient;
          
          for (int j = 0; j < allPantryIngredients.length; j++) {
            final String pantryIngredient = allPantryIngredients[j];
            
            if (recipeIngredient == pantryIngredient) {
              foundInPantry = true;
              matchedPantryIngredient = pantryIngredient;
              break;
            }
          }
          
          if (foundInPantry) {
            matchedIngredients.add('"$recipeIngredient" (✓)');
          } else {
            allIngredientsInPantry = false;
            missingIngredients.add('"$recipeIngredient" (✗)');
          }
        }
        
        if (allIngredientsInPantry) {
          debugPrint('PIŞIR_DEBUG: [13] ✅ BAŞARILI EŞLEŞME: $recipeTitle | Tüm malzemeler mevcut: ${matchedIngredients.join(", ")}');
          newMatchingRecipes.add({
            'id': recipeId,
            'title': recipeTitle,
            'ingredientsOnly': ingredientsOnly,
            'imageUrl': recipeData['imageUrl'],
            'cookTime': recipeData['cookTime'],
            'prepTime': recipeData['prepTime'],
          });
        }
      }

      if (recipesSnapshot.docs.length < _recipesPerPage) {
        _hasMoreRecipes = false;
      }

      if (newMatchingRecipes.isNotEmpty) {
        setState(() {
          _matchingRecipes.addAll(newMatchingRecipes);
          if (_displayedRecipes.isEmpty) {
            _displayedRecipes = _matchingRecipes.take(_displayPerPage).toList();
          }
          _loadingMore = false;
          _isLoading = false;
        });
      } else {
        if (_hasMoreRecipes) {
          setState(() {
            _loadingMore = false;
            _isLoading = false;
          });
          await _loadMoreRecipes();
        } else {
          setState(() {
            _loadingMore = false;
            _isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      setState(() {
        _loadingMore = false;
        _isLoading = false;
      });
    }
    
    Future.delayed(const Duration(seconds: 10), () {
      if (_isLoading || _loadingMore) {
        setState(() {
          _loadingMore = false;
          _isLoading = false;
        });
      }
    });
  }

  // Yeni metod: Daha fazla tarif yükle
  void _loadMoreDisplayedRecipes() {
    if (_matchingRecipes.length > _displayedRecipes.length) {
      setState(() {
        final nextBatch = _matchingRecipes.skip(_displayedRecipes.length).take(_displayPerPage).toList();
        _displayedRecipes.addAll(nextBatch);
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
          'assets/pısırlogo.png',
          width: 115,
          height: 115,
        ),
      ),
      body: _isLoading && _matchingRecipes.isEmpty
          ? const Center(child: CircularProgressIndicator())
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
                    // Son öğe ve daha fazla tarif varsa "Daha Fazla" butonu göster
                    if (index == _displayedRecipes.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: ElevatedButton(
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
                                    if (recipe['cookTime'] != null) ...[
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
                                            'Hazırlanma süresi: ${(recipe['prepTime'] ?? 0) + (recipe['cookTime'] ?? 0)} dakika',
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
