import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  PantryPageState createState() => PantryPageState();
}

class PantryPageState extends State<PantryPage> {
  bool _isLoading = false;
  bool _isInitialized = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializePantry();
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Lütfen giriş yapın'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Giriş Yap'),
              ),
            ],
          ),
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
            .where('userId', isEqualTo: user.email)
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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeIngredients();
  }

  Future<void> _initializeIngredients() async {
    try {
      setState(() {
        _filteredIngredients = List.from(_allIngredients);
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredIngredients = _allIngredients
          .where((item) =>
              item.toLowerCase().startsWith(query) &&
              !_selectedIngredients.contains(item))
          .toList();
    });
  }

  void _selectIngredient(String ingredient) {
    if (!mounted) return;
    setState(() {
      _selectedIngredients.add(ingredient);
      _searchController.clear();
      _filteredIngredients = _allIngredients
          .where((String item) => !_selectedIngredients.contains(item))
          .toList();
    });
  }

  void _removeIngredient(String ingredient) {
    if (!mounted) return;
    setState(() {
      _selectedIngredients.remove(ingredient);
      _filteredIngredients = _allIngredients
          .where((String item) => !_selectedIngredients.contains(item))
          .toList();
    });
  }

  Future<void> _addToPantry() async {
    if (_selectedIngredients.isEmpty || !mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce giriş yapın'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pantryRef = FirebaseFirestore.instance.collection('pantry');
      final batch = FirebaseFirestore.instance.batch();

      // Mevcut malzemeleri kontrol et
      final existingIngredients = await pantryRef
          .where('userId', isEqualTo: user.email)
          .get();
      final existingNames = existingIngredients.docs
          .map((doc) => (doc.data()['name'] as String).toLowerCase())
          .toSet();

      for (var ingredient in _selectedIngredients) {
        // Eğer malzeme zaten varsa, ekleme
        if (existingNames.contains(ingredient.toLowerCase())) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$ingredient zaten dolapta mevcut'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          continue;
        }

        final docRef = pantryRef.doc();
        batch.set(docRef, {
          'name': ingredient,
          'userId': user.email,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Malzemeler başarıyla eklendi!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('Error adding to pantry: $e');
      print('Stack trace: $stackTrace');
      
      String errorMessage = 'Hata oluştu: ';
      if (e.toString().contains('database (default) does not exist')) {
        errorMessage = 'Firestore veritabanı henüz oluşturulmamış. Lütfen Firebase Console\'da veritabanını oluşturun.';
      } else {
        errorMessage += e.toString();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: [
                    for (var ingredient in _selectedIngredients)
                      Chip(
                        label: Text(ingredient),
                        onDeleted: () => _removeIngredient(ingredient),
                      ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Malzeme ara...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredIngredients.length,
                    itemBuilder: (context, index) {
                      final item = _filteredIngredients[index];
                      return ListTile(
                        title: Text(item),
                        trailing: const Icon(Icons.add),
                        onTap: () => _selectIngredient(item),
                      );
                    },
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading || _selectedIngredients.isEmpty
                      ? null
                      : _addToPantry,
                  icon: const Icon(Icons.add),
                  label: Text(_isLoading ? 'Ekleniyor...' : 'Dolaba Ekle'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
