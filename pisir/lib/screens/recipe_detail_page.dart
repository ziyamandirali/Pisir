import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecipeDetailPage extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailPage({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool _isLoading = true;
  String? _instructions;
  String? _ingredients;
  String? _title;
  String? _imageUrl;
  String? _prepTime;
  String? _cookTime;
  String? _description;
  bool _isFavorited = false;
  bool _isUpdatingFavorite = false;
  
  @override
  void initState() {
    super.initState();
    _loadRecipeDetails();
  }
  
  Future<String?> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  Future<void> _loadRecipeDetails() async {
    if (widget.recipe['id'] == null) {
      setState(() { 
        _isLoading = false; 
        _isUpdatingFavorite = false; 
      });
      return;
    }

    setState(() { 
      _isLoading = true; 
      _isUpdatingFavorite = true; 
    });

    bool determinedIsFavoritedFlag = false; 
    bool actualInitialIsFavoritedValue = false;

    try {
      final recipeId = widget.recipe['id'].toString();
      final deviceId = await _getDeviceId();

      if (deviceId != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(deviceId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          if (userData.containsKey('favorites')) {
            final favoritesList = List<String>.from(userData['favorites'] ?? []);
            actualInitialIsFavoritedValue = favoritesList.contains(recipeId);
          }
        }
        determinedIsFavoritedFlag = true; 
      } else {
        debugPrint('Device ID not found. Cannot load favorite status.');
        actualInitialIsFavoritedValue = false; // Default to false if no deviceId
        determinedIsFavoritedFlag = true; // Still, consider it "determined"
      }

      final recipeDoc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get(GetOptions(source: Source.serverAndCache));

      if (recipeDoc.exists) {
        final data = recipeDoc.data()!;
        setState(() {
          _title = data['title'] ?? '';
          _ingredients = data['ingredients'] ?? '';
          _instructions = data['instructions'] ?? '';
          _imageUrl = data['imageUrl'];
          _prepTime = data['prepTime'];
          _cookTime = data['cookTime'];
          _description = data['description'] ?? '';
          if (determinedIsFavoritedFlag) {
             _isFavorited = actualInitialIsFavoritedValue;
          }
          _isLoading = false;
          _isUpdatingFavorite = false;
        });
      } else {
        setState(() {
          if (determinedIsFavoritedFlag) {
            _isFavorited = actualInitialIsFavoritedValue;
          }
          _isLoading = false;
          _isUpdatingFavorite = false;
          debugPrint('Recipe document not found, but favorite status determined.');
        });
      }
    } catch (e) {
      debugPrint('Error loading recipe details or favorite status: $e');
      setState(() {
        if (determinedIsFavoritedFlag) {
          _isFavorited = actualInitialIsFavoritedValue;
        }
        _isLoading = false;
        _isUpdatingFavorite = false;
      });
    }
  }

  Future<void> _toggleFavoriteStatus() async {
    final deviceId = await _getDeviceId();

    if (deviceId == null) {
      debugPrint('Device ID not found. Cannot change favorite status.');
      // Optionally: show a message to the user
      return;
    }

    if (widget.recipe['id'] == null) return;
    final recipeId = widget.recipe['id'].toString();

    setState(() {
      _isUpdatingFavorite = true;
    });

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(deviceId);

    try {
      if (_isFavorited) {
        // Remove from favorites array
        await userDocRef.update({
          'favorites': FieldValue.arrayRemove([recipeId])
        });
      } else {
        // Add to favorites array
        await userDocRef.update({
          'favorites': FieldValue.arrayUnion([recipeId])
        });
      }
      setState(() {
        _isFavorited = !_isFavorited;
      });
    } catch (e) {
      debugPrint('Error updating favorite status (array): $e');
      // Optionally: show an error message to the user
      // Consider if the user document or 'favorites' field might not exist.
      // If it might not exist and update would fail, you might need to use .set with merge:true
      // or check existence first. For now, assuming 'favorites' field exists or can be created by update.
      // If 'users' doc or 'favorites' field might not exist, a more robust approach:
      /*
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDocRef);
        if (!snapshot.exists) {
          // If user doc doesn't exist, create it with the favorite
           transaction.set(userDocRef, {'favorites': [recipeId], 'device_id': deviceId});
        } else {
          final currentFavorites = List<String>.from(snapshot.data()?['favorites'] ?? []);
          if (_isFavorited) { // Current state is favorited, so we want to remove
            if (currentFavorites.contains(recipeId)) {
              transaction.update(userDocRef, {'favorites': FieldValue.arrayRemove([recipeId])});
            }
          } else { // Current state is not favorited, so we want to add
            if (!currentFavorites.contains(recipeId)) {
               transaction.update(userDocRef, {'favorites': FieldValue.arrayUnion([recipeId])});
            }
          }
        }
      });
      */
    } finally {
      setState(() {
        _isUpdatingFavorite = false;
      });
    }
  }

  // Helper method to format ingredients text
  String _formatIngredientsText(String? ingredients) {
    if (ingredients == null || ingredients.isEmpty) {
      return 'Malzemeler belirtilmemiş';
    }
    
    // Split by || and format each ingredient
    final ingredientsList = ingredients.split('||');
    return ingredientsList.map((ingredient) => '• $ingredient').join('\n');
  }

  // Helper method to format instructions text
  String _formatInstructionsText(String? instructions) {
    if (instructions == null || instructions.isEmpty) {
      return 'Hazırlanışı belirtilmemiş';
    }
    
    // Split by || and join with newlines
    return instructions.split('||').join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? widget.recipe['title'] ?? 'Tarif Detayı'),
        actions: [
          if (widget.recipe['id'] != null)
            _isUpdatingFavorite
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,)
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorited ? Colors.red : null,
                  ),
                  onPressed: _toggleFavoriteStatus,
                  tooltip: _isFavorited ? 'Favorilerden çıkar' : 'Favorilere ekle',
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.recipe['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _imageUrl ?? widget.recipe['imageUrl'],
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _description ?? widget.recipe['description'] ?? 'Açıklama yok',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Malzemeler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatIngredientsText(_ingredients ?? widget.recipe['ingredients']),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Hazırlanışı',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatInstructionsText(_instructions ?? widget.recipe['instructions']),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  if (widget.recipe['cookingTime'] != null) ...[
                    const Text(
                      'Pişirme Süresi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_cookTime ?? widget.recipe['cookingTime']} dakika',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                  if (widget.recipe['servings'] != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Porsiyon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.recipe['servings']} kişilik',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_prepTime != null || _cookTime != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_prepTime != null) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Hazırlık süresi: ${_prepTime ?? widget.recipe['prepTime']} dakika',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_cookTime != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.restaurant,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pişirme süresi: ${_cookTime ?? widget.recipe['cookTime']} dakika',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
