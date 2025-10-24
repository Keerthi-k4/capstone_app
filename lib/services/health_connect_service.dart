import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_data_model.dart';

/// Service to interact with Health Connect API via platform channels
/// Supports both demo mode and actual mode for health data tracking
class HealthConnectService {
  static const MethodChannel _channel =
      MethodChannel('com.capstone.fitnessdiet/health_connect');

  static const String _demoModeKey = 'health_connect_demo_mode';

  /// Get the current mode (demo or actual)
  Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_demoModeKey) ?? true; // Default to demo mode
  }

  /// Set the mode (demo or actual)
  Future<void> setDemoMode(bool isDemo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, isDemo);
  }

  /// Check if Health Connect is available on the device
  Future<bool> isHealthConnectAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking Health Connect availability: ${e.message}');
      return false;
    }
  }

  /// Request Health Connect permissions
  Future<bool> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error requesting permissions: ${e.message}');
      return false;
    }
  }

  /// Check if all required permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking permissions: ${e.message}');
      return false;
    }
  }

  /// Get today's health data
  /// Returns demo data if in demo mode, otherwise fetches from Health Connect
  Future<HealthData> getTodayHealthData() async {
    final isDemo = await isDemoMode();

    if (isDemo) {
      // Return demo data
      return HealthData.demo();
    }

    // Check if Health Connect is available
    final isAvailable = await isHealthConnectAvailable();
    if (!isAvailable) {
      print('Health Connect not available, returning demo data');
      return HealthData.demo();
    }

    // Check permissions
    final hasPerms = await hasPermissions();
    if (!hasPerms) {
      print('Health Connect permissions not granted, returning demo data');
      return HealthData.demo();
    }

    // Fetch actual data from Health Connect
    try {
      final String today = DateTime.now().toIso8601String().split('T')[0];
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod(
        'getTodayHealthData',
        {'date': today},
      );

      if (result != null) {
        return HealthData.fromJson(Map<String, dynamic>.from(result));
      } else {
        print('No data returned from Health Connect, using demo data');
        return HealthData.demo();
      }
    } on PlatformException catch (e) {
      print('Error fetching health data: ${e.message}');
      return HealthData.demo();
    }
  }

  /// Get health data for a specific date
  Future<HealthData> getHealthDataForDate(String date) async {
    final isDemo = await isDemoMode();

    if (isDemo) {
      return HealthData.demo();
    }

    final isAvailable = await isHealthConnectAvailable();
    if (!isAvailable) {
      return HealthData.demo();
    }

    final hasPerms = await hasPermissions();
    if (!hasPerms) {
      return HealthData.demo();
    }

    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod(
        'getHealthDataForDate',
        {'date': date},
      );

      if (result != null) {
        return HealthData.fromJson(Map<String, dynamic>.from(result));
      } else {
        return HealthData.demo();
      }
    } on PlatformException catch (e) {
      print('Error fetching health data for date: ${e.message}');
      return HealthData.demo();
    }
  }

  /// Write health data to Health Connect (for testing purposes)
  Future<bool> writeHealthData(HealthData data) async {
    final isDemo = await isDemoMode();
    if (isDemo) {
      print('Cannot write data in demo mode');
      return false;
    }

    final isAvailable = await isHealthConnectAvailable();
    if (!isAvailable) {
      return false;
    }

    final hasPerms = await hasPermissions();
    if (!hasPerms) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'writeHealthData',
        data.toJson(),
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error writing health data: ${e.message}');
      return false;
    }
  }

  /// Open Health Connect settings
  Future<void> openHealthConnectSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } on PlatformException catch (e) {
      print('Error opening Health Connect settings: ${e.message}');
    }
  }
}
