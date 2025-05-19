import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  
  @override
  void initState() {
    super.initState();
    _loadRecipeDetails();
  }
  
  Future<void> _loadRecipeDetails() async {
    if (widget.recipe['id'] == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final recipeDoc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipe['id'].toString())
          .get();

      if (recipeDoc.exists) {
        final data = recipeDoc.data()!;
        setState(() {
          _title = data['title'] ?? '';
          _ingredients = data['ingredients'] ?? '';
          _instructions = data['instructions'] ?? '';
          _imageUrl = data['imageUrl'];
          _prepTime = data['prepTime'];
          _cookTime = data['cookTime'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recipe details: $e');
      setState(() {
        _isLoading = false;
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
        title: Text(widget.recipe['title'] ?? 'Tarif Detayı'),
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
                        widget.recipe['imageUrl'],
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
                    widget.recipe['description'] ?? 'Açıklama yok',
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
                      '${widget.recipe['cookingTime']} dakika',
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
                                  'Hazırlık süresi: $_prepTime dakika',
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
                                  'Pişirme süresi: $_cookTime dakika',
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
