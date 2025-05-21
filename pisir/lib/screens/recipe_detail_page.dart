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
    if (widget.recipe['id'] == null) return;

    setState(() {
      _isLoading = true;
      _isUpdatingFavorite = true;
    });

    try {
      final recipeId = widget.recipe['id'].toString();
      final deviceId = await _getDeviceId();

      final recipeDocFuture = FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get(GetOptions(source: Source.serverAndCache));

      Future<DocumentSnapshot?>? favoriteStatusFuture;
      if (deviceId != null) {
        favoriteStatusFuture = FirebaseFirestore.instance
            .collection('users')
            .doc(deviceId)
            .collection('favorites')
            .doc(recipeId)
            .get();
      } else {
        debugPrint('Device ID not found. Cannot load favorite status.');
        setState(() {
          _isUpdatingFavorite = false; 
        });
      }

      final results = await Future.wait([
        recipeDocFuture,
        if (favoriteStatusFuture != null) favoriteStatusFuture,
      ]);

      final recipeDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      bool isFavorited = false;
      if (results.length > 1 && results[1] != null) {
        final favoriteDoc = results[1] as DocumentSnapshot;
        isFavorited = favoriteDoc.exists;
      }
      
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
          _isFavorited = isFavorited;
          _isLoading = false;
          _isUpdatingFavorite = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isUpdatingFavorite = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recipe details or favorite status: $e');
      setState(() {
        _isLoading = false;
        _isUpdatingFavorite = false;
      });
    }
  }

  Future<void> _toggleFavoriteStatus() async {
    final deviceId = await _getDeviceId();

    if (deviceId == null) {
      debugPrint('Device ID not found. Cannot change favorite status.');
      return;
    }

    if (widget.recipe['id'] == null) return;
    final recipeId = widget.recipe['id'].toString();

    setState(() {
      _isUpdatingFavorite = true;
    });

    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(deviceId)
        .collection('favorites')
        .doc(recipeId);

    try {
      if (_isFavorited) {
        await favoriteRef.delete();
      } else {
        await favoriteRef.set({'favoritedAt': FieldValue.serverTimestamp()});
      }
      setState(() {
        _isFavorited = !_isFavorited;
      });
    } catch (e) {
      debugPrint('Error updating favorite status: $e');
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
