import 'dart:async';

import 'package:flutter/material.dart';
import '../models/food_model.dart';
import '../services/ml_food_recognition_service.dart';
import '../services/nutrition_db_helper.dart';
import 'food_confirmation_screen.dart';

class ManualFoodSearchScreen extends StatefulWidget {
  const ManualFoodSearchScreen({super.key});

  @override
  State<ManualFoodSearchScreen> createState() => _ManualFoodSearchScreenState();
}

class _ManualFoodSearchScreenState extends State<ManualFoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MLFoodRecognitionService _mlService = MLFoodRecognitionService();
  final NutritionDBHelper _nutritionDb = NutritionDBHelper.instance;

  List<FoodItem> _searchResults = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  List<String> _suggestions = [];
  final Map<String, Map<String, double>> _suggestionNutrition = {};
  int _suggestionRequestId = 0;
  Timer? _searchDebounce;
  bool _skipNextTextChange = false;

  @override
  void initState() {
    super.initState();
    _showSuggestions = true;
    _loadInitialSuggestions();
  }

  void _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSuggestions = true;
      });
      _updateSuggestions('');
      return;
    }

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    try {
      final localResults = await _searchDatabase(trimmed);
      final enhancedResults = <FoodItem>[];

      for (final result in localResults) {
        if (result.category == 'Custom') {
          enhancedResults.add(result);
          continue;
        }

        try {
          final nutrition = await _mlService.getNutrition(result.name);
          if (nutrition != null) {
            enhancedResults.add(FoodItem(
              id: result.id,
              name: nutrition.foodName,
              calories: nutrition.calories,
              protein: nutrition.protein,
              carbs: nutrition.carbohydrates,
              fat: nutrition.fat,
              category: 'Nutritionix API',
              nutritionalInfo: result.nutritionalInfo,
            ));
          } else {
            enhancedResults.add(result);
          }
        } catch (e, stackTrace) {
          print('Error getting nutrition for ${result.name}: $e');
          print(stackTrace);
          enhancedResults.add(result);
        }
      }

      setState(() {
        _searchResults = enhancedResults;
        _isSearching = false;
      });
    } catch (e, stackTrace) {
      print('Database search failed for "$trimmed": $e');
      print(stackTrace);
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showSuggestions = true;
      });
    }
  }

  Future<void> _loadInitialSuggestions() async {
    await _updateSuggestions('');
  }

  Future<void> _updateSuggestions(String rawQuery) async {
    final trimmed = rawQuery.trim();
    final requestId = ++_suggestionRequestId;

    try {
      final names = trimmed.isEmpty
          ? await _nutritionDb.getDefaultFoods(limit: 10)
          : await _nutritionDb.searchFoods(trimmed);

      if (!mounted || requestId != _suggestionRequestId) {
        return;
      }

      final limited = names.take(10).toList();

      final nutritionEntries = await Future.wait(
        limited.map(
          (name) async => MapEntry(name, await _nutritionDb.getNutrition(name)),
        ),
      );

      if (!mounted || requestId != _suggestionRequestId) {
        return;
      }

      final nutritionMap = <String, Map<String, double>>{};
      for (final entry in nutritionEntries) {
        final data = entry.value;
        if (data != null) {
          nutritionMap[entry.key] = data;
        }
      }

      setState(() {
        _suggestions = limited;
        _suggestionNutrition
          ..clear()
          ..addAll(nutritionMap);
      });
    } catch (e, stackTrace) {
      print('Suggestion update failed for "$rawQuery": $e');
      print(stackTrace);
    }
  }

  Future<List<FoodItem>> _searchDatabase(String query) async {
    final names = await _nutritionDb.searchFoods(query);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final nutritionEntries = await Future.wait(
      names.map(
        (name) async => MapEntry(name, await _nutritionDb.getNutrition(name)),
      ),
    );

    final results = <FoodItem>[];
    for (var i = 0; i < nutritionEntries.length; i++) {
      final entry = nutritionEntries[i];
      final nutrition = entry.value;
      if (nutrition == null) {
        continue;
      }

      results.add(FoodItem(
        id: '${timestamp}_$i',
        name: entry.key,
        calories: nutrition['calories'] ?? 0,
        protein: nutrition['protein'] ?? 0,
        carbs: nutrition['carbs'] ?? 0,
        fat: nutrition['fat'] ?? 0,
        category: 'SQLite Nutrition DB',
        nutritionalInfo: {
          'fiber': nutrition['fiber'] ?? 0,
        },
      ));
    }

    print('Local DB returned ${results.length} candidates for "$query"');

    final lowerQuery = query.toLowerCase();
    final hasExactMatch =
        results.any((item) => item.name.toLowerCase() == lowerQuery);
    if (!hasExactMatch) {
      results.add(FoodItem(
        id: '${timestamp}_custom',
        name: query,
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        category: 'Custom',
      ));
    }

    return results;
  }

  List<String> _getFilteredSuggestions() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      return _suggestions.take(10).toList();
    }

    return _suggestions
        .where((food) => food.toLowerCase().contains(query))
        .take(10)
        .toList();
  }

  void _selectFood(FoodItem food) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodConfirmationScreen(
          prefilledFood: food,
        ),
      ),
    ).then((result) {
      if (result == true) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Food'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for food items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                            _showSuggestions = true;
                          });
                          _updateSuggestions('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _searchDebounce?.cancel();
                if (_skipNextTextChange) {
                  _skipNextTextChange = false;
                  return;
                }
                _updateSuggestions(value);

                final trimmed = value.trim();
                if (trimmed.isEmpty) {
                  setState(() {
                    _searchResults = [];
                    _isSearching = false;
                    _showSuggestions = true;
                  });
                  return;
                }

                setState(() {
                  _showSuggestions = true;
                });

                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  if (!mounted) return;
                  _performSearch(value);
                });
              },
              onSubmitted: _performSearch,
            ),
          ),

          // Content area
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _showSuggestions
                    ? _buildSuggestionsView()
                    : _buildSearchResultsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsView() {
    final suggestions = _getFilteredSuggestions();

    if (suggestions.isEmpty) {
      return const Center(
        child: Text('No suggestions yet. Start typing to search.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_searchController.text.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Popular Foods',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        ...suggestions.map((food) {
          final nutrition = _suggestionNutrition[food];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.fastfood),
              title: Text(food),
              subtitle: nutrition != null
                  ? Text(
                      '${nutrition['calories']?.toStringAsFixed(0) ?? '0'} cal · '
                      '${nutrition['protein']?.toStringAsFixed(1) ?? '0.0'}g protein',
                    )
                  : null,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                FocusScope.of(context).unfocus();
                _searchDebounce?.cancel();
                _skipNextTextChange = true;
                _searchController.text = food;
                _performSearch(food);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSearchResultsView() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No results found'),
            SizedBox(height: 8),
            Text(
              'Try different keywords or add a custom entry',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final food = _searchResults[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: food.category == 'Custom'
                  ? Colors.orange
                  : Theme.of(context).primaryColor,
              child: Icon(
                food.category == 'Custom' ? Icons.add : Icons.fastfood,
                color: Colors.white,
              ),
            ),
            title: Text(food.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${food.calories.toInt()} cal · ${food.protein.toStringAsFixed(1)}g protein'),
                if (food.category != null)
                  Text(
                    food.category!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _selectFood(food),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
