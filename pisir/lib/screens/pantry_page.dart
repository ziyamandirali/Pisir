import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  PantryPageState createState() => PantryPageState();
}

class PantryPageState extends State<PantryPage> {
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _deviceId;
  List<String> _ingredients = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadDeviceId();
    if (mounted) {
      await _initializePantry();
    }
  }

  Future<void> _loadDeviceId() async {
    debugPrint('Loading device ID from SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    debugPrint('Loaded device ID: $deviceId');
    
    if (mounted) {
      setState(() {
        _deviceId = deviceId;
      });
    }
  }

  Future<void> _initializePantry() async {
    if (_deviceId == null) {
      debugPrint('Device ID is null, redirecting to login');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    debugPrint('Initializing pantry for device: $_deviceId');

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_deviceId)
          .get();

      debugPrint('User document exists: ${userDoc.exists}');

      if (!userDoc.exists) {
        debugPrint('Creating new user document');
        // Kullanıcı dokümanı yoksa oluştur
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_deviceId)
            .set({'pantry': ''});
        
        if (mounted) {
          setState(() {
            _ingredients = [];
            _isInitialized = true;
          });
        }
        debugPrint('New user document created');
        return;
      }

      // Kullanıcı dokümanı var ama pantry field'ı yoksa ekle
      if (!userDoc.data()!.containsKey('pantry')) {
        debugPrint('Adding pantry field to existing user document');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_deviceId)
            .update({'pantry': ''});
        
        if (mounted) {
          setState(() {
            _ingredients = [];
            _isInitialized = true;
          });
        }
        debugPrint('Pantry field added');
        return;
      }

      // Pantry field'ı varsa malzemeleri yükle
      debugPrint('Loading existing pantry items');
      final pantryString = userDoc.data()?['pantry'] as String? ?? '';
      if (mounted) {
        setState(() {
          _ingredients = pantryString.split(',').where((s) => s.isNotEmpty).toList();
          _isInitialized = true;
        });
      }
      debugPrint('Pantry items loaded: ${_ingredients.length} items');
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
        // Hata durumunda da initialized'ı true yapalım ki loading ekranında takılı kalmasın
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _removeIngredient(String ingredient) async {
    if (_deviceId == null) return;

    try {
      final updatedIngredients = _ingredients.where((i) => i != ingredient).toList();
      final pantryString = updatedIngredients.join(',');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_deviceId)
          .update({'pantry': pantryString});

      setState(() {
        _ingredients = updatedIngredients;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Malzeme başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Malzeme silinirken hata oluştu: $e'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutfak Dolabı'),
      ),
      body: _ingredients.isEmpty
          ? const Center(
              child: Text('Henüz malzeme eklenmemiş'),
            )
          : ListView.builder(
              itemCount: _ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = _ingredients[index];
                
                return Dismissible(
                  key: Key(ingredient),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _removeIngredient(ingredient);
                  },
                  child: ListTile(
                    title: Text(ingredient),
                    leading: const Icon(Icons.kitchen),
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Malzemeyi Sil'),
                            content: Text('$ingredient malzemesini silmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _removeIngredient(ingredient);
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Sil',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
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
    );
  }
}

class AddIngredientPage extends StatefulWidget {
  final List<String> existingIngredients;
  final Function(List<String>) onIngredientsAdded;

  const AddIngredientPage({
    super.key,
    required this.existingIngredients,
    required this.onIngredientsAdded,
  });

  @override
  AddIngredientPageState createState() => AddIngredientPageState();
}

class AddIngredientPageState extends State<AddIngredientPage> {
  final List<String> _allIngredients = [
    'yumurta', 'un', 'şeker', 'tuz', 'süt', 'yoğurt', 'zeytinyağı'
  ];

  final List<String> _selectedIngredients = [];
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredIngredients = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializePage();
  }

  Future<void> _initializePage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadDeviceId();
      await _initializeIngredients();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _loadDeviceId() async {
    debugPrint('Loading device ID from SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    debugPrint('Loaded device ID: $deviceId');
    
    if (mounted) {
      setState(() {
        _deviceId = deviceId;
      });
    }
  }

  Future<void> _initializeIngredients() async {
    try {
      // Mevcut malzemeleri hariç tut
      final availableIngredients = _allIngredients
          .where((ingredient) => !widget.existingIngredients.contains(ingredient.toLowerCase()))
          .toList();

      setState(() {
        _filteredIngredients = availableIngredients;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Malzemeler yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredIngredients = _allIngredients
          .where((ingredient) => 
              ingredient.toLowerCase().contains(query) &&
              !widget.existingIngredients.contains(ingredient.toLowerCase()))
          .toList();
    });
  }

  Future<void> _saveIngredients() async {
    if (_deviceId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedIngredients = [...widget.existingIngredients, ..._selectedIngredients];
      final pantryString = updatedIngredients.join(',');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_deviceId)
          .update({'pantry': pantryString});

      widget.onIngredientsAdded(updatedIngredients);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Malzemeler başarıyla eklendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Malzemeler eklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Malzeme Ekle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Malzeme Ara',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _filteredIngredients.isEmpty
                ? const Center(
                    child: Text('Eklenebilecek yeni malzeme kalmadı'),
                  )
                : ListView.builder(
                    itemCount: _filteredIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = _filteredIngredients[index];
                      final isSelected = _selectedIngredients.contains(ingredient);

                      return ListTile(
                        title: Text(ingredient),
                        trailing: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? Colors.green : null,
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIngredients.remove(ingredient);
                            } else {
                              _selectedIngredients.add(ingredient);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedIngredients.isEmpty || _isLoading ? null : _saveIngredients,
        backgroundColor: _selectedIngredients.isEmpty ? Colors.grey : Colors.purple[100],
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
      ),
    );
  }
}
