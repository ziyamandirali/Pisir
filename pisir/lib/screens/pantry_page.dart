import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart'; // darkModeNotifier için import

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  static const String _pantryCacheKey = 'pantry_data_cache';
  static const String _recipesCacheKey = 'recipes_data_cache';
  static const String _lastUpdateKey = 'last_update_timestamp';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
      // Önce önbellekten verileri yüklemeyi dene
      await _loadFromCache();

      // Firestore'dan güncel verileri al
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

      // Verileri önbelleğe kaydet
      await _saveToCache(ingredients);

      if (mounted) {
        setState(() {
          _ingredients = ingredients;
          _isInitialized = true;
          _isLoading = false;
        });
      }

      // Tarifleri güncelle
      await _updateRecipesCache();
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

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(_pantryCacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> decodedData = json.decode(cachedData);
        final Map<String, List<String>> cachedIngredients = Map<String, List<String>>.from(
          decodedData.map((key, value) => MapEntry(
            key.toString(),
            List<String>.from(value as List),
          )),
        );
        
        if (mounted) {
          setState(() {
            _ingredients = cachedIngredients;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    }
  }

  Future<void> _saveToCache(Map<String, List<String>> ingredients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = json.encode(ingredients);
      await prefs.setString(_pantryCacheKey, encodedData);
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error saving to cache: $e');
    }
  }

  Future<void> _updateRecipesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastUpdate = prefs.getString(_lastUpdateKey);
      final DateTime lastUpdateTime = lastUpdate != null 
          ? DateTime.parse(lastUpdate) 
          : DateTime.now().subtract(const Duration(days: 1));

      // Son güncellemeden bu yana 24 saat geçtiyse veya hiç güncelleme yoksa
      if (DateTime.now().difference(lastUpdateTime).inHours >= 24) {
        // Tüm tarifleri getir
        final recipesSnapshot = await FirebaseFirestore.instance
            .collection('recipes')
            .get(GetOptions(source: Source.serverAndCache));

        final List<Map<String, dynamic>> recipes = recipesSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();

        // Tarifleri önbelleğe kaydet
        await prefs.setString(_recipesCacheKey, json.encode(recipes));
        await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint('Error updating recipes cache: $e');
    }
  }

  // Resim önbelleği için widget
  Widget _buildCachedImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.error),
      memCacheWidth: 300, // Önbellekteki resim boyutunu optimize et
      memCacheHeight: 300,
    );
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

  Map<String, List<String>> _getFilteredIngredients() {
    Map<String, List<String>> filteredBySearch = _ingredients;
    
    // Önce arama filtresini uygula
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredBySearch = {};
      
      _ingredients.forEach((category, ingredients) {
        final filteredList = ingredients.where((ingredient) {
          return ingredient.toLowerCase().contains(query) ||
                 category.toLowerCase().contains(query);
        }).toList();

        if (filteredList.isNotEmpty) {
          filteredBySearch[category] = filteredList;
        }
      });
    }

    // Sonra kategori filtresini uygula
    if (_selectedCategories.isNotEmpty) {
      final filteredByCategory = <String, List<String>>{};
      filteredBySearch.forEach((category, ingredients) {
        if (_selectedCategories.contains(category)) {
          filteredByCategory[category] = ingredients;
        }
      });
      return filteredByCategory;
    }

    return filteredBySearch;
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = darkModeNotifier.value;
    if (!_isInitialized || _deviceId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filteredIngredients = _getFilteredIngredients();

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
                child: Text(
                  'Tümünü Seç',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              ),
              TextButton(
                onPressed: _toggleSelectionMode,
                child: Text(
                  'İptal',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _ingredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.kitchen_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz malzeme eklenmemiş',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
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
                          icon: const Icon(Icons.add),
                          label: const Text('Malzeme Ekle'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Arama çubuğu
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Malzeme ara...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      // Kategori seçici
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _ingredients.length,
                          itemBuilder: (context, index) {
                            final category = _ingredients.keys.elementAt(index);
                            final hasIngredients = _ingredients[category]?.isNotEmpty ?? false;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(category),
                                  ],
                                ),
                                selected: _selectedCategories.contains(category),
                                onSelected: hasIngredients ? (selected) {
                                  _toggleCategory(category);
                                } : null,
                                backgroundColor: hasIngredients
                                    ? (_selectedCategories.contains(category)
                                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                                        : null)
                                    : Colors.grey[200],
                              ),
                            );
                          },
                        ),
                      ),
                      // Malzeme listesi
                      Expanded(
                        child: filteredIngredients.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Arama sonucu bulunamadı',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: filteredIngredients.length,
                                itemBuilder: (context, categoryIndex) {
                                  final category = filteredIngredients.keys.elementAt(categoryIndex);
                                  final ingredients = filteredIngredients[category]!;
                                  
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              /*Icon(
                                                _getCategoryIcon(category),
                                                color: Theme.of(context).colorScheme.primary,
                                              
                                              )*/
                                              const SizedBox(width: 8),
                                              Text(
                                                category,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        ...ingredients.map((ingredient) => ListTile(
                                          key: Key('$category-$ingredient'),
                                          title: Text(ingredient),
                                          leading: const Icon(Icons.kitchen),
                                          trailing: _isSelectionMode
                                              ? Checkbox(
                                                value: _selectedIngredients.contains('$category-$ingredient'),
                                                onChanged: (bool? value) {
                                                  _toggleIngredientSelection(category, ingredient);
                                                },
                                              )
                                              : null,
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
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'sebze':
        return Icons.eco;
      case 'meyve':
        return Icons.apple;
      case 'et':
        return Icons.restaurant;
      case 'süt ürünleri':
        return Icons.water_drop;
      case 'bakliyat':
        return Icons.grain;
      case 'baharat':
        return Icons.spa;
      case 'unlu mamüller':
        return Icons.bakery_dining;
      case 'içecek':
        return Icons.local_drink;
      default:
        return Icons.category;
    }
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
    final isDark = darkModeNotifier.value; // isDark değişkenini burada tanımla
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
                color: _selectedIngredients.isEmpty 
                    ? Colors.grey 
                    : isDark // Tanımlı isDark değişkenini kullan
                        ? Colors.white 
                        : Colors.black,
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
