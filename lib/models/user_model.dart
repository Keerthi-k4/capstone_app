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

  /// Calculate daily calorie needs based on user data
  /// Using the Mifflin-St Jeor Equation
  double? get dailyCalorieNeeds {
    if (weight == null || height == null || age == null || gender == null) {
      return null;
    }

    // Base calculation
    double bmr;
    if (gender!.toLowerCase() == 'male') {
      bmr = 10 * weight! + 6.25 * height! - 5 * age! + 5;
    } else {
      bmr = 10 * weight! + 6.25 * height! - 5 * age! - 161;
    }

    // Assuming moderate activity level (multiplier of 1.55)
    return bmr * 1.55;
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
      weight: json['weight'],
      height: json['height'],
      gender: json['gender'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      healthMetrics: json['healthMetrics'],
    );
  }

  /// For SharedPreferences storage
  String toJsonString() => jsonEncode(toJson());

  /// Create from SharedPreferences stored string
  factory UserModel.fromJsonString(String jsonString) {
    return UserModel.fromJson(jsonDecode(jsonString));
  }
}
