import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/food_model.dart';

/// Service for communicating with the ML Food Recognition API
class MLFoodRecognitionService {
  static const List<String> _serverUrls = [
    'http://127.0.0.1:5000',
    'http://localhost:5000',
    'http://192.168.29.51:5000',
  ];
  late final Dio _dio;
  String? _workingUrl;

  MLFoodRecognitionService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Check if the ML API server is running
  Future<bool> isServerHealthy() async {
    for (final url in _serverUrls) {
      try {
        print('Checking server health at: $url');
        _dio.options.baseUrl = url;
        final response = await _dio.get('/health');
        
        if (response.data['status'] == 'healthy') {
          _workingUrl = url;
          print('? Server healthy at: $url');
          return true;
        }
      } catch (e) {
        print('? Server check failed at $url: $e');
        continue;
      }
    }
    
    print('? No healthy servers found');
    return false;
  }

  /// Predict food from image file
  Future<MLFoodRecognitionResponse> predictFood(File imageFile) async {
    try {
      // Ensure we have a working server URL
      if (_workingUrl == null) {
        final isHealthy = await isServerHealthy();
        if (!isHealthy) {
          return MLFoodRecognitionResponse(
            success: false,
            error: 'No healthy ML server found',
          );
        }
      }

      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _dio.post(
        '/predict',
        data: {
          'image': base64Image,
        },
      );

      return MLFoodRecognitionResponse.fromJson(response.data);
    } catch (e) {
      print('Error predicting food: $e');
      return MLFoodRecognitionResponse(
        success: false,
        error: 'Failed to predict food: ${e.toString()}',
      );
    }
  }

  /// Get nutrition information for a food item
  Future<NutritionData?> getNutrition(String foodName) async {
    try {
      // Ensure we have a working server URL
      if (_workingUrl == null) {
        final isHealthy = await isServerHealthy();
        if (!isHealthy) {
          print('No healthy server for nutrition lookup');
          return null;
        }
      }

      final response = await _dio.post(
        '/nutrition',
        data: {
          'food_name': foodName,
          'quantity': 100, // Default to 100g
        },
      );

      if (response.data['success'] == true) {
        final nutrition = response.data['nutrition'];
        return NutritionData(
          foodName: nutrition['food_name'] ?? foodName,
          calories: (nutrition['energy_kcal'] ?? 0).toDouble(),
          protein: (nutrition['protein_g'] ?? 0).toDouble(),
          carbohydrates: (nutrition['carbohydrate_g'] ?? 0).toDouble(),
          fat: (nutrition['fat_g'] ?? 0).toDouble(),
          fiber: (nutrition['fibre_g'] ?? 0).toDouble(),
          sugars: (nutrition['sugars_g'] ?? 0).toDouble(),
          sodium: (nutrition['sodium_mg'] ?? 0).toDouble(),
          cholesterol: (nutrition['cholesterol_mg'] ?? 0).toDouble(),
        );
      }

      return null;
    } catch (e) {
      print('Error getting nutrition: $e');
      return null;
    }
  }

  /// Get nutrition information for a food item (alternative method name for compatibility)
  Future<NutritionData?> getNutritionInfo(String foodName, {double quantity = 100}) async {
    try {
      // Ensure we have a working server URL
      if (_workingUrl == null) {
        final isHealthy = await isServerHealthy();
        if (!isHealthy) {
          print('No healthy server for nutrition lookup');
          return null;
        }
      }

      final response = await _dio.post(
        '/nutrition',
        data: {
          'food_name': foodName,
          'quantity': quantity,
        },
      );

      if (response.data['success'] == true) {
        final nutrition = response.data['nutrition'];
        return NutritionData(
          foodName: nutrition['food_name'] ?? foodName,
          calories: (nutrition['energy_kcal'] ?? 0).toDouble(),
          protein: (nutrition['protein_g'] ?? 0).toDouble(),
          carbohydrates: (nutrition['carbohydrate_g'] ?? 0).toDouble(),
          fat: (nutrition['fat_g'] ?? 0).toDouble(),
          fiber: (nutrition['fibre_g'] ?? 0).toDouble(),
          sugars: (nutrition['sugars_g'] ?? 0).toDouble(),
          sodium: (nutrition['sodium_mg'] ?? 0).toDouble(),
          cholesterol: (nutrition['cholesterol_mg'] ?? 0).toDouble(),
        );
      }

      return null;
    } catch (e) {
      print('Error getting nutrition info: $e');
      return null;
    }
  }

  /// Predict food from image bytes
  Future<MLFoodRecognitionResponse> predictFoodFromBytes(Uint8List imageBytes) async {
    try {
      // Ensure we have a working server URL
      if (_workingUrl == null) {
        final isHealthy = await isServerHealthy();
        if (!isHealthy) {
          return MLFoodRecognitionResponse(
            success: false,
            error: 'No healthy ML server found',
          );
        }
      }

      final base64Image = base64Encode(imageBytes);

      final response = await _dio.post(
        '/predict',
        data: {
          'image': base64Image,
        },
      );

      return MLFoodRecognitionResponse.fromJson(response.data);
    } catch (e) {
      print('Error predicting food from bytes: $e');
      return MLFoodRecognitionResponse(
        success: false,
        error: 'Failed to predict food: ${e.toString()}',
      );
    }
  }

  /// Predict food and get nutrition information
  Future<MLFoodRecognitionResponse> predictFoodWithNutrition(File imageFile) async {
    try {
      // Ensure we have a working server URL
      if (_workingUrl == null) {
        final isHealthy = await isServerHealthy();
        if (!isHealthy) {
          return MLFoodRecognitionResponse(
            success: false,
            error: 'No healthy ML server found',
          );
        }
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _dio.post(
        '/predict_with_nutrition',
        data: {
          'image': base64Image,
        },
      );

      return MLFoodRecognitionResponse.fromJson(response.data);
    } catch (e) {
      print('Error predicting food with nutrition: $e');
      return MLFoodRecognitionResponse(
        success: false,
        error: 'Failed to predict food with nutrition: ${e.toString()}',
      );
    }
  }

  /// Set a custom server URL for testing
  void setServerUrl(String newUrl) {
    _workingUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }
}
