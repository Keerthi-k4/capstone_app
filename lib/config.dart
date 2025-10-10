import 'dart:io';
import 'dart:developer' as developer;

class ApiConfig {
  static String get baseUrl {
    if (Platform.isAndroid) {
      if (_isAndroidEmulator()) {
        developer.log('Detected Android Emulator - using 10.0.2.2');
        return 'http://10.0.2.2:8000'; // Emulator
      } else {
        developer.log('Detected Android Physical Device - using local IP');
        return 'http://192.168.1.10:8000'; // Physical device
      }
    } else if (Platform.isIOS) {
      if (_isIOSSimulator()) {
        developer.log('Detected iOS Simulator - using localhost');
        return 'http://localhost:8000'; // iOS Simulator
      } else {
        developer.log('Detected iOS Physical Device - using local IP');
        return 'http://192.168.1.10:8000'; // Physical iOS device
      }
    }

    // Fallback
    return 'http://10.0.2.2:8000';
  }

  // Improved Android emulator detection
  static bool _isAndroidEmulator() {
    // Multiple checks for better detection
    final env = Platform.environment;

    // Check common emulator environment variables
    if (env['ANDROID_EMULATOR'] != null) return true;
    if (env['FLUTTER_TEST'] != null) return true;

    // Check for emulator-specific properties
    try {
      // This works in debug mode - check if we're running on x86/x86_64
      final result = Process.runSync('getprop', ['ro.product.cpu.abi']);
      if (result.exitCode == 0) {
        final abi = result.stdout.toString().trim();
        if (abi.contains('x86') || abi.contains('x86_64')) {
          return true;
        }
      }
    } catch (e) {
      // Process.runSync might not work in release mode
      developer.log('Could not run getprop: $e');
    }

    // Fallback: assume emulator if we can't determine
    // You might want to change this default based on your needs
    return false;
  }

  // iOS simulator detection
  static bool _isIOSSimulator() {
    final env = Platform.environment;

    // Check for simulator environment variables
    if (env['SIMULATOR_DEVICE_NAME'] != null) return true;
    if (env['SIMULATOR_RUNTIME_VERSION'] != null) return true;
    if (env['SIMULATOR_UDID'] != null) return true;

    return false;
  }

  // Manual override for testing
  static const bool forceEmulator = false; // Set to true to force emulator URLs
  static const bool forcePhysicalDevice =
      false; // Set to true to force device URLs

  static String get baseUrlWithOverride {
    if (forceEmulator) {
      return Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';
    }
    if (forcePhysicalDevice) {
      return 'http://192.168.1.10:8000';
    }
    return baseUrl;
  }

  // Debug method to help troubleshoot
  static void debugInfo() {
    developer.log('=== API Config Debug Info ===');
    developer.log('Platform: ${Platform.operatingSystem}');
    developer.log('Is Android: ${Platform.isAndroid}');
    developer.log('Is iOS: ${Platform.isIOS}');

    if (Platform.isAndroid) {
      developer.log('Android Emulator detected: ${_isAndroidEmulator()}');
    }
    if (Platform.isIOS) {
      developer.log('iOS Simulator detected: ${_isIOSSimulator()}');
    }

    developer.log('Selected base URL: $baseUrl');
    developer.log('Environment variables:');
    Platform.environment.forEach((key, value) {
      if (key.contains('ANDROID') ||
          key.contains('SIMULATOR') ||
          key.contains('FLUTTER') ||
          key.contains('EMULATOR')) {
        developer.log('  $key: $value');
      }
    });
    developer.log('============================');
  }
}
