import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attempt2/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service that handles authentication with Firebase
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Sign in with email and password
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return _createUserModelFromFirebaseUser(userCredential.user!);
      }
      return null;
    } catch (e) {
      print('Error signing in with email: $e');
      return null;
    }
  }

  /// Sign up with email and password
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    int? age,
    double? weight,
    double? height,
    String? gender,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Update display name
        await userCredential.user!.updateDisplayName(name);

        // Create user model
        final userModel = UserModel(
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

        // Save to shared preferences
        await _saveUserToPrefs(userModel);

        return userModel;
      }
      return null;
    } catch (e) {
      print('Error signing up with email: $e');
      return null;
    }
  }

  /// Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Begin Google sign in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in flow
        return null;
      }

      // Get auth details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        return _createUserModelFromFirebaseUser(userCredential.user!);
      }
      return null;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();

      // Sign out from Google if needed
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Clear user from shared preferences
      await _clearUserFromPrefs();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  /// Update user profile
  Future<UserModel?> updateUserProfile(UserModel updatedUser) async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // Update display name if changed
        if (updatedUser.name != user.displayName) {
          await user.updateDisplayName(updatedUser.name);
        }

        // Save to shared preferences
        await _saveUserToPrefs(updatedUser);

        return updatedUser;
      }
      return null;
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  /// Create UserModel from Firebase User
  UserModel _createUserModelFromFirebaseUser(User firebaseUser) {
    return UserModel(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      photoUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
    );
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

  /// Clear user from shared preferences
  Future<void> _clearUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
    } catch (e) {
      print('Error clearing user from prefs: $e');
    }
  }

  /// Load user from shared preferences
  Future<UserModel?> loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        return UserModel.fromJsonString(userData);
      }
      return null;
    } catch (e) {
      print('Error loading user from prefs: $e');
      return null;
    }
  }
}
