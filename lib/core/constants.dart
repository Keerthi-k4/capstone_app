import 'package:flutter/material.dart';

/// App-wide constants for the Diet Fitness app
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // API keys and endpoints
  static const String appName = "Diet Fitness Planner";

  // Shared Preferences Keys
  static const String userPrefsKey = "user_data";
  static const String themePrefsKey = "app_theme";
  static const String onboardingCompleteKey = "onboarding_complete";

  // Nutrition API constants
  static const String nutritionApiBaseUrl = "https://api.example.com/nutrition";

  // Workout-related constants
  static const List<String> workoutCategories = [
    "Cardio",
    "Strength",
    "Flexibility",
    "Balance",
    "HIIT",
  ];

  // Diet-related constants
  static const List<String> mealTypes = [
    "Breakfast",
    "Morning Snack",
    "Lunch",
    "Afternoon Snack",
    "Dinner",
    "Evening Snack",
  ];

  // Colors
  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color secondaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF43A047);

  // Animations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 500);
  static const Duration longAnimationDuration = Duration(milliseconds: 800);

  // Default UI values
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultSpacing = 8.0;
}

// App-wide constants

// API endpoints
class ApiConstants {
  static const String baseUrl = 'https://api.example.com';
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
}

// Route names
class RouteNames {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String dietPlan = '/diet-plan';
  static const String mealTracker = '/meal-tracker';
  static const String exerciseTracker = '/exercise-tracker';
}

// Asset paths
class AssetPaths {
  static const String logo = 'assets/images/logo.png';
  static const String placeholder = 'assets/images/placeholder.png';
}

// Shared preference keys
class PreferenceKeys {
  static const String userData = 'user_data';
  static const String foodsData = 'foods_data';
  static const String mealsData = 'meals_data';
  static const String dietPlansData = 'diet_plans_data';
  static const String token = 'auth_token';
  static const String onboardingCompleted = 'onboarding_completed';
}

// App strings
class AppStrings {
  static const String appName = 'Diet & Fitness App';
  static const String welcomeMessage = 'Welcome to Diet & Fitness App!';
  static const String signIn = 'Sign In';
  static const String signUp = 'Sign Up';
  static const String emailHint = 'Email';
  static const String passwordHint = 'Password';
  static const String nameHint = 'Full Name';
  static const String logout = 'Logout';
}

// Error messages
class ErrorMessages {
  static const String genericError = 'Something went wrong, please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String invalidCredentials = 'Invalid email or password.';
  static const String emailAlreadyInUse = 'Email is already in use.';
  static const String weakPassword = 'Password is too weak.';
  static const String invalidEmail = 'Invalid email address.';
}

// Validation rules
class ValidationRules {
  static const int minPasswordLength = 6;
  static const int minNameLength = 2;
  static const Pattern emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
}
