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

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _initializePantry();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id');
    });
  }

  Future<void> _initializePantry() async {
    try {
      setState(() {
        _isInitialized = true;
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

  Future<void> _removeIngredient(String ingredientId) async {
    try {
      await FirebaseFirestore.instance
          .collection('pantry')
          .doc(ingredientId)
          .delete();
      
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

  Future<void> _removeDuplicateIngredients() async {
    if (_deviceId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pantry')
          .where('device_id', isEqualTo: _deviceId)
          .get();

      final Map<String, List<String>> nameToIds = {};
      
      // Malzemeleri isimlerine göre grupla
      for (var doc in snapshot.docs) {
        final name = doc.data()['name']?.toString().toLowerCase() ?? '';
        if (!nameToIds.containsKey(name)) {
          nameToIds[name] = [];
        }
        nameToIds[name]!.add(doc.id);
      }

      // Tekrar eden malzemeleri sil
      final batch = FirebaseFirestore.instance.batch();
      for (var ids in nameToIds.values) {
        if (ids.length > 1) {
          // İlk malzemeyi tut, diğerlerini sil
          for (var i = 1; i < ids.length; i++) {
            batch.delete(FirebaseFirestore.instance.collection('pantry').doc(ids[i]));
          }
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error removing duplicates: $e');
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pantry')
            .where('device_id', isEqualTo: _deviceId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Bir hata oluştu: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Henüz malzeme eklenmemiş'),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return Dismissible(
                key: Key(doc.id),
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
                  _removeIngredient(doc.id);
                },
                child: ListTile(
                  title: Text(data['name']?.toString() ?? ''),
                  leading: const Icon(Icons.kitchen),
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Malzemeyi Sil'),
                          content: Text('${data['name']?.toString() ?? ''} malzemesini silmek istediğinize emin misiniz?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('İptal'),
                            ),
                            TextButton(
                              onPressed: () {
                                _removeIngredient(doc.id);
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddIngredientPage(),
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
  const AddIngredientPage({super.key});

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
  Set<String> _existingIngredients = {};

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
      await _loadExistingIngredients();
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id');
    });
  }

  Future<void> _loadExistingIngredients() async {
    if (_deviceId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pantry')
          .where('device_id', isEqualTo: _deviceId)
          .get();

      setState(() {
        _existingIngredients = snapshot.docs
            .map((doc) => doc.data()['name']?.toString().toLowerCase() ?? '')
            .toSet();
      });
    } catch (e) {
      debugPrint('Error loading existing ingredients: $e');
    }
  }

  Future<void> _initializeIngredients() async {
    try {
      // Mevcut malzemeleri hariç tut
      final availableIngredients = _allIngredients
          .where((ingredient) => !_existingIngredients.contains(ingredient.toLowerCase()))
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
              !_existingIngredients.contains(ingredient.toLowerCase()))
          .toList();
    });
  }

  Future<void> _saveIngredients() async {
    if (_deviceId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Mevcut malzemeleri tekrar kontrol et
      final snapshot = await FirebaseFirestore.instance
          .collection('pantry')
          .where('device_id', isEqualTo: _deviceId)
          .get();

      final currentIngredients = snapshot.docs
          .map((doc) => doc.data()['name']?.toString().toLowerCase() ?? '')
          .toSet();

      // Sadece dolapta olmayan malzemeleri ekle
      final newIngredients = _selectedIngredients
          .where((ingredient) => !currentIngredients.contains(ingredient.toLowerCase()))
          .toList();

      if (newIngredients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seçilen malzemeler zaten dolapta mevcut'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      
      for (final ingredient in newIngredients) {
        final docRef = FirebaseFirestore.instance.collection('pantry').doc();
        batch.set(docRef, {
          'name': ingredient,
          'device_id': _deviceId,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

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
