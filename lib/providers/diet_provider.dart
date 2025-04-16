import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:attempt2/models/food_model.dart';
import 'package:flutter/foundation.dart';

/// Provider that manages diet-related data
class DietProvider with ChangeNotifier {
  List<FoodItem> _foods = [];
  List<Meal> _meals = [];
  List<DietPlan> _dietPlans = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<FoodItem> get foods => _foods;
  List<Meal> get meals => _meals;
  List<DietPlan> get dietPlans => _dietPlans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Constructor
  DietProvider() {
    _loadData();
  }

  /// Load data from shared preferences
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load foods
      final foodsJson = prefs.getString('foods_data');
      if (foodsJson != null) {
        final List<dynamic> decodedFoods = jsonDecode(foodsJson);
        _foods = decodedFoods.map((food) => FoodItem.fromJson(food)).toList();
      }

      // Load meals
      final mealsJson = prefs.getString('meals_data');
      if (mealsJson != null) {
        final List<dynamic> decodedMeals = jsonDecode(mealsJson);
        _meals = decodedMeals.map((meal) => Meal.fromJson(meal)).toList();
      }

      // Load diet plans
      final plansJson = prefs.getString('diet_plans_data');
      if (plansJson != null) {
        final List<dynamic> decodedPlans = jsonDecode(plansJson);
        _dietPlans =
            decodedPlans.map((plan) => DietPlan.fromJson(plan)).toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = "Failed to load diet data: $e";
      _isLoading = false;
      notifyListeners();
      print(_error);
    }
  }

  /// Save data to shared preferences
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save foods
      final foodsJson = jsonEncode(
        _foods.map((food) => food.toJson()).toList(),
      );
      await prefs.setString('foods_data', foodsJson);

      // Save meals
      final mealsJson = jsonEncode(
        _meals.map((meal) => meal.toJson()).toList(),
      );
      await prefs.setString('meals_data', mealsJson);

      // Save diet plans
      final plansJson = jsonEncode(
        _dietPlans.map((plan) => plan.toJson()).toList(),
      );
      await prefs.setString('diet_plans_data', plansJson);
    } catch (e) {
      _error = "Failed to save diet data: $e";
      print(_error);
    }
  }

  /// Add a new food item
  Future<void> addFood(FoodItem food) async {
    _foods.add(food);
    await _saveData();
    notifyListeners();
  }

  /// Update an existing food item
  Future<void> updateFood(FoodItem updatedFood) async {
    final index = _foods.indexWhere((food) => food.id == updatedFood.id);
    if (index != -1) {
      _foods[index] = updatedFood;
      await _saveData();
      notifyListeners();
    }
  }

  /// Delete a food item
  Future<void> deleteFood(String foodId) async {
    _foods.removeWhere((food) => food.id == foodId);
    await _saveData();
    notifyListeners();
  }

  /// Toggle favorite status of a food item
  Future<void> toggleFavorite(String foodId) async {
    final index = _foods.indexWhere((food) => food.id == foodId);
    if (index != -1) {
      final food = _foods[index];
      _foods[index] = food.copyWith(isFavorite: !food.isFavorite);
      await _saveData();
      notifyListeners();
    }
  }

  /// Get favorite foods
  List<FoodItem> get favoriteFoods =>
      _foods.where((food) => food.isFavorite).toList();

  /// Add a new meal
  Future<void> addMeal(Meal meal) async {
    _meals.add(meal);
    await _saveData();
    notifyListeners();
  }

  /// Update an existing meal
  Future<void> updateMeal(Meal updatedMeal) async {
    final index = _meals.indexWhere((meal) => meal.id == updatedMeal.id);
    if (index != -1) {
      _meals[index] = updatedMeal;
      await _saveData();
      notifyListeners();
    }
  }

  /// Delete a meal
  Future<void> deleteMeal(String mealId) async {
    _meals.removeWhere((meal) => meal.id == mealId);
    await _saveData();
    notifyListeners();
  }

  /// Get meals for a specific date
  List<Meal> getMealsForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _meals.where((meal) {
      final mealDate = DateTime(
        meal.dateTime.year,
        meal.dateTime.month,
        meal.dateTime.day,
      );
      return mealDate.isAtSameMomentAs(dateOnly);
    }).toList();
  }

  /// Get meals by type for a specific date
  List<Meal> getMealsByTypeForDate(DateTime date, String type) {
    return getMealsForDate(date).where((meal) => meal.type == type).toList();
  }

  /// Add a new diet plan
  Future<void> addDietPlan(DietPlan plan) async {
    _dietPlans.add(plan);
    await _saveData();
    notifyListeners();
  }

  /// Update an existing diet plan
  Future<void> updateDietPlan(DietPlan updatedPlan) async {
    final index = _dietPlans.indexWhere((plan) => plan.id == updatedPlan.id);
    if (index != -1) {
      _dietPlans[index] = updatedPlan;
      await _saveData();
      notifyListeners();
    }
  }

  /// Delete a diet plan
  Future<void> deleteDietPlan(String planId) async {
    _dietPlans.removeWhere((plan) => plan.id == planId);
    await _saveData();
    notifyListeners();
  }

  /// Get active diet plans (current date falls within plan date range)
  List<DietPlan> get activeDietPlans {
    final now = DateTime.now();
    return _dietPlans.where((plan) {
      final isAfterStart =
          now.isAfter(plan.startDate) || now.isAtSameMomentAs(plan.startDate);
      final isBeforeEnd = plan.endDate == null || now.isBefore(plan.endDate!);
      return isAfterStart && isBeforeEnd;
    }).toList();
  }

  /// Get diet plans for a specific user
  List<DietPlan> getDietPlansForUser(String userId) {
    return _dietPlans.where((plan) => plan.userId == userId).toList();
  }

  /// Calculate total nutrition for a specific date
  Map<String, double> calculateNutritionForDate(DateTime date) {
    final meals = getMealsForDate(date);

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final meal in meals) {
      totalCalories += meal.totalCalories;
      totalProtein += meal.totalProtein;
      totalCarbs += meal.totalCarbs;
      totalFat += meal.totalFat;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  /// Search foods by name
  List<FoodItem> searchFoods(String query) {
    if (query.isEmpty) return _foods;

    final lowercaseQuery = query.toLowerCase();
    return _foods
        .where(
          (food) =>
              food.name.toLowerCase().contains(lowercaseQuery) ||
              (food.category?.toLowerCase().contains(lowercaseQuery) ?? false),
        )
        .toList();
  }

  /// Create sample data for testing
  void createSampleData(String userId) {
    // Sample foods
    final foods = [
      FoodItem(
        id: const Uuid().v4(),
        name: 'Chicken Breast',
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 3.6,
        category: 'Protein',
        servingSize: '100g',
      ),
      FoodItem(
        id: const Uuid().v4(),
        name: 'Brown Rice',
        calories: 112,
        protein: 2.6,
        carbs: 23.5,
        fat: 0.9,
        category: 'Carbs',
        servingSize: '100g',
      ),
      FoodItem(
        id: const Uuid().v4(),
        name: 'Broccoli',
        calories: 34,
        protein: 2.8,
        carbs: 6.6,
        fat: 0.4,
        category: 'Vegetables',
        servingSize: '100g',
      ),
      FoodItem(
        id: const Uuid().v4(),
        name: 'Salmon',
        calories: 208,
        protein: 20,
        carbs: 0,
        fat: 13,
        category: 'Protein',
        servingSize: '100g',
      ),
      FoodItem(
        id: const Uuid().v4(),
        name: 'Avocado',
        calories: 160,
        protein: 2,
        carbs: 8.5,
        fat: 14.7,
        category: 'Fats',
        servingSize: '100g',
      ),
    ];

    _foods = foods;

    // Sample meals for today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final breakfast = Meal(
      id: const Uuid().v4(),
      name: 'Breakfast',
      dateTime: DateTime(today.year, today.month, today.day, 8, 0),
      type: 'Breakfast',
      foodItems: [
        MealFoodItem(
          foodItem: foods[1], // Brown Rice
          quantity: 0.5,
          servingType: 'cup',
        ),
        MealFoodItem(
          foodItem: foods[4], // Avocado
          quantity: 0.5,
          servingType: 'piece',
        ),
      ],
    );

    final lunch = Meal(
      id: const Uuid().v4(),
      name: 'Lunch',
      dateTime: DateTime(today.year, today.month, today.day, 13, 0),
      type: 'Lunch',
      foodItems: [
        MealFoodItem(
          foodItem: foods[0], // Chicken Breast
          quantity: 1,
          servingType: 'piece',
        ),
        MealFoodItem(
          foodItem: foods[2], // Broccoli
          quantity: 1,
          servingType: 'cup',
        ),
      ],
    );

    final dinner = Meal(
      id: const Uuid().v4(),
      name: 'Dinner',
      dateTime: DateTime(today.year, today.month, today.day, 19, 0),
      type: 'Dinner',
      foodItems: [
        MealFoodItem(
          foodItem: foods[3], // Salmon
          quantity: 1,
          servingType: 'fillet',
        ),
        MealFoodItem(
          foodItem: foods[2], // Broccoli
          quantity: 1,
          servingType: 'cup',
        ),
      ],
    );

    _meals = [breakfast, lunch, dinner];

    // Sample diet plan
    final dietPlan = DietPlan(
      id: const Uuid().v4(),
      name: 'Balanced Diet Plan',
      userId: userId,
      startDate: today,
      endDate: today.add(const Duration(days: 7)),
      meals: _meals,
      nutritionalGoals: {
        'calories': 2000,
        'protein': 150,
        'carbs': 200,
        'fat': 70,
      },
    );

    _dietPlans = [dietPlan];

    _saveData();
    notifyListeners();
  }
}
