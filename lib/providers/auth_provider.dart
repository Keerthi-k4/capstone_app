import 'package:flutter/material.dart';
import 'package:attempt2/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:attempt2/core/services/dummy_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider that manages user authentication state
class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _useFirebase = true;

  // Firebase instances
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Dummy auth service for development
  final DummyAuthService _dummyAuth = DummyAuthService();

  // Add debug flag
  final bool _isDebugging = true;

  void _debugPrint(String message) {
    if (_isDebugging) {
      print('AUTH DEBUG: $message');
    }
  }

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  AuthProvider() {
    _init();
  }

  /// Initialize the provider
  Future<void> _init() async {
    try {
      // Check if Firebase is available
      firebase_auth.FirebaseAuth.instance.app;
      _useFirebase = true;

      // Load user data
      _loadUserFromPrefs();

      // Listen to Firebase auth state changes
      _auth.authStateChanges().listen((firebase_auth.User? user) {
        if (user == null && _currentUser != null) {
          // User logged out from Firebase, clear local user
          signOut();
        }
      });
    } catch (e) {
      // Firebase not initialized, use dummy auth
      _useFirebase = false;
      print('Firebase not initialized, using dummy auth service');
      await _dummyAuth.init();
      _currentUser = _dummyAuth.currentUser;
      if (_currentUser != null) {
        notifyListeners();
      }
    }
  }

  /// Load user data from shared preferences
  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        _currentUser = UserModel.fromJsonString(userData);
        notifyListeners();
      }
    } catch (e) {
      _error = "Failed to load user data: $e";
      print(_error);
    }
  }

  /// Save user data to shared preferences
  Future<void> _saveUserToPrefs(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', user.toJsonString());
    } catch (e) {
      _error = "Failed to save user data: $e";
      print(_error);
    }
  }

  /// Clear user data from shared preferences
  Future<void> _clearUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
    } catch (e) {
      _error = "Failed to clear user data: $e";
      print(_error);
    }
  }

  /// Sign up with email and password
  /// Only name and email are required, all other parameters are optional
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    int? age,
    double? weight,
    double? height,
    String? gender,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _debugPrint('Attempting to sign up with email: $email');

      // Check if Firebase is available
      if (!_useFirebase) {
        _debugPrint('Firebase not available, using dummy auth');
        await Future.delayed(const Duration(seconds: 1)); // Simulate network
        _currentUser = UserModel(
          id: 'dummy-user-id',
          name: name,
          email: email,
          photoUrl: null,
          age: age,
          weight: weight,
          height: height,
          gender: gender,
          createdAt: DateTime.now(),
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Firebase auth
      _debugPrint('Using Firebase authentication for sign up');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _debugPrint('Firebase sign-up successful');

        // Update the user's display name
        await userCredential.user!.updateDisplayName(name);

        // Create UserModel from Firebase user
        _currentUser = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          photoUrl: userCredential.user!.photoURL,
          age: age,
          weight: weight,
          height: height,
          gender: gender,
          createdAt: DateTime.now(),
        );

        // Save user to shared preferences
        await _saveUserToPrefs(_currentUser!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _debugPrint('Firebase returned null user after sign-up');
        _error = 'Account creation failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _debugPrint(
        'FirebaseAuthException during sign-up: ${e.code} - ${e.message}',
      );

      switch (e.code) {
        case 'email-already-in-use':
          _error = 'Email already in use';
          break;
        case 'weak-password':
          _error = 'Password is too weak';
          break;
        case 'invalid-email':
          _error = 'Invalid email address';
          break;
        case 'network-request-failed':
          _error = 'Network error - please check your connection';
          break;
        default:
          _error = 'Account creation failed: ${e.message}';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _debugPrint('Generic error during sign-up: $e');
      _error = 'Account creation failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _debugPrint('Attempting to sign in with email: $email');

      // Check if Firebase is available
      if (!_useFirebase) {
        _debugPrint('Firebase not available, using dummy auth');
        await Future.delayed(const Duration(seconds: 1)); // Simulate network
        _currentUser = UserModel(
          id: 'dummy-user-id',
          name: 'Test User',
          email: email,
          photoUrl: null,
          createdAt: DateTime.now(),
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Firebase auth
      _debugPrint('Using Firebase authentication');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _debugPrint('Firebase sign-in successful');

        // Get additional user data from Firestore if needed
        await _fetchUserData(userCredential.user!.uid);

        _currentUser = UserModel(
          id: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'User',
          email: email,
          photoUrl: userCredential.user!.photoURL,
          createdAt: DateTime.now(),
        );

        // Save user to shared preferences
        await _saveUserToPrefs(_currentUser!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _debugPrint('Firebase returned null user after sign-in');
        _error = 'Authentication failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'user-not-found':
          _error = 'No user found with this email';
          break;
        case 'wrong-password':
          _error = 'Wrong password';
          break;
        case 'network-request-failed':
          _error = 'Network error - please check your connection';
          break;
        default:
          _error = 'Authentication failed: ${e.message}';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _debugPrint('Generic error during sign-in: $e');
      _error = 'Authentication failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _debugPrint('Attempting to sign in with Google');

      if (!_useFirebase) {
        _debugPrint(
          'Firebase not available, using dummy auth for Google sign-in',
        );
        await Future.delayed(const Duration(seconds: 1)); // Simulate network
        _currentUser = UserModel(
          id: 'google-dummy-user-id',
          name: 'Google Test User',
          email: 'google-user@example.com',
          photoUrl: null,
          createdAt: DateTime.now(),
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Configure Google Sign In
      _debugPrint('Configuring Google Sign In');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _debugPrint('Google sign-in was cancelled by user');
        _error = 'Google sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _debugPrint('Getting Google auth credentials');
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      _debugPrint('Signing in to Firebase with Google credential');
      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        _debugPrint('Firebase sign-in with Google successful');

        // Check if this user exists in Firestore, if not, create a record
        bool userExists = await _checkUserExists(userCredential.user!.uid);

        if (!userExists) {
          _debugPrint('Creating new user record in Firestore');
          await _saveUserData(
            userCredential.user!.uid,
            userCredential.user!.displayName ?? 'User',
            userCredential.user!.email ?? '',
          );
        } else {
          _debugPrint('User already exists in Firestore');
        }

        // Update local user data
        _currentUser = UserModel(
          id: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'User',
          email: userCredential.user!.email ?? '',
          photoUrl: userCredential.user!.photoURL,
          createdAt: DateTime.now(),
        );

        // Save user to shared preferences
        await _saveUserToPrefs(_currentUser!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _debugPrint('Firebase returned null user after Google sign-in');
        _error = 'Authentication failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _debugPrint('Error during Google sign-in: $e');
      _error = 'Google sign-in failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update user profile information
  Future<bool> updateUserProfile({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? gender,
    Map<String, dynamic>? healthMetrics,
  }) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = _currentUser!.copyWith(
        name: name,
        age: age,
        weight: weight,
        height: height,
        gender: gender,
        healthMetrics: healthMetrics ?? _currentUser!.healthMetrics,
      );

      if (_useFirebase) {
        // Update Firebase display name if needed
        if (name != null && name != _auth.currentUser?.displayName) {
          await _auth.currentUser?.updateDisplayName(name);
        }
      } else {
        // Use dummy auth for development
        await _dummyAuth.updateUserProfile(updatedUser);
      }

      // Save to provider state
      _currentUser = updatedUser;

      // Save to shared preferences
      await _saveUserToPrefs(updatedUser);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign user out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_useFirebase) {
        // Sign out from Firebase
        await _auth.signOut();

        // Sign out from Google if needed
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      } else {
        // Use dummy auth for development
        await _dummyAuth.signOut();
      }

      // Clear user data
      _currentUser = null;
      await _clearUserFromPrefs();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // For demo/testing purposes only - creates a fake user
  void createDemoUser() {
    if (_useFirebase) {
      _currentUser = UserModel(
        id: 'demo-user-id',
        name: 'Demo User',
        email: 'demo@example.com',
        photoUrl: null,
        age: 30,
        weight: 70,
        height: 175,
        gender: 'Male',
        createdAt: DateTime.now(),
      );
      _saveUserToPrefs(_currentUser!);
    } else {
      _currentUser = _dummyAuth.createDemoUser();
    }
    notifyListeners();
  }

  // Helper method to check if user exists in Firestore
  Future<bool> _checkUserExists(String uid) async {
    try {
      if (!_useFirebase) return false;

      final docSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      return docSnapshot.exists;
    } catch (e) {
      _debugPrint('Error checking if user exists: $e');
      return false;
    }
  }

  // Helper method to save user data to Firestore
  Future<void> _saveUserData(String uid, String name, String email) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': email,
      });
    } catch (e) {
      _debugPrint('Error saving user data to Firestore: $e');
    }
  }

  // Helper method to fetch user data from Firestore
  Future<void> _fetchUserData(String uid) async {
    try {
      if (!_useFirebase) return;

      final docSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        if (userData != null) {
          _currentUser = UserModel(
            id: uid,
            name: userData['name'],
            email: userData['email'],
            photoUrl: null,
            createdAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      _debugPrint('Error fetching user data from Firestore: $e');
    }
  }

  // Add demo mode method
  Future<bool> loginWithDemoAccount() async {
    _debugPrint('Using demo account login');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Short delay for UI feedback

      _currentUser = UserModel(
        id: 'demo-user-id',
        email: 'demo@example.com',
        name: 'Demo User',
        photoUrl: null,
        age: 30,
        weight: 70,
        height: 175,
        gender: 'Male',
        createdAt: DateTime.now(),
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _debugPrint('Error during demo login: $e');
      _error = 'Demo login failed';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
