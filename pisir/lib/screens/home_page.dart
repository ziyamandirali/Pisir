import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Map<String, List<String>> _pantryIngredients = {};
  // Sayfalandırma için değişkenler
  DocumentSnapshot? _lastDocument;
  bool _hasMoreRecipes = true;
  final int _recipesPerPage = 10;
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
      debugPrint('PIŞIR_DEBUG: Firestore bağlantı testi yapılıyor...');
      
      // Basit bir get işlemi ile kontrol
      final testDoc = await FirebaseFirestore.instance
          .collection('test')
          .doc('test')
          .get(GetOptions(source: Source.serverAndCache));
      
      if (testDoc.exists) {
        debugPrint('PIŞIR_DEBUG: Firestore test başarılı - ${testDoc.data()}');
      } else {
        debugPrint('PIŞIR_DEBUG: Firestore test belge mevcut değil, oluşturuluyor...');
        
        // Test belgesini oluştur
        try {
          await FirebaseFirestore.instance
              .collection('test')
              .doc('test')
              .set({'timestamp': FieldValue.serverTimestamp()});
          debugPrint('PIŞIR_DEBUG: Firestore test belgesi oluşturuldu');
        } catch (e) {
          debugPrint('PIŞIR_DEBUG: Firestore test belgesi oluşturulamadı: $e');
        }
      }
      
      // Mevcut recipes koleksiyonunu kontrol et
      debugPrint('PIŞIR_DEBUG: Recipes koleksiyonu kontrol ediliyor...');
      final recipesSnapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .limit(5)
          .get();
      
      debugPrint('PIŞIR_DEBUG: ${recipesSnapshot.docs.length} adet tarif bulundu');
      for (var doc in recipesSnapshot.docs) {
        debugPrint('PIŞIR_DEBUG: Tarif ID: ${doc.id}, Başlık: ${doc.data()['title'] ?? 'Başlık yok'}');
      }
      
    } catch (e) {
      debugPrint('PIŞIR_DEBUG: Firestore testi başarısız: $e');
    }
  }

  Future<void> _loadDeviceId() async {
    debugPrint('PIŞIR_DEBUG: [A] Device ID yükleniyor...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id');
    });
    debugPrint('PIŞIR_DEBUG: [B] Device ID: $_deviceId');
    if (_deviceId != null) {
      debugPrint('PIŞIR_DEBUG: [C] Mutfak dolabını yüklemeye başlıyorum...');
      await _loadPantryIngredients();
      debugPrint('PIŞIR_DEBUG: [D] Mutfak dolabı yüklendi. Şimdi tarifleri yüklemeye başlıyorum...');
      await _loadMatchingRecipes();
      debugPrint('PIŞIR_DEBUG: [E] Tarifler yüklendi.');
    } else {
      debugPrint('PIŞIR_DEBUG: HATA! Device ID bulunamadı');
    }
  }

  Future<void> _loadPantryIngredients() async {
    if (_deviceId == null) return;

    debugPrint('PIŞIR_DEBUG: Mutfak dolabı malzemeleri yükleniyor...');
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_deviceId)
          .get(GetOptions(source: Source.serverAndCache));

      debugPrint('PIŞIR_DEBUG: Kullanıcı belgesi var mı? ${userDoc.exists}');
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
          debugPrint('PIŞIR_DEBUG: Mutfak dolabı yüklendi: ${_pantryIngredients.length} kategori');
          // Kategorileri ve içlerindeki malzemeleri yazdır
          _pantryIngredients.forEach((category, ingredients) {
            debugPrint('PIŞIR_DEBUG: Kategori: $category - Malzemeler: ${ingredients.join(", ")}');
          });
        }
      } else {
        debugPrint('PIŞIR_DEBUG: Kullanıcının mutfak dolabı boş veya uygun formatta değil');
      }
    } catch (e) {
      debugPrint('PIŞIR_DEBUG: Mutfak dolabı yüklenirken hata: $e');
    }
  }

  Future<void> _loadMatchingRecipes() async {
    debugPrint('PIŞIR_DEBUG: [Z] _loadMatchingRecipes başladı ------------------');
    
    if (_deviceId == null) {
      debugPrint('PIŞIR_DEBUG: [Z1] Device ID null, tarifleri yükleyemiyorum!');
      return;
    }

    setState(() {
      _isLoading = true;
      _lastDocument = null;
      _hasMoreRecipes = true;
      _matchingRecipes = [];
    });
    debugPrint('PIŞIR_DEBUG: [Z2] State ayarlandı, şimdi ilk tarif sayfası yüklenecek');
    
    // Burada bir gecikme ekleyelim, böylece state doğru şekilde güncellenebilir
    await Future.delayed(const Duration(milliseconds: 100));
    
    await _loadMoreRecipes();
    debugPrint('PIŞIR_DEBUG: [Y] _loadMatchingRecipes tamamlandı ---------------');
  }

  Future<void> _loadMoreRecipes() async {
    debugPrint('PIŞIR_DEBUG: [M] ************* _loadMoreRecipes BAŞLADI ************');
    
    if (_deviceId == null) {
      debugPrint('PIŞIR_DEBUG: [M-ERR] DeviceID null!');
      return;
    }
    
    if (_loadingMore) {
      debugPrint('PIŞIR_DEBUG: [M-ERR] Zaten yükleme yapılıyor!');
      return;
    }
    
    if (!_hasMoreRecipes) {
      debugPrint('PIŞIR_DEBUG: [M-ERR] Daha fazla tarif yok!');
      return;
    }
    
    // _isLoading kontrolü artık atlanabilir
    // Bu metod direkt çalışmalı
    debugPrint('PIŞIR_DEBUG: [M-OK] Tarifler yüklenmeye başlıyor...');

    setState(() {
      _loadingMore = true;
    });

    try {
      debugPrint('PIŞIR_DEBUG: [1] Tarifleri yüklemeye başlıyoruz...');
      final List<String> allPantryIngredients = _pantryIngredients.values
          .expand((ingredients) => ingredients)
          .map((ingredient) => ingredient.toLowerCase().trim())
          .toList();
      
      debugPrint('PIŞIR_DEBUG: [2] Mutfak dolabında ${allPantryIngredients.length} malzeme var: ${allPantryIngredients.join(', ')}');

      // İlk sorgu veya sonraki sayfa sorgusu
      Query recipesQuery = FirebaseFirestore.instance
          .collection('recipes')
          .limit(_recipesPerPage);

      // Eğer bir önceki sayfa yüklendiyse, son belge referansını kullan
      if (_lastDocument != null) {
        recipesQuery = recipesQuery.startAfterDocument(_lastDocument!);
      }

      debugPrint('PIŞIR_DEBUG: [3] Firestore sorgusu yapılıyor...');
      final recipesSnapshot = await recipesQuery.get(GetOptions(source: Source.serverAndCache));
      debugPrint('PIŞIR_DEBUG: [4] *** Sorgu yapıldı: ${recipesSnapshot.docs.length} tarif bulundu ***');

      // Son belge kontrolü
      if (recipesSnapshot.docs.isEmpty) {
        debugPrint('PIŞIR_DEBUG: [5] Sorgu sonucu boş geldi');
        setState(() {
          _hasMoreRecipes = false;
          _loadingMore = false;
          _isLoading = false;
        });
        return;
      }

      // Son belgeyi kaydet
      _lastDocument = recipesSnapshot.docs.last;

      // Eşleşen tarifleri topla
      final List<Map<String, dynamic>> newMatchingRecipes = [];
      
      // Hangi tariflerin mutfak dolabındaki malzemelerle eşleştiğini kontrol et
      debugPrint('PIŞIR_DEBUG: [6] ========= MALZEME KARŞILAŞTIRMA BAŞLIYOR =========');
      
      for (var recipeDoc in recipesSnapshot.docs) {
        final recipeData = recipeDoc.data() as Map<String, dynamic>;
        final String recipeId = recipeDoc.id;
        final String recipeTitle = recipeData['title'] ?? 'İsimsiz Tarif';
        final ingredientsOnly = recipeData['ingredientsOnly'] as String?;
        
        debugPrint('PIŞIR_DEBUG: [7] TARİF: $recipeTitle (ID: $recipeId)');
        
        if (ingredientsOnly == null) {
          debugPrint('PIŞIR_DEBUG: [8] UYARI! Bu tarifte ingredientsOnly alanı yok!');
          continue; // Bu tarifi atla
        }
        
        // Malzemeleri virgülle ayır
        final List<String> recipeIngredients = ingredientsOnly
            .split(',')
            .map((ingredient) => ingredient.trim().toLowerCase())
            .where((ingredient) => ingredient.isNotEmpty)
            .toList();
        
        debugPrint('PIŞIR_DEBUG: [9] TARİF MALZEMELERİ (${recipeIngredients.length}): ${recipeIngredients.join(", ")}');
        
        // YENİ ALGORİTMA: Tarifte SADECE pantry'deki malzemeler olmalı
        bool allIngredientsInPantry = true; // Tüm malzemeler pantry'de mi?
        List<String> matchedIngredients = [];
        List<String> missingIngredients = [];
        
        // Her tarif malzemesini kontrol et
        for (int i = 0; i < recipeIngredients.length; i++) {
          final String recipeIngredient = recipeIngredients[i];
          debugPrint('PIŞIR_DEBUG: [10] MAL-${i+1}: "$recipeIngredient"');
          
          // Bu malzeme pantry'de var mı?
          bool foundInPantry = false;
          String? matchedPantryIngredient;
          
          for (int j = 0; j < allPantryIngredients.length; j++) {
            final String pantryIngredient = allPantryIngredients[j];
            
            // Tam eşleşme kontrolü
            if (recipeIngredient == pantryIngredient) {
              foundInPantry = true;
              matchedPantryIngredient = pantryIngredient;
              debugPrint('PIŞIR_DEBUG: [11] EŞLEŞME BULUNDU! "$recipeIngredient" = "$pantryIngredient"');
              break;
            }
          }
          
          if (foundInPantry) {
            matchedIngredients.add('"$recipeIngredient" (✓)');
          } else {
            allIngredientsInPantry = false; // Bu malzeme pantry'de yok!
            missingIngredients.add('"$recipeIngredient" (✗)');
            debugPrint('PIŞIR_DEBUG: [12] EKSİK MALZEME: "$recipeIngredient" pantry\'de bulunamadı');
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
        } else {
          debugPrint('PIŞIR_DEBUG: [14] ❌ EŞLEŞME YOK: $recipeTitle | Eksik malzemeler: ${missingIngredients.join(", ")}');
        }
        
        debugPrint('PIŞIR_DEBUG: [15] ----------------------------------------');
      }
      
      debugPrint('PIŞIR_DEBUG: [16] *** Bu sayfada ${newMatchingRecipes.length} tarif eşleşti ***');

      // Daha fazla tarif olup olmadığını kontrol et
      if (recipesSnapshot.docs.length < _recipesPerPage) {
        _hasMoreRecipes = false;
        debugPrint('PIŞIR_DEBUG: [17] *** Daha fazla tarif yok ***');
      }

      // UI'ı bir kerede güncelle
      if (newMatchingRecipes.isNotEmpty) {
        setState(() {
          _matchingRecipes.addAll(newMatchingRecipes);
          debugPrint('PIŞIR_DEBUG: [18] *** Toplam ${_matchingRecipes.length} tarif gösteriliyor ***');
          _loadingMore = false;
          _isLoading = false;
        });
      } else {
        // Eşleşen tarif yoksa ve daha fazla tarif varsa, bir sonraki sayfayı yükle
        if (_hasMoreRecipes) {
          debugPrint('PIŞIR_DEBUG: [19] Hiç eşleşme bulunamadı, bir sonraki sayfaya geçiliyor');
          setState(() {
            _loadingMore = false;
            _isLoading = false;
          });
          // Hemen bir sonraki sayfayı yükle
          await _loadMoreRecipes();
        } else {
          setState(() {
            _loadingMore = false;
            _isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('PIŞIR_DEBUG: [20] HATA! Tarifleri yüklerken hata: $e');
      debugPrint('PIŞIR_DEBUG: [21] HATA DETAYI: $stackTrace');
      setState(() {
        _loadingMore = false;
        _isLoading = false;
      });
    }
    
    // Eğer 10 saniye içinde işlem tamamlanmazsa zorunlu olarak yükleme durumunu kaldır
    Future.delayed(const Duration(seconds: 10), () {
      if (_isLoading || _loadingMore) {
        debugPrint('PIŞIR_DEBUG: [TIMEOUT] Yükleme zaman aşımına uğradı, UI güncelleniyor.');
        setState(() {
          _loadingMore = false;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
                  itemCount: _matchingRecipes.length + (_hasMoreRecipes ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Son öğe ve daha fazla tarif varsa yükleme göstergesi göster
                    if (index == _matchingRecipes.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    
                    final recipe = _matchingRecipes[index];
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
