import 'dart:convert';

/// Model class representing a user in the app
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final int? age;
  final double? weight;
  final double? height;
  final String? gender;
  final DateTime? createdAt;
  final Map<String, dynamic>? healthMetrics;
  // New fields
  final String? activityLevel; // 'sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extremely_active'
  final double? targetWeight;
  final String? medicalConcerns;
  final bool useWatchDataForTDEE; // If true, use watch data; if false, use calculated TDEE

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.age,
    this.weight,
    this.height,
    this.gender,
    this.createdAt,
    this.healthMetrics,
    this.activityLevel,
    this.targetWeight,
    this.medicalConcerns,
    this.useWatchDataForTDEE = false,
  });

  /// Calculate BMI if weight and height are available
  double? get bmi {
    if (weight != null && height != null && height! > 0) {
      // BMI = weight(kg) / (height(m))²
      final heightInMeters = height! / 100;
      return weight! / (heightInMeters * heightInMeters);
    }
    return null;
  }

  /// Get BMI category
  String get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return 'Not available';

    if (bmiValue < 18.5) {
      return 'Underweight';
    } else if (bmiValue >= 18.5 && bmiValue < 25) {
      return 'Normal weight';
    } else if (bmiValue >= 25 && bmiValue < 30) {
      return 'Overweight';
    } else {
      return 'Obesity';
    }
  }

  /// Calculate Basal Metabolic Rate (BMR) using Mifflin-St Jeor Equation
  /// BMR is the number of calories your body needs at rest
  double? calculateBMR() {
    if (weight == null || height == null || age == null || gender == null) {
      return null;
    }

    if (gender!.toLowerCase() == 'male') {
      // Male: BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age + 5
      return 10 * weight! + 6.25 * height! - 5 * age! + 5;
    } else {
      // Female: BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age - 161
      return 10 * weight! + 6.25 * height! - 5 * age! - 161;
    }
  }

  /// Get activity multiplier based on activity level
  double getActivityMultiplier() {
    switch (activityLevel?.toLowerCase()) {
      case 'sedentary':
        return 1.2; // Little or no exercise
      case 'lightly_active':
        return 1.375; // Light exercise 1-3 days/week
      case 'moderately_active':
        return 1.55; // Moderate exercise 3-5 days/week
      case 'very_active':
        return 1.725; // Hard exercise 6-7 days/week
      case 'extremely_active':
        return 1.9; // Very hard exercise & physical job
      default:
        return 1.55; // Default to moderately active
    }
  }

  /// Calculate Total Daily Energy Expenditure (TDEE)
  /// TDEE is the total calories you burn per day including activity
  double? calculateTDEE() {
    final bmr = calculateBMR();
    if (bmr == null) return null;
    
    return bmr * getActivityMultiplier();
  }

  /// Calculate daily calorie needs based on user data
  /// Using the Mifflin-St Jeor Equation with activity level
  /// This is kept for backward compatibility
  double? get dailyCalorieNeeds {
    return calculateTDEE();
  }

  /// Create a copy of this user with modified fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    int? age,
    double? weight,
    double? height,
    String? gender,
    DateTime? createdAt,
    Map<String, dynamic>? healthMetrics,
    String? activityLevel,
    double? targetWeight,
    String? medicalConcerns,
    bool? useWatchDataForTDEE,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      healthMetrics: healthMetrics ?? this.healthMetrics,
      activityLevel: activityLevel ?? this.activityLevel,
      targetWeight: targetWeight ?? this.targetWeight,
      medicalConcerns: medicalConcerns ?? this.medicalConcerns,
      useWatchDataForTDEE: useWatchDataForTDEE ?? this.useWatchDataForTDEE,
    );
  }

  /// Convert user model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'createdAt': createdAt?.toIso8601String(),
      'healthMetrics': healthMetrics,
      'activityLevel': activityLevel,
      'targetWeight': targetWeight,
      'medicalConcerns': medicalConcerns,
      'useWatchDataForTDEE': useWatchDataForTDEE,
    };
  }

  /// Create user model from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      photoUrl: json['photoUrl'],
      age: json['age'],
      weight: json['weight']?.toDouble(),
      height: json['height']?.toDouble(),
      gender: json['gender'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      healthMetrics: json['healthMetrics'],
      activityLevel: json['activityLevel'],
      targetWeight: json['targetWeight']?.toDouble(),
      medicalConcerns: json['medicalConcerns'],
      useWatchDataForTDEE: json['useWatchDataForTDEE'] ?? false,
    );
  }

  /// For SharedPreferences storage
  String toJsonString() => jsonEncode(toJson());

  /// Create from SharedPreferences stored string
  factory UserModel.fromJsonString(String jsonString) {
    return UserModel.fromJson(jsonDecode(jsonString));
  }
}
