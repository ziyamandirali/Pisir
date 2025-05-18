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
  String? _deviceId;
  List<Map<String, dynamic>> _matchingRecipes = [];
  Map<String, List<String>> _pantryIngredients = {};

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
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
          .get();

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
      debugPrint('Error loading pantry ingredients: $e');
    }
  }

  Future<void> _loadMatchingRecipes() async {
    if (_deviceId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all pantry ingredients as a flat list
      final List<String> allPantryIngredients = _pantryIngredients.values
          .expand((ingredients) => ingredients)
          .map((ingredient) => ingredient.toLowerCase())
          .toList();

      // Get all recipes
      final recipesSnapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .get();

      final List<Map<String, dynamic>> matchingRecipes = [];

      for (var recipeDoc in recipesSnapshot.docs) {
        final recipeData = recipeDoc.data();
        final ingredientsOnly = recipeData['ingredientsOnly'] as String?;
        
        if (ingredientsOnly != null) {
          final recipeIngredients = ingredientsOnly
              .split(',')
              .map((ingredient) => ingredient.trim().toLowerCase())
              .toList();

          // Check if ALL recipe ingredients are in pantry
          final allIngredientsAvailable = recipeIngredients.every(
            (recipeIngredient) => allPantryIngredients.any(
              (pantryIngredient) => recipeIngredient.contains(pantryIngredient) ||
                  pantryIngredient.contains(recipeIngredient),
            ),
          );

          if (allIngredientsAvailable) {
            matchingRecipes.add({
              'id': recipeDoc.id,
              'title': recipeData['title'],
              'ingredientsOnly': ingredientsOnly,
              'ingredients': recipeData['ingredients'],
              'instructions': recipeData['instructions'],
            });
          }
        }
      }

      setState(() {
        _matchingRecipes = matchingRecipes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading matching recipes: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
      body: _isLoading
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
                  padding: const EdgeInsets.all(16),
                  itemCount: _matchingRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _matchingRecipes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          recipe['title'] ?? 'İsimsiz Tarif',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Malzemeler: ${recipe['ingredientsOnly']}',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/recipeDetail',
                            arguments: recipe,
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
