import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // Added for rootBundle
import 'recipe_detail_page.dart';
// Removed: import 'package:cloud_firestore/cloud_firestore.dart'; // Not needed for local search list

// Simple class to hold recipe data parsed from the text file
class LocalRecipe {
  final String id;
  final String title;
  final String imageUrl;
  // home_page.dart'taki kartta gösterilen ek bilgiler için alanlar eklenebilir.
  // final String ingredientsPreview; 
  // final String totalTimeText;

  LocalRecipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    // this.ingredientsPreview = '',
    // this.totalTimeText = '',
  });

  // Factory constructor to parse a line from recipes.txt
  // Example line: çilekli-ve-vişneli-cheesecake:{bisküvi...}{https://...}{95}{Çilekli ve Vişneli Cheesecake}
  factory LocalRecipe.fromLine(String line) {
    try {
      final idEndIndex = line.indexOf(':');
      if (idEndIndex == -1) throw FormatException("Missing ':' separator for ID.");
      final id = line.substring(0, idEndIndex);

      final parts = <String>[];
      int currentPartStartIndex = -1;
      bool inQuotes = false;
      StringBuffer sb = StringBuffer();

      for (int i = idEndIndex + 1; i < line.length; i++) {
        if (line[i] == '{' && !inQuotes) {
          currentPartStartIndex = i + 1;
          sb.clear();
        } else if (line[i] == '}' && !inQuotes && currentPartStartIndex != -1) {
          parts.add(sb.toString());
          currentPartStartIndex = -1;
        } else if (currentPartStartIndex != -1) {
          // Süslü parantez içindeki özel karakterleri koru
          sb.write(line[i]);
        }
      }
      
      // title her zaman sonuncu eleman
      if (parts.length < 4) throw FormatException("Line does not contain enough parts. Found ${parts.length}, expected at least 4 for title to be last.");
      
      return LocalRecipe(
        id: id,
        title: parts.last.trim(), // Son eleman her zaman title
        imageUrl: parts.length > 1 ? parts[1].trim() : '', // imageUrl ikinci eleman (varsa)
        // ingredientsPreview: parts.isNotEmpty ? parts[0].trim() : '', // İlk eleman malzemeler (varsa)
        // totalTimeText: parts.length > 2 ? parts[2].trim() : '', // Üçüncü eleman süre (varsa)
      );
    } catch (e) {
      debugPrint("Error parsing line '$line': $e");
      // Return a placeholder or rethrow, depending on desired error handling
      // For now, let's return a placeholder to avoid crashing if one line is bad
      return LocalRecipe(id: 'error-id', title: 'Error Parsing Recipe', imageUrl: '');
    }
  }
}

class RecipeSearchPage extends StatefulWidget {
  const RecipeSearchPage({super.key});

  @override
  State<RecipeSearchPage> createState() => _RecipeSearchPageState();
}

class _RecipeSearchPageState extends State<RecipeSearchPage> {
  String _searchText = "";
  final TextEditingController _searchController = TextEditingController();

  List<LocalRecipe> _allRecipes = [];
  List<LocalRecipe> _filteredRecipes = []; // Başlangıçta boş olacak
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipesFromAssets();
  }

  Future<void> _loadRecipesFromAssets() async {
    setState(() {
      _isLoading = true;
      _allRecipes = []; // Yükleme başlarken listeyi temizle
      _filteredRecipes = []; // Yükleme başlarken filtrelenmiş listeyi de temizle
    });
    try {
      final String fileContents = await rootBundle.loadString('assets/recipes.txt');
      final List<String> lines = fileContents.split('\n');
      
      final List<LocalRecipe> loadedRecipes = [];
      for (var line in lines) {
        if (line.trim().isNotEmpty) {
          loadedRecipes.add(LocalRecipe.fromLine(line.trim()));
        }
      }
      
      setState(() {
        _allRecipes = loadedRecipes.where((r) => r.id != 'error-id').toList();
        // _filteredRecipes = []; // Arama yapılana kadar boş kalacak
        _isLoading = false;
      });
      debugPrint("PIŞIR_DEBUG: Loaded ${_allRecipes.length} recipes from assets.");
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint("PIŞIR_DEBUG: Error loading recipes from assets: $e");
      // Optionally show an error message to the user
    }
  }

  void _filterRecipes() {
    final query = _searchText.toLowerCase().trim();
    debugPrint("PIŞIR_DEBUG: Filtering with query: '$query'");
    setState(() {
      if (query.isEmpty) {
        _filteredRecipes = []; // Arama metni boşsa sonuç gösterme
      } else {
        _filteredRecipes = _allRecipes
            .where((recipe) => recipe.title.toLowerCase().contains(query))
            .toList();
      }
      debugPrint("PIŞIR_DEBUG: Found ${_filteredRecipes.length} recipes matching '$query'");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarif Adıyla Ara'), 
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true, // Sayfa açıldığında otomatik odaklan
              decoration: InputDecoration(
                hintText: 'Bulmak istediğiniz tarifi yazın...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey[800] 
                            : Colors.grey[200],
                suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchText = "";
                        });
                        _filterRecipes(); 
                      },
                    )
                  : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
                _filterRecipes();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchText.isEmpty // Arama metni yoksa hiçbir şey gösterme
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Aramak için yukarıya tarif adı yazın.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : _filteredRecipes.isEmpty 
                        ? Center(
                            child: Text(
                              '"$_searchText" ile eşleşen tarif bulunamadı.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: _filteredRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = _filteredRecipes[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    debugPrint("PIŞIR_DEBUG: Tapped on recipe ID: ${recipe.id}, Title: ${recipe.title}");
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RecipeDetailPage(
                                          recipe: {
                                            'id': recipe.id,
                                            'title': recipe.title,
                                            'imageUrl': recipe.imageUrl,
                                          },
                                        ),
                                        settings: RouteSettings(
                                          arguments: {
                                            'id': recipe.id,
                                            'title': recipe.title,
                                            'imageUrl': recipe.imageUrl,
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: recipe.imageUrl.isNotEmpty && Uri.tryParse(recipe.imageUrl)?.hasAbsolutePath == true
                                              ? Image.network(
                                                  recipe.imageUrl,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      width: 100,
                                                      height: 100,
                                                      color: Colors.grey[200],
                                                      child: const Icon(
                                                        Icons.image_not_supported,
                                                        size: 30,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  width: 100,
                                                  height: 100,
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                    Icons.restaurant_menu, // Placeholder for missing/invalid image
                                                    size: 30,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center, // Dikeyde ortalamak için
                                            children: [
                                              Text(
                                                recipe.title,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2, // Başlık en fazla 2 satır olsun
                                                overflow: TextOverflow.ellipsis, // Taşarsa ... ile kesilsin
                                              ),
                                              // İsteğe bağlı: Malzeme önizlemesi veya süre gibi ek bilgiler buraya eklenebilir
                                              // if (recipe.ingredientsPreview.isNotEmpty) ...[
                                              //   const SizedBox(height: 8),
                                              //   Text(
                                              //     recipe.ingredientsPreview,
                                              //     style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                              //     maxLines: 2,
                                              //     overflow: TextOverflow.ellipsis,
                                              //   ),
                                              // ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
} 