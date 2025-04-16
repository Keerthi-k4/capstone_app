/// Model class for food items
class FoodItem {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? imageUrl;
  final Map<String, dynamic>? nutritionalInfo;
  final String? servingSize;
  final String? category;
  final bool isFavorite;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.imageUrl,
    this.nutritionalInfo,
    this.servingSize,
    this.category,
    this.isFavorite = false,
  });

  FoodItem copyWith({
    String? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? imageUrl,
    Map<String, dynamic>? nutritionalInfo,
    String? servingSize,
    String? category,
    bool? isFavorite,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      imageUrl: imageUrl ?? this.imageUrl,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      servingSize: servingSize ?? this.servingSize,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'imageUrl': imageUrl,
      'nutritionalInfo': nutritionalInfo,
      'servingSize': servingSize,
      'category': category,
      'isFavorite': isFavorite,
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'],
      name: json['name'],
      calories: json['calories']?.toDouble() ?? 0,
      protein: json['protein']?.toDouble() ?? 0,
      carbs: json['carbs']?.toDouble() ?? 0,
      fat: json['fat']?.toDouble() ?? 0,
      imageUrl: json['imageUrl'],
      nutritionalInfo: json['nutritionalInfo'],
      servingSize: json['servingSize'],
      category: json['category'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}

/// Model for a meal (breakfast, lunch, dinner, etc.)
class Meal {
  final String id;
  final String name;
  final DateTime dateTime;
  final List<MealFoodItem> foodItems;
  final String? notes;
  final String type; // breakfast, lunch, dinner, snack

  Meal({
    required this.id,
    required this.name,
    required this.dateTime,
    required this.foodItems,
    required this.type,
    this.notes,
  });

  // Get total nutritional information
  double get totalCalories => foodItems.fold(
    0,
    (sum, item) => sum + (item.foodItem.calories * item.quantity),
  );
  double get totalProtein => foodItems.fold(
    0,
    (sum, item) => sum + (item.foodItem.protein * item.quantity),
  );
  double get totalCarbs => foodItems.fold(
    0,
    (sum, item) => sum + (item.foodItem.carbs * item.quantity),
  );
  double get totalFat => foodItems.fold(
    0,
    (sum, item) => sum + (item.foodItem.fat * item.quantity),
  );

  Meal copyWith({
    String? id,
    String? name,
    DateTime? dateTime,
    List<MealFoodItem>? foodItems,
    String? notes,
    String? type,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
      foodItems: foodItems ?? this.foodItems,
      notes: notes ?? this.notes,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dateTime': dateTime.toIso8601String(),
      'foodItems': foodItems.map((item) => item.toJson()).toList(),
      'notes': notes,
      'type': type,
    };
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'],
      name: json['name'],
      dateTime: DateTime.parse(json['dateTime']),
      foodItems:
          (json['foodItems'] as List)
              .map((item) => MealFoodItem.fromJson(item))
              .toList(),
      notes: json['notes'],
      type: json['type'],
    );
  }
}

/// Represents a food item in a meal with quantity
class MealFoodItem {
  final FoodItem foodItem;
  final double quantity;
  final String servingType;

  MealFoodItem({
    required this.foodItem,
    required this.quantity,
    required this.servingType,
  });

  Map<String, dynamic> toJson() {
    return {
      'foodItem': foodItem.toJson(),
      'quantity': quantity,
      'servingType': servingType,
    };
  }

  factory MealFoodItem.fromJson(Map<String, dynamic> json) {
    return MealFoodItem(
      foodItem: FoodItem.fromJson(json['foodItem']),
      quantity: json['quantity']?.toDouble() ?? 0,
      servingType: json['servingType'],
    );
  }
}

/// Model for a diet plan (collection of meals for a day or multiple days)
class DietPlan {
  final String id;
  final String name;
  final String userId;
  final List<Meal> meals;
  final DateTime startDate;
  final DateTime? endDate;
  final Map<String, double> nutritionalGoals;
  final String? notes;

  DietPlan({
    required this.id,
    required this.name,
    required this.userId,
    required this.meals,
    required this.startDate,
    this.endDate,
    required this.nutritionalGoals,
    this.notes,
  });

  // Get total nutritional information
  double get totalCalories =>
      meals.fold(0, (sum, meal) => sum + meal.totalCalories);
  double get totalProtein =>
      meals.fold(0, (sum, meal) => sum + meal.totalProtein);
  double get totalCarbs => meals.fold(0, (sum, meal) => sum + meal.totalCarbs);
  double get totalFat => meals.fold(0, (sum, meal) => sum + meal.totalFat);

  DietPlan copyWith({
    String? id,
    String? name,
    String? userId,
    List<Meal>? meals,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, double>? nutritionalGoals,
    String? notes,
  }) {
    return DietPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      meals: meals ?? this.meals,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nutritionalGoals: nutritionalGoals ?? this.nutritionalGoals,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'meals': meals.map((meal) => meal.toJson()).toList(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'nutritionalGoals': nutritionalGoals,
      'notes': notes,
    };
  }

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    return DietPlan(
      id: json['id'],
      name: json['name'],
      userId: json['userId'],
      meals:
          (json['meals'] as List).map((meal) => Meal.fromJson(meal)).toList(),
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      nutritionalGoals: Map<String, double>.from(json['nutritionalGoals']),
      notes: json['notes'],
    );
  }
}
