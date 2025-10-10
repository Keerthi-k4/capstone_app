import 'dart:io';
import '../models/food_model.dart';
import 'ml_food_recognition_service.dart';
import 'on_device_ml_service.dart';

/// Hybrid ML service that can use either server-based or on-device ML
class HybridMLService {
  final MLFoodRecognitionService _serverService = MLFoodRecognitionService();
  final OnDeviceMLService _onDeviceService = OnDeviceMLService();
  
  bool _preferOnDevice = true; // Set to true to prefer on-device ML
  bool _serverAvailable = false;
  bool _onDeviceAvailable = false;

  /// Initialize the hybrid service
  Future<void> initialize() async {
    print('🔄 Initializing Hybrid ML Service...');
    
    // Initialize on-device service
    _onDeviceAvailable = await _onDeviceService.initialize();
    
    // Check server availability with explicit health check
    _serverAvailable = await _serverService.isServerHealthy();
    
    print('📊 Hybrid ML Service Status:');
    print('- On-device: ${_onDeviceAvailable ? "✅ Available" : "❌ Not available"}');
    print('- Server: ${_serverAvailable ? "✅ Available" : "❌ Not available"}');
    
    if (!_onDeviceAvailable && !_serverAvailable) {
      print('⚠️  Warning: No ML services available!');
    }
  }

  /// Check if any ML service is available
  Future<bool> isAvailable() async {
    if (!_onDeviceAvailable && !_serverAvailable) {
      await initialize();
    }
    return _onDeviceAvailable || _serverAvailable;
  }

  /// Get the current service status
  MLServiceStatus getStatus() {
    if (_onDeviceAvailable && _serverAvailable) {
      return MLServiceStatus.both;
    } else if (_onDeviceAvailable) {
      return MLServiceStatus.onDeviceOnly;
    } else if (_serverAvailable) {
      return MLServiceStatus.serverOnly;
    } else {
      return MLServiceStatus.none;
    }
  }

  /// Predict food using the best available service
  Future<MLFoodRecognitionResponse> predictFood(File imageFile) async {
    // Refresh availability
    await initialize();

    try {
      // Try on-device first if preferred and available
      if (_preferOnDevice && _onDeviceAvailable) {
        print('Using on-device ML for prediction');
        final result = await _onDeviceService.predictFood(imageFile);
        if (result.success) {
          return result;
        }
        print('On-device prediction failed, trying server...');
      }

      // Try server if available
      if (_serverAvailable) {
        print('Using server-based ML for prediction');
        final result = await _serverService.predictFoodWithNutrition(imageFile);
        if (result.success) {
          return result;
        }
        print('Server prediction failed');
      }

      // Fallback to on-device if server fails and we haven't tried it yet
      if (!_preferOnDevice && _onDeviceAvailable) {
        print('Falling back to on-device ML');
        return await _onDeviceService.predictFood(imageFile);
      }

      // No service available
      return MLFoodRecognitionResponse(
        success: false,
        error: 'No ML service available for prediction',
      );
    } catch (e) {
      return MLFoodRecognitionResponse(
        success: false,
        error: 'Prediction error: $e',
      );
    }
  }

  /// Get nutrition information
  Future<NutritionData?> getNutritionInfo(String foodName, {double quantity = 100}) async {
    // Try server first for nutrition (more comprehensive)
    if (_serverAvailable) {
      try {
        return await _serverService.getNutritionInfo(foodName, quantity: quantity);
      } catch (e) {
        print('Server nutrition lookup failed: $e');
      }
    }

    // Fallback to on-device nutrition data
    if (_onDeviceAvailable) {
      // On-device service has basic nutrition data
      return null; // Would implement basic lookup in on-device service
    }

    return null;
  }

  /// Set preference for ML service
  void setPreference(bool preferOnDevice) {
    _preferOnDevice = preferOnDevice;
  }

  /// Force refresh of service availability
  Future<void> refreshAvailability() async {
    await initialize();
  }
}

/// Enum for ML service status
enum MLServiceStatus {
  none,
  onDeviceOnly,
  serverOnly,
  both,
}

/// Extension to get user-friendly status messages
extension MLServiceStatusExtension on MLServiceStatus {
  String get displayName {
    switch (this) {
      case MLServiceStatus.none:
        return 'No ML service available';
      case MLServiceStatus.onDeviceOnly:
        return 'On-device ML ready';
      case MLServiceStatus.serverOnly:
        return 'Server ML connected';
      case MLServiceStatus.both:
        return 'Both ML services available';
    }
  }

  String get description {
    switch (this) {
      case MLServiceStatus.none:
        return 'Photo recognition is not available. Use manual search instead.';
      case MLServiceStatus.onDeviceOnly:
        return 'Photo recognition works offline on your device.';
      case MLServiceStatus.serverOnly:
        return 'Photo recognition requires internet connection.';
      case MLServiceStatus.both:
        return 'Photo recognition available both online and offline.';
    }
  }

  bool get isAvailable => this != MLServiceStatus.none;
}
