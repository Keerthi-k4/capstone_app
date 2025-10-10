import 'package:flutter/material.dart';
import '../models/food_model.dart';
import '../services/ml_food_recognition_service.dart';
import 'food_confirmation_screen.dart';

class ManualFoodSearchScreen extends StatefulWidget {
  const ManualFoodSearchScreen({super.key});

  @override
  State<ManualFoodSearchScreen> createState() => _ManualFoodSearchScreenState();
}

class _ManualFoodSearchScreenState extends State<ManualFoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MLFoodRecognitionService _mlService = MLFoodRecognitionService();
  
  List<FoodItem> _searchResults = [];
  bool _isSearching = false;
  bool _showSuggestions = false;

  // Common food suggestions
  final List<String> _commonFoods = [
    'Apple', 'Banana', 'Orange', 'Rice', 'Chicken Breast', 'Salmon',
    'Broccoli', 'Spinach', 'Eggs', 'Milk', 'Bread', 'Pasta',
    'Pizza', 'Burger', 'Sandwich', 'Salad', 'Yogurt', 'Cheese',
    'Almonds', 'Avocado', 'Sweet Potato', 'Quinoa', 'Oatmeal',
    'Dosa', 'Idli', 'Chapati', 'Dal', 'Samosa', 'Biryani'
  ];

  // Basic nutrition data for common foods (calories per 100g)
  final Map<String, Map<String, double>> _basicNutritionData = {
    'Apple': {'calories': 52, 'protein': 0.3, 'carbs': 14, 'fat': 0.2},
    'Banana': {'calories': 89, 'protein': 1.1, 'carbs': 23, 'fat': 0.3},
    'Orange': {'calories': 47, 'protein': 0.9, 'carbs': 12, 'fat': 0.1},
    'Rice': {'calories': 130, 'protein': 2.7, 'carbs': 28, 'fat': 0.3},
    'Chicken Breast': {'calories': 165, 'protein': 31, 'carbs': 0, 'fat': 3.6},
    'Salmon': {'calories': 208, 'protein': 22, 'carbs': 0, 'fat': 13},
    'Broccoli': {'calories': 34, 'protein': 2.8, 'carbs': 7, 'fat': 0.4},
    'Spinach': {'calories': 23, 'protein': 2.9, 'carbs': 3.6, 'fat': 0.4},
    'Eggs': {'calories': 155, 'protein': 13, 'carbs': 1.1, 'fat': 11},
    'Milk': {'calories': 42, 'protein': 3.4, 'carbs': 5, 'fat': 1},
    'Bread': {'calories': 265, 'protein': 9, 'carbs': 49, 'fat': 3.2},
    'Pasta': {'calories': 131, 'protein': 5, 'carbs': 25, 'fat': 1.1},
    'Pizza': {'calories': 285, 'protein': 12, 'carbs': 36, 'fat': 10},
    'Burger': {'calories': 295, 'protein': 15, 'carbs': 30, 'fat': 14},
    'Sandwich': {'calories': 250, 'protein': 12, 'carbs': 30, 'fat': 9},
    'Salad': {'calories': 20, 'protein': 1.5, 'carbs': 4, 'fat': 0.2},
    'Yogurt': {'calories': 59, 'protein': 10, 'carbs': 3.6, 'fat': 0.4},
    'Cheese': {'calories': 113, 'protein': 7, 'carbs': 1, 'fat': 9},
    'Almonds': {'calories': 579, 'protein': 21, 'carbs': 22, 'fat': 50},
    'Avocado': {'calories': 160, 'protein': 2, 'carbs': 9, 'fat': 15},
    'Dosa': {'calories': 168, 'protein': 4, 'carbs': 25, 'fat': 6},
    'Idli': {'calories': 58, 'protein': 2, 'carbs': 8, 'fat': 2},
    'Chapati': {'calories': 297, 'protein': 11, 'carbs': 51, 'fat': 7},
    'Dal': {'calories': 116, 'protein': 9, 'carbs': 20, 'fat': 0.4},
    'Samosa': {'calories': 262, 'protein': 6, 'carbs': 24, 'fat': 16},
    'Biryani': {'calories': 200, 'protein': 8, 'carbs': 35, 'fat': 4},
  };

  @override
  void initState() {
    super.initState();
    _showSuggestions = true;
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSuggestions = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    // First, search locally
    final localResults = _searchLocally(query);
    
    // Try to get nutrition data from ML service
    final enhancedResults = <FoodItem>[];
    
    for (final result in localResults) {
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
          ));
        } else {
          enhancedResults.add(result);
        }
      } catch (e) {
        print('Error getting nutrition for ${result.name}: $e');
        enhancedResults.add(result);
      }
    }

    setState(() {
      _searchResults = enhancedResults;
      _isSearching = false;
    });
  }

  List<FoodItem> _searchLocally(String query) {
    final results = <FoodItem>[];
    final lowerQuery = query.toLowerCase();

    // Search in common foods
    for (final food in _commonFoods) {
      if (food.toLowerCase().contains(lowerQuery)) {
        final nutrition = _basicNutritionData[food];
        if (nutrition != null) {
          results.add(FoodItem(
            id: DateTime.now().millisecondsSinceEpoch.toString() + food,
            name: food,
            calories: nutrition['calories'] ?? 0,
            protein: nutrition['protein'] ?? 0,
            carbs: nutrition['carbs'] ?? 0,
            fat: nutrition['fat'] ?? 0,
            category: 'Common Foods',
          ));
        }
      }
    }

    // Add a generic option for the exact search
    if (!results.any((f) => f.name.toLowerCase() == lowerQuery)) {
      results.add(FoodItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + 'custom',
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
    if (_searchController.text.isEmpty) {
      return _commonFoods.take(10).toList();
    }
    
    final query = _searchController.text.toLowerCase();
    return _commonFoods
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
                            _showSuggestions = true;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                if (value.isNotEmpty) {
                  _performSearch(value);
                } else {
                  setState(() {
                    _searchResults = [];
                    _showSuggestions = true;
                  });
                }
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
        ...suggestions.map((food) => Card(
          child: ListTile(
            leading: const Icon(Icons.fastfood),
            title: Text(food),
            subtitle: _basicNutritionData.containsKey(food)
                ? Text('${_basicNutritionData[food]!['calories']!.toInt()} cal per 100g')
                : null,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _searchController.text = food;
              _performSearch(food);
            },
          ),
        )),
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
                Text('${food.calories.toInt()} cal · ${food.protein.toStringAsFixed(1)}g protein'),
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
    _searchController.dispose();
    super.dispose();
  }
}
