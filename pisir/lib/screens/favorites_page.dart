import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pisir/screens/recipe_detail_page.dart'; // Assuming this is your detail page

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Stream<List<Map<String, dynamic>>> _favoritesStream;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _initializeFavorites();
  }

  Future<void> _initializeFavorites() async {
    await _loadDeviceId();
    if (_deviceId != null) {
      setState(() {
        _favoritesStream = _loadFavoritesStream();
      });
    } else {
      // Device ID yoksa boş stream veya hata durumu
      setState(() {
        _favoritesStream = Stream.value([]); 
      });
      debugPrint('Device ID not found. Cannot load favorites.');
    }
  }

  Future<void> _loadDeviceId() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    _deviceId = currentUser?.uid;
  }

  Stream<List<Map<String, dynamic>>> _loadFavoritesStream() {
    if (_deviceId == null) {
      debugPrint('Device ID is null in _loadFavoritesStream. Cannot load favorites.');
      return Stream.value([]);
    }

    // Dinlenecek olan kullanıcı dokümanının referansı
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_deviceId!) // deviceId kullanıldı
        .snapshots() // Artık kullanıcı dokümanının tamamını dinliyoruz
        .asyncMap((userDocSnapshot) async {
      if (!userDocSnapshot.exists || userDocSnapshot.data() == null) {
        return []; // Kullanıcı dokümanı yoksa veya veri yoksa boş liste
      }

      final userData = userDocSnapshot.data()!;
      final favoriteRecipeIds = List<String>.from(userData['favorites'] ?? []);

      if (favoriteRecipeIds.isEmpty) {
        return [];
      }

      // Fetch details for each recipe ID
      List<Map<String, dynamic>> favoriteRecipes = [];
      for (String recipeId in favoriteRecipeIds) {
        try {
          final recipeDoc = await FirebaseFirestore.instance
              .collection('recipes')
              .doc(recipeId)
              .get();
          if (recipeDoc.exists) {
            favoriteRecipes.add({
              'id': recipeDoc.id,
              ...recipeDoc.data()!,
            });
          }
        } catch (e) {
          debugPrint('Error fetching recipe details for $recipeId: $e');
        }
      }
      return favoriteRecipes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favori Tariflerim'),
      ),
      body: _deviceId == null
          ? const Center(
              child: Text(
                'Favorilerinizi görmek için lütfen uygulamaya tekrar giriş yapın veya device ID bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _favoritesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('Error in favorites stream: ${snapshot.error}');
                  return const Center(
                      child: Text('Favoriler yüklenirken bir hata oluştu.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text(
                    'Henüz favori tarifiniz bulunmuyor.\nKalp ikonuna dokunarak tarifleri favorilerinize ekleyebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ));
                }

                final favorites = snapshot.data!;

                return ListView.builder(
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final recipe = favorites[index];
                    final imageUrl = recipe['imageUrl'] as String?;
                    final title = recipe['title'] as String? ?? 'İsimsiz Tarif';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailPage(recipe: recipe),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrl != null)
                              Hero(
                                tag: 'recipeImage_${recipe['id']}', // Ensure unique tag if also used elsewhere
                                child: Image.network(
                                  imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 180,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 180,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Optionally, add more details like prep time, cook time, etc.
                            // For example:
                            // if (recipe['prepTime'] != null)
                            //   Padding(
                            //     padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            //     child: Text('Hazırlık: ${recipe['prepTime']} dk'),
                            //   ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
} 