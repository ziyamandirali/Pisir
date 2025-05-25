import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  String? _youtubeVideoId;
  bool _isFavorited = false;
  bool _isUpdatingFavorite = false;
  WebViewController? _webViewController;
  
  // Nutritional value variables
  Map<String, String>? _nutritionalValues;
  
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
    debugPrint("[RecipeDetailPage] _loadRecipeDetails CALLED.");
    debugPrint("[RecipeDetailPage] Initial widget.recipe: ${widget.recipe}");

    if (widget.recipe['id'] == null) {
      debugPrint("[RecipeDetailPage] recipe['id'] is NULL. Exiting _loadRecipeDetails early.");
      setState(() { 
        _isLoading = false; 
        _isUpdatingFavorite = false; 
      });
      return;
    }

    final recipeId = widget.recipe['id'].toString();
    debugPrint("[RecipeDetailPage] Determined recipeId: $recipeId");

    setState(() { 
      _isLoading = true; 
      _isUpdatingFavorite = true; 
    });

    bool determinedIsFavoritedFlag = false; 
    bool actualInitialIsFavoritedValue = false;

    try {
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
        debugPrint('[RecipeDetailPage] Device ID not found. Cannot load favorite status.');
        actualInitialIsFavoritedValue = false; 
        determinedIsFavoritedFlag = true;
      }

      debugPrint("[RecipeDetailPage] Fetching recipe document from Firestore for ID: $recipeId");
      final recipeDoc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get(const GetOptions(source: Source.serverAndCache)); // Added const

      if (recipeDoc.exists) {
        debugPrint("[RecipeDetailPage] Recipe document FOUND for ID: $recipeId");
        final data = recipeDoc.data()!;
        debugPrint("[RecipeDetailPage] Firestore data received: $data");
        debugPrint("[RecipeDetailPage] Firestore data['description'] specific value: ${data['description']}");
        debugPrint("[RecipeDetailPage] Firestore data['youtube_url'] specific value: ${data['youtube_url']}");
        debugPrint("[RecipeDetailPage] Firestore data['nutritionalValue'] specific value: ${data['nutritionalValue']}");
        
        setState(() {
          _title = data['title'] ?? widget.recipe['title'] ?? 'Tarif Başlığı Yok'; // Robust title
          _ingredients = data['ingredients'] ?? '';
          _instructions = data['instructions'] ?? '';
          _imageUrl = data['imageUrl'];
          _prepTime = data['prepTime']?.toString(); // Convert int/double to String
          _cookTime = data['cookTime']?.toString(); // Convert int/double to String
          _description = data['description']; // Keep as is from previous fix
          _youtubeVideoId = data['youtubeId']; // YouTube video ID from Firestore
          _nutritionalValues = _parseNutritionalValues(data['nutritionalValue']);
          if (determinedIsFavoritedFlag) {
             _isFavorited = actualInitialIsFavoritedValue;
          }
          _isLoading = false;
          _isUpdatingFavorite = false;
        });
        
        debugPrint("[RecipeDetailPage] Parsed nutritional values: $_nutritionalValues");
      } else {
        debugPrint("[RecipeDetailPage] Recipe document NOT FOUND in Firestore for ID: $recipeId");
        setState(() {
          _title = widget.recipe['title'] ?? 'Tarif Bulunamadı'; // Fallback title
          // _description will remain null, displayDescription will handle it
          _nutritionalValues = _parseNutritionalValues(widget.recipe['nutritionalValue']);
          if (determinedIsFavoritedFlag) {
            _isFavorited = actualInitialIsFavoritedValue;
          }
          _isLoading = false;
          _isUpdatingFavorite = false;
          debugPrint('[RecipeDetailPage] Recipe document not found, but favorite status determined.');
        });
        debugPrint("[RecipeDetailPage] Fallback nutritional values from widget.recipe: $_nutritionalValues");
      }
    } catch (e) {
      debugPrint('[RecipeDetailPage] Error loading recipe details or favorite status: $e');
      setState(() {
        _title = widget.recipe['title'] ?? 'Hata Oluştu'; // Error title
        // _description will remain null
        _nutritionalValues = _parseNutritionalValues(widget.recipe['nutritionalValue']);
        if (determinedIsFavoritedFlag) {
          _isFavorited = actualInitialIsFavoritedValue;
        }
        _isLoading = false;
        _isUpdatingFavorite = false;
      });
    }
    debugPrint("[RecipeDetailPage] _loadRecipeDetails FINISHED. Current state _description: $_description");
    debugPrint("[RecipeDetailPage] _loadRecipeDetails FINISHED. Current state _youtubeVideoId: $_youtubeVideoId");
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

  String get displayDescription {
    // Use _description from Firestore if it's valid (not null, not empty)
    if (_description != null && _description!.isNotEmpty) {
      return _description!;
    }
    // Fallback to initial widget.recipe['description'] if it's valid
    final initialDescription = widget.recipe['description'] as String?;
    if (initialDescription != null && initialDescription.isNotEmpty) {
      return initialDescription;
    }
    // Default placeholder
    return 'Açıklama yok';
  }

  // Helper method to check if video ID is valid
  bool _isValidYouTubeVideoId(String? videoId) {
    if (videoId == null || videoId.isEmpty) return false;
    
    // Basic validation for YouTube video ID (11 characters, alphanumeric and some special chars)
    return videoId.length == 11 && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(videoId);
  }

  // Helper method to parse nutritional values
  Map<String, String>? _parseNutritionalValues(dynamic nutritionalValue) {
    if (nutritionalValue == null) return null;
    
    try {
      String nutritionalString;
      
      // Handle different data types
      if (nutritionalValue is String) {
        nutritionalString = nutritionalValue;
      } else if (nutritionalValue is Map) {
        // If it's already a map, convert to our expected format
        return Map<String, String>.from(nutritionalValue.map((key, value) => 
          MapEntry(key.toString(), value.toString())));
      } else {
        nutritionalString = nutritionalValue.toString();
      }
      
      if (nutritionalString.isEmpty || nutritionalString == 'null') return null;
      
      final Map<String, String> nutritionalMap = {};
      
      // Parse format: "Kalori: 250 kcal||Protein: 15g||Karbonhidrat: 30g||Yağ: 8g"
      // Also handle alternative formats like "Kalori:250kcal||Protein:15g"
      final parts = nutritionalString.split('||');
      
      for (final part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.isEmpty) continue;
        
        final colonIndex = trimmedPart.indexOf(':');
        if (colonIndex != -1 && colonIndex < trimmedPart.length - 1) {
          final key = trimmedPart.substring(0, colonIndex).trim();
          final value = trimmedPart.substring(colonIndex + 1).trim();
          
          if (key.isNotEmpty && value.isNotEmpty) {
            // Clean up common formatting issues
            String cleanKey = key.replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞIÖÇ]'), '').trim();
            String cleanValue = value.trim();
            
            // Ensure we have valid data
            if (cleanKey.isNotEmpty && cleanValue.isNotEmpty) {
              nutritionalMap[cleanKey] = cleanValue;
            }
          }
        }
      }
      
      debugPrint('[RecipeDetailPage] Successfully parsed ${nutritionalMap.length} nutritional values');
      return nutritionalMap.isNotEmpty ? nutritionalMap : null;
    } catch (e) {
      debugPrint('[RecipeDetailPage] Error parsing nutritional values: $e');
      return null;
    }
  }

  // Helper method to build nutritional value cards
  Widget _buildNutritionalValuesSection() {
    if (_nutritionalValues == null || _nutritionalValues!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[800] 
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[600]! 
                  : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _nutritionalValues!.entries.map((entry) {
              // Format the display text properly
              String displayText;
              if (entry.key.toLowerCase().contains('kalori')) {
                displayText = 'Porsiyon başı kalori: ${entry.value}';
              } else {
                displayText = '${entry.key}: ${entry.value}';
              }
              
              return Text(
                displayText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white70 
                      : Colors.black87,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
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
                  Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(_imageUrl ?? widget.recipe['imageUrl'] ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTimeInfo(
                          Icons.timer_outlined,
                          'Hazırlık Süresi',
                          '${_prepTime ?? widget.recipe['prepTime'] ?? 0} dk',
                        ),
                        _buildTimeInfo(
                          Icons.restaurant,
                          'Pişirme Süresi',
                          '${_cookTime ?? widget.recipe['cookTime'] ?? 0} dk',
                        ),
                      ],
                    ),
                  ),

                  _buildNutritionalValuesSection(),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _title ?? widget.recipe['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Builder( // Used Builder to easily insert debugPrint before Text
                    builder: (context) {
                      final currentDisplayDescription = displayDescription;
                      debugPrint("[RecipeDetailPage] BUILDER: _description = $_description");
                      debugPrint("[RecipeDetailPage] BUILDER: widget.recipe['description'] = ${widget.recipe['description']}");
                      debugPrint("[RecipeDetailPage] BUILDER: displayDescription evaluates to = $currentDisplayDescription");
                      return Text(
                        currentDisplayDescription,
                        style: const TextStyle(fontSize: 16),
                      );
                    }
                  ),
                  
                  // YouTube Video Player
                  if (_youtubeVideoId != null && _isValidYouTubeVideoId(_youtubeVideoId)) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Video',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: WebViewWidget(
                          controller: WebViewController()
                            ..setJavaScriptMode(JavaScriptMode.unrestricted)
                            ..loadRequest(Uri.parse(
                              'https://www.youtube.com/embed/$_youtubeVideoId?autoplay=0&controls=1&showinfo=0&rel=0'
                            )),
                        ),
                      ),
                    ),
                  ],
                  
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
                ],
              ),
            ),
    );
  }

  Widget _buildTimeInfo(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final iconColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      children: [
        Icon(icon, size: 24, color: iconColor),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
