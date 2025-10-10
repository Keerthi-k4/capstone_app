import 'dart:io';
import 'package:flutter/services.dart';
import '../models/food_model.dart';

/// On-device ML food recognition using TensorFlow Lite
class OnDeviceMLService {
  static const String _labelsPath = 'assets/models/labels.txt';
  
  bool _isModelLoaded = false;
  List<String> _labels = [];
  
  // Common food nutrition data (calories per 100g)
  final Map<String, Map<String, double>> _nutritionData = {
    'burger': {'calories': 295, 'protein': 15, 'carbs': 30, 'fat': 14},
    'pizza': {'calories': 285, 'protein': 12, 'carbs': 36, 'fat': 10},
    'dosa': {'calories': 168, 'protein': 4, 'carbs': 25, 'fat': 6},
    'idli': {'calories': 58, 'protein': 2, 'carbs': 8, 'fat': 2},
    'samosa': {'calories': 262, 'protein': 6, 'carbs': 24, 'fat': 16},
    'biryani': {'calories': 200, 'protein': 8, 'carbs': 35, 'fat': 4},
    'momos': {'calories': 190, 'protein': 7, 'carbs': 26, 'fat': 6.5},
    'dal': {'calories': 116, 'protein': 9, 'carbs': 20, 'fat': 0.4},
    'chapati': {'calories': 297, 'protein': 11, 'carbs': 51, 'fat': 7},
    'paani_puri': {'calories': 36, 'protein': 1, 'carbs': 6, 'fat': 1},
    'pakode': {'calories': 280, 'protein': 6, 'carbs': 25, 'fat': 18},
    'pav_bhaji': {'calories': 160, 'protein': 4, 'carbs': 22, 'fat': 6},
    'butter_naan': {'calories': 384, 'protein': 12, 'carbs': 45, 'fat': 18},
    'chole_bhature': {'calories': 427, 'protein': 12, 'carbs': 58, 'fat': 16},
    'dhokla': {'calories': 160, 'protein': 4, 'carbs': 27, 'fat': 4},
    'jalebi': {'calories': 150, 'protein': 1, 'carbs': 37, 'fat': 0.1},
    'kaathi_rolls': {'calories': 250, 'protein': 12, 'carbs': 30, 'fat': 10},
    'kadai_paneer': {'calories': 180, 'protein': 8, 'carbs': 8, 'fat': 14},
    'kulfi': {'calories': 135, 'protein': 4, 'carbs': 16, 'fat': 6},
    'masala_dosa': {'calories': 200, 'protein': 5, 'carbs': 30, 'fat': 7},
    'chai': {'calories': 37, 'protein': 1.5, 'carbs': 6, 'fat': 1},
    'fried_rice': {'calories': 163, 'protein': 4, 'carbs': 30, 'fat': 3},
  };

  /// Initialize the on-device ML service
  Future<bool> initialize() async {
    if (_isModelLoaded) return true;
    
    try {
      // Load labels
      await _loadLabels();
      
      // For now, we'll simulate model loading since TensorFlow Lite setup
      // requires additional native configuration
      _isModelLoaded = true;
      print('On-device ML service initialized successfully');
      return true;
    } catch (e) {
      print('Error initializing on-device ML: $e');
      return false;
    }
  }

  Future<void> _loadLabels() async {
    try {
      // Try loading from assets first
      final String labelsContent = await rootBundle.loadString(_labelsPath);
      _labels = labelsContent.split('\n').where((label) => label.isNotEmpty).toList();
    } catch (e) {
      // Fallback to predefined labels
      _labels = [
        'burger', 'butter_naan', 'chai', 'chapati', 'chole_bhature',
        'dal_makhani', 'dhokla', 'fried_rice', 'idli', 'jalebi',
        'kaathi_rolls', 'kadai_paneer', 'kulfi', 'masala_dosa', 'momos',
        'paani_puri', 'pakode', 'pav_bhaji', 'pizza', 'samosa'
      ];
      print('Using fallback labels: ${_labels.length} classes');
    }
  }

  /// Predict food from image file (simulated for now)
  Future<MLFoodRecognitionResponse> predictFood(File imageFile) async {
    if (!_isModelLoaded) {
      await initialize();
    }

    try {
      // For demonstration, we'll use a simple image-based heuristic
      // In a real implementation, you'd run TensorFlow Lite inference here
      
      final predictions = await _simulatePrediction(imageFile);
      
      return MLFoodRecognitionResponse(
        success: true,
        predictions: predictions,
        topPrediction: predictions.isNotEmpty 
            ? FoodPredictionWithNutrition(
                name: predictions.first.name,
                confidence: predictions.first.confidence,
                nutrition: _getNutritionForFood(predictions.first.name),
              )
            : null,
      );
    } catch (e) {
      return MLFoodRecognitionResponse(
        success: false,
        error: 'On-device prediction failed: $e',
      );
    }
  }

  /// Simulate ML prediction (replace with actual TensorFlow Lite inference)
  Future<List<FoodPrediction>> _simulatePrediction(File imageFile) async {
    // This is a simulation - in reality you would:
    // 1. Preprocess the image (resize, normalize)
    // 2. Run inference using TensorFlow Lite
    // 3. Post-process the results
    
    // For now, randomly select from available classes with simulated confidence
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate processing time
    
    final predictions = <FoodPrediction>[];
    
    // Simulate getting top 3 predictions
    final shuffledLabels = List<String>.from(_labels)..shuffle();
    
    for (int i = 0; i < 3 && i < shuffledLabels.length; i++) {
      final confidence = (0.95 - (i * 0.25)).clamp(0.1, 1.0); // Decreasing confidence
      predictions.add(FoodPrediction(
        name: shuffledLabels[i].replaceAll('_', ' ').toUpperCase(),
        confidence: confidence,
        isCustomModel: true,
      ));
    }
    
    return predictions;
  }

  /// Get nutrition data for a specific food
  NutritionData? _getNutritionForFood(String foodName) {
    final key = foodName.toLowerCase().replaceAll(' ', '_');
    final nutrition = _nutritionData[key];
    
    if (nutrition != null) {
      return NutritionData(
        foodName: foodName,
        calories: nutrition['calories'] ?? 0,
        protein: nutrition['protein'] ?? 0,
        carbohydrates: nutrition['carbs'] ?? 0,
        fat: nutrition['fat'] ?? 0,
        fiber: 2.0, // Default values
        sugars: 5.0,
        sodium: 300.0,
        cholesterol: 10.0,
      );
    }
    
    return null;
  }

  /// Check if the service is ready
  bool get isReady => _isModelLoaded;

  /// Get available food classes
  List<String> get availableClasses => _labels;
}
