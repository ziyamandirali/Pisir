import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  PantryPageState createState() => PantryPageState();
}

class PantryPageState extends State<PantryPage> {
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _deviceId;
  Map<String, List<String>> _ingredients = {};
  bool _isSelectionMode = false;
  Set<String> _selectedIngredients = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    await _loadDeviceId();
    
    if (mounted) {
      await _initializePantry();
    }
  }

  Future<void> _loadDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      
      if (mounted) {
        setState(() {
          _deviceId = deviceId;
        });
      }
    } catch (e) {
      debugPrint('Error loading device ID: $e');
    }
  }

  Future<void> _initializePantry() async {
    if (_deviceId == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_deviceId)
          .get(GetOptions(source: Source.serverAndCache));

      if (!userDoc.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_deviceId)
            .set({'pantry': {}});
        
        if (mounted) {
          setState(() {
            _ingredients = {};
            _isInitialized = true;
            _isLoading = false;
          });
        }
        return;
      }

      if (!userDoc.data()!.containsKey('pantry')) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_deviceId)
            .update({'pantry': {}});
        
        if (mounted) {
          setState(() {
            _ingredients = {};
            _isInitialized = true;
            _isLoading = false;
          });
        }
        return;
      }

      final pantryData = userDoc.data()?['pantry'];
      Map<String, List<String>> ingredients = {};
      
      if (pantryData != null) {
        if (pantryData is Map) {
          ingredients = Map<String, List<String>>.from(
            (pantryData as Map).map((key, value) => MapEntry(
              key.toString(),
              List<String>.from(value as List),
            )),
          );
        } else if (pantryData is String) {
          final List<String> oldIngredients = pantryData.split(',').where((s) => s.isNotEmpty).toList();
          if (oldIngredients.isNotEmpty) {
            ingredients['Genel'] = oldIngredients;
          }
        }
      }

      if (mounted) {
        setState(() {
          _ingredients = ingredients;
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _initializePantry: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Malzemeler yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIngredients.clear();
      }
    });
  }

  void _toggleIngredientSelection(String category, String ingredient) {
    setState(() {
      final key = '$category-$ingredient';
      if (_selectedIngredients.contains(key)) {
        _selectedIngredients.remove(key);
      } else {
        _selectedIngredients.add(key);
      }
    });
  }

  void _selectAllIngredients() {
    setState(() {
      _selectedIngredients.clear();
      for (var category in _ingredients.keys) {
        for (var ingredient in _ingredients[category]!) {
          _selectedIngredients.add('$category-$ingredient');
        }
      }
    });
  }

  Future<void> _deleteSelectedIngredients() async {
    if (_deviceId == null || _selectedIngredients.isEmpty) return;

    try {
      final updatedIngredients = Map<String, List<String>>.from(_ingredients);
      
      for (var key in _selectedIngredients) {
        final parts = key.split('-');
        final category = parts[0];
        final ingredient = parts[1];
        
        if (updatedIngredients.containsKey(category)) {
          updatedIngredients[category] = updatedIngredients[category]!
              .where((i) => i != ingredient)
              .toList();

          if (updatedIngredients[category]!.isEmpty) {
            updatedIngredients.remove(category);
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_deviceId)
          .update({'pantry': updatedIngredients});

      if (mounted) {
        setState(() {
          _ingredients = updatedIngredients;
          _selectedIngredients.clear();
          _isSelectionMode = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seçili malzemeler başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Malzemeler silinirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _deviceId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedIngredients.clear();
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mutfak Dolabı'),
          actions: [
            if (_isSelectionMode) ...[
              TextButton(
                onPressed: _selectAllIngredients,
                child: const Text(
                  'Tümünü Seç',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              TextButton(
                onPressed: _toggleSelectionMode,
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _ingredients.isEmpty
                ? const Center(
                    child: Text('Henüz malzeme eklenmemiş'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _ingredients.length,
                    itemBuilder: (context, categoryIndex) {
                      final category = _ingredients.keys.elementAt(categoryIndex);
                      final ingredients = _ingredients[category]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...ingredients.map((ingredient) => ListTile(
                            key: Key('$category-$ingredient'),
                            title: Text(ingredient),
                            leading: _isSelectionMode
                                ? Checkbox(
                                    value: _selectedIngredients.contains('$category-$ingredient'),
                                    onChanged: (bool? value) {
                                      _toggleIngredientSelection(category, ingredient);
                                    },
                                  )
                                : const Icon(Icons.kitchen),
                            onTap: _isSelectionMode
                                ? () {
                                    _toggleIngredientSelection(category, ingredient);
                                  }
                                : null,
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                _toggleSelectionMode();
                                _toggleIngredientSelection(category, ingredient);
                              }
                            },
                          )).toList(),
                        ],
                      );
                    },
                  ),
        floatingActionButton: _isSelectionMode
            ? FloatingActionButton(
                onPressed: _selectedIngredients.isEmpty ? null : _deleteSelectedIngredients,
                backgroundColor: _selectedIngredients.isEmpty ? Colors.grey : Colors.red,
                child: const Icon(Icons.delete),
              )
            : FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddIngredientPage(
                        existingIngredients: _ingredients,
                        onIngredientsAdded: (newIngredients) {
                          setState(() {
                            _ingredients = newIngredients;
                          });
                        },
                      ),
                    ),
                  );
                },
                backgroundColor: Colors.purple[100],
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}

class AddIngredientPage extends StatefulWidget {
  final Map<String, List<String>> existingIngredients;
  final Function(Map<String, List<String>>) onIngredientsAdded;

  const AddIngredientPage({
    super.key,
    required this.existingIngredients,
    required this.onIngredientsAdded,
  });

  @override
  State<AddIngredientPage> createState() => _AddIngredientPageState();
}

class _AddIngredientPageState extends State<AddIngredientPage> {
  Map<String, List<String>> _categories = {};
  String? _selectedCategory;
  Map<String, List<String>> _selectedIngredients = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
      for (var category in _categories.entries) {
        for (var ingredient in category.value) {
          if (ingredient.toLowerCase().contains(query)) {
            _searchResults.add(ingredient);
          }
        }
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final String data = await DefaultAssetBundle.of(context).loadString('assets/categorized.txt');
      final List<String> lines = data.split('\n');
      
      Map<String, List<String>> categories = {};
      String currentCategory = '';
      
      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        
        if (line == line.toUpperCase()) {
          currentCategory = line;
          categories[currentCategory] = [];
        } else if (currentCategory.isNotEmpty) {
          categories[currentCategory]!.add(line);
        }
      }
      
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleIngredient(String category, String ingredient) {
    setState(() {
      if (_selectedIngredients.containsKey(category)) {
        if (_selectedIngredients[category]!.contains(ingredient)) {
          _selectedIngredients[category]!.remove(ingredient);
          if (_selectedIngredients[category]!.isEmpty) {
            _selectedIngredients.remove(category);
          }
        } else {
          _selectedIngredients[category]!.add(ingredient);
        }
      } else {
        _selectedIngredients[category] = [ingredient];
      }
    });
  }

  bool _isIngredientSelected(String category, String ingredient) {
    return _selectedIngredients[category]?.contains(ingredient) ?? false;
  }

  bool _isIngredientExisting(String category, String ingredient) {
    return widget.existingIngredients[category]?.contains(ingredient) ?? false;
  }

  Future<void> _saveIngredients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      
      if (deviceId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cihaz ID bulunamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final newIngredients = Map<String, List<String>>.from(widget.existingIngredients);
      
      for (var entry in _selectedIngredients.entries) {
        if (newIngredients.containsKey(entry.key)) {
          newIngredients[entry.key] = [
            ...newIngredients[entry.key]!,
            ...entry.value,
          ];
        } else {
          newIngredients[entry.key] = entry.value;
        }
      }

      // Firestore'a kaydet
      await FirebaseFirestore.instance
          .collection('users')
          .doc(deviceId)
          .update({
            'pantry': newIngredients.map(
              (key, value) => MapEntry(key, value),
            ),
          });

      if (mounted) {
        widget.onIngredientsAdded(newIngredients);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Malzemeler başarıyla kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving ingredients: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Malzemeler kaydedilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Malzeme Ekle'),
        actions: [
          TextButton(
            onPressed: _selectedIngredients.isEmpty ? null : _saveIngredients,
            child: Text(
              'Kaydet',
              style: TextStyle(
                color: _selectedIngredients.isEmpty ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Malzeme Ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          if (!_isSearching) ...[
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories.keys.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _selectedCategory == null
                  ? const Center(
                      child: Text('Lütfen bir kategori seçin'),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedCategory != null ? _categories[_selectedCategory]?.length ?? 0 : 0,
                      itemBuilder: (context, index) {
                        if (_selectedCategory == null) return const SizedBox.shrink();
                        
                        final category = _selectedCategory!;
                        final ingredients = _categories[category];
                        if (ingredients == null) return const SizedBox.shrink();
                        
                        final ingredient = ingredients[index];
                        final isSelected = _isIngredientSelected(category, ingredient);
                        final isExisting = _isIngredientExisting(category, ingredient);
                        
                        return FilterChip(
                          label: Text(
                            ingredient,
                            style: TextStyle(
                              color: isExisting ? Colors.grey : null,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: isExisting ? null : (selected) {
                            _toggleIngredient(category, ingredient);
                          },
                          backgroundColor: isExisting ? Colors.grey[200] : null,
                        );
                      },
                    ),
            ),
          ] else ...[
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(
                      child: Text('Sonuç bulunamadı'),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final ingredient = _searchResults[index];
                        String? ingredientCategory;
                        
                        for (var entry in _categories.entries) {
                          if (entry.value.contains(ingredient)) {
                            ingredientCategory = entry.key;
                            break;
                          }
                        }
                        
                        if (ingredientCategory == null) return const SizedBox.shrink();
                        
                        final category = ingredientCategory;
                        final isSelected = _isIngredientSelected(category, ingredient);
                        final isExisting = _isIngredientExisting(category, ingredient);
                        
                        return FilterChip(
                          label: Text(
                            ingredient,
                            style: TextStyle(
                              color: isExisting ? Colors.grey : null,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: isExisting ? null : (selected) {
                            _toggleIngredient(category, ingredient);
                          },
                          backgroundColor: isExisting ? Colors.grey[200] : null,
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
