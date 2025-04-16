import 'package:attempt2/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A dummy authentication service for development purposes
/// when Firebase is not set up yet
class DummyAuthService {
  static final DummyAuthService _instance = DummyAuthService._internal();
  factory DummyAuthService() => _instance;
  DummyAuthService._internal();

  UserModel? _currentUser;

  /// Get current user
  UserModel? get currentUser => _currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => _currentUser != null;

  /// Initialize the service
  Future<void> init() async {
    // Try to load user from preferences
    await _loadUserFromPrefs();
  }

  /// Sign in with email and password (dummy implementation)
  Future<UserModel?> signInWithEmail(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Very basic validation - in a real app you would check against stored credentials
    if (email.isNotEmpty && password.length >= 6) {
      final user = UserModel(
        id: const Uuid().v4(),
        name: email.split('@').first,
        email: email,
        createdAt: DateTime.now(),
      );

      _currentUser = user;
      await _saveUserToPrefs(user);
      return user;
    }

    return null;
  }

  /// Sign up with email and password (dummy implementation)
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    int? age,
    double? weight,
    double? height,
    String? gender,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Basic validation
    if (email.isNotEmpty && password.length >= 6 && name.isNotEmpty) {
      final user = UserModel(
        id: const Uuid().v4(),
        name: name,
        email: email,
        age: age,
        weight: weight,
        height: height,
        gender: gender,
        createdAt: DateTime.now(),
      );

      _currentUser = user;
      await _saveUserToPrefs(user);
      return user;
    }

    return null;
  }

  /// Sign in with Google (dummy implementation)
  Future<UserModel?> signInWithGoogle() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    final user = UserModel(
      id: const Uuid().v4(),
      name: 'Google User',
      email: 'google@example.com',
      photoUrl: 'https://via.placeholder.com/150',
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    await _saveUserToPrefs(user);
    return user;
  }

  /// Sign out
  Future<void> signOut() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  /// Update user profile
  Future<UserModel?> updateUserProfile(UserModel updatedUser) async {
    if (_currentUser == null) return null;

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    _currentUser = updatedUser;
    await _saveUserToPrefs(updatedUser);
    return updatedUser;
  }

  /// Save user to shared preferences
  Future<void> _saveUserToPrefs(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', user.toJsonString());
    } catch (e) {
      print('Error saving user to prefs: $e');
    }
  }

  /// Load user from shared preferences
  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        _currentUser = UserModel.fromJsonString(userData);
      }
    } catch (e) {
      print('Error loading user from prefs: $e');
    }
  }

  /// Create a demo user
  UserModel createDemoUser() {
    final user = UserModel(
      id: 'demo-user-id',
      name: 'Demo User',
      email: 'demo@example.com',
      photoUrl: 'https://via.placeholder.com/150',
      age: 30,
      weight: 70,
      height: 175,
      gender: 'Male',
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    _saveUserToPrefs(user);
    return user;
  }
}
