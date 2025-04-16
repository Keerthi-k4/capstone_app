import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling local storage operations
class StorageService {
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  /// Initialize the storage service
  Future<void> init() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
  }

  /// Save a string value
  Future<bool> setString(String key, String value) async {
    await _ensureInitialized();
    return await _prefs.setString(key, value);
  }

  /// Get a string value
  String? getString(String key) {
    if (!_isInitialized) return null;
    return _prefs.getString(key);
  }

  /// Save an integer value
  Future<bool> setInt(String key, int value) async {
    await _ensureInitialized();
    return await _prefs.setInt(key, value);
  }

  /// Get an integer value
  int? getInt(String key) {
    if (!_isInitialized) return null;
    return _prefs.getInt(key);
  }

  /// Save a double value
  Future<bool> setDouble(String key, double value) async {
    await _ensureInitialized();
    return await _prefs.setDouble(key, value);
  }

  /// Get a double value
  double? getDouble(String key) {
    if (!_isInitialized) return null;
    return _prefs.getDouble(key);
  }

  /// Save a boolean value
  Future<bool> setBool(String key, bool value) async {
    await _ensureInitialized();
    return await _prefs.setBool(key, value);
  }

  /// Get a boolean value
  bool? getBool(String key) {
    if (!_isInitialized) return null;
    return _prefs.getBool(key);
  }

  /// Save a list of strings
  Future<bool> setStringList(String key, List<String> value) async {
    await _ensureInitialized();
    return await _prefs.setStringList(key, value);
  }

  /// Get a list of strings
  List<String>? getStringList(String key) {
    if (!_isInitialized) return null;
    return _prefs.getStringList(key);
  }

  /// Save an object (converts to JSON string)
  Future<bool> setObject(String key, Map<String, dynamic> value) async {
    await _ensureInitialized();
    return await _prefs.setString(key, jsonEncode(value));
  }

  /// Get an object (parses from JSON string)
  Map<String, dynamic>? getObject(String key) {
    if (!_isInitialized) return null;
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing JSON: $e');
      return null;
    }
  }

  /// Save a list of objects (converts to JSON string)
  Future<bool> setObjectList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    await _ensureInitialized();
    return await _prefs.setString(key, jsonEncode(value));
  }

  /// Get a list of objects (parses from JSON string)
  List<Map<String, dynamic>>? getObjectList(String key) {
    if (!_isInitialized) return null;
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error parsing JSON list: $e');
      return null;
    }
  }

  /// Remove a value
  Future<bool> remove(String key) async {
    await _ensureInitialized();
    return await _prefs.remove(key);
  }

  /// Clear all values
  Future<bool> clear() async {
    await _ensureInitialized();
    return await _prefs.clear();
  }

  /// Check if a key exists
  bool containsKey(String key) {
    if (!_isInitialized) return false;
    return _prefs.containsKey(key);
  }

  /// Get all keys
  Set<String> getKeys() {
    if (!_isInitialized) return {};
    return _prefs.getKeys();
  }

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }
}
