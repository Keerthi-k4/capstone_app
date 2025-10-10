import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class FoodLog {
  final String? id;
  final String name;
  final int calories;
  final String mealType;
  final String date;
  final double quantity;
  final String userId;

  FoodLog({
    this.id,
    required this.name,
    required this.calories,
    required this.mealType,
    required this.date,
    this.quantity = 1.0,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,
      'mealType': mealType,
      'date': date,
      'quantity': quantity,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toApiFormat() {
    return {
      'name': name,
      'calories': calories,
      'mealType': mealType,
      'date': date,
      'quantity': quantity,
    };
  }

  factory FoodLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodLog(
      id: doc.id,
      name: data['name'] ?? '',
      calories: data['calories'] ?? 0,
      mealType: data['mealType'] ?? 'snack',
      date: data['date'] ?? '',
      quantity: (data['quantity'] ?? 1.0).toDouble(),
      userId: data['userId'] ?? '',
    );
  }
}

class FoodRecommendation {
  final String? id;
  final String item;
  final int calories;
  final String mealType;
  final String date;
  final String reasoning;
  final double quantity;
  final String userId;
  final bool accepted;

  FoodRecommendation({
    this.id,
    required this.item,
    required this.calories,
    required this.mealType,
    required this.date,
    required this.reasoning,
    this.quantity = 1.0,
    required this.userId,
    this.accepted = false,
  });

  factory FoodRecommendation.fromJson(
      Map<String, dynamic> json, String userId) {
    return FoodRecommendation(
      item: json['item'] ?? '',
      calories: json['calories'] ?? 0,
      mealType: json['mealType'] ?? 'snack',
      date: json['date'] ?? '',
      reasoning: json['reasoning'] ?? '',
      quantity: (json['quantity'] ?? 1.0).toDouble(),
      userId: userId,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': item,
      'calories': calories,
      'mealType': mealType,
      'date': date,
      'reason': reasoning,
      'quantity': quantity,
      'accepted': accepted,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory FoodRecommendation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodRecommendation(
      id: doc.id,
      item: data['name'] ?? '',
      calories: data['calories'] ?? 0,
      mealType: data['mealType'] ?? 'snack',
      date: data['date'] ?? '',
      reasoning: data['reason'] ?? '',
      quantity: (data['quantity'] ?? 1.0).toDouble(),
      userId: data['userId'] ?? '',
      accepted: data['accepted'] ?? false,
    );
  }
}

class FoodFirestoreService {
  static final FoodFirestoreService _instance =
      FoodFirestoreService._internal();
  factory FoodFirestoreService() => _instance;
  FoodFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _currentUserId != null;

  String get _requireUserId {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to perform this operation');
    }
    return userId;
  }

  CollectionReference get _foodLogsCollection =>
      _firestore.collection('food_logs');

  CollectionReference get _foodRecommendationsCollection =>
      _firestore.collection('food_recommendations');

  Future<String> insertLog(FoodLog log) async {
    final userId = _requireUserId;
    final logWithUserId = FoodLog(
      name: log.name,
      calories: log.calories,
      mealType: log.mealType,
      date: log.date,
      quantity: log.quantity,
      userId: userId,
    );

    final docRef = await _foodLogsCollection.add(logWithUserId.toMap());

    Future(() async {
      try {
        await generateRecommendations(log.date);
      } catch (e, st) {
        print("Error generating recommendations: $e\n$st");
      }
    });

    return docRef.id;
  }

  Future<List<FoodLog>> getLogsByDate(String date) async {
    final userId = _requireUserId;
    final querySnapshot = await _foodLogsCollection
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: date)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => FoodLog.fromFirestore(doc)).toList();
  }

  Future<void> deleteLog(String id) async {
    final userId = _requireUserId;
    final docRef = _foodLogsCollection.doc(id);

    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception('Food log not found');
    }

    final data = doc.data() as Map<String, dynamic>;
    if (data['userId'] != userId) {
      throw Exception('Unauthorized: Cannot delete food log');
    }

    await docRef.delete();
  }

  Future<void> updateLog(FoodLog log) async {
    final userId = _requireUserId;
    if (log.id == null) {
      throw Exception('Log ID is required for update');
    }

    final docRef = _foodLogsCollection.doc(log.id);

    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception('Food log not found');
    }

    final data = doc.data() as Map<String, dynamic>;
    if (data['userId'] != userId) {
      throw Exception('Unauthorized: Cannot update food log');
    }

    final updateData = log.toMap();
    updateData['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.update(updateData);
  }

  Future<void> deleteAllLogs() async {
    final userId = _requireUserId;
    final querySnapshot =
        await _foodLogsCollection.where('userId', isEqualTo: userId).get();

    final batch = _firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<String> insertRecommendation(FoodRecommendation rec) async {
    final docRef =
        await _foodRecommendationsCollection.add(rec.toFirestoreMap());
    return docRef.id;
  }

  Future<List<FoodRecommendation>> getRecommendationsByDate(String date) async {
    final userId = _requireUserId;

    print('DEBUG: Querying recommendations for userId=$userId, date=$date');

    // Query without orderBy to avoid issues with serverTimestamp not being set yet
    final querySnapshot = await _foodRecommendationsCollection
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: date)
        .get();

    print('DEBUG: Found ${querySnapshot.docs.length} recommendations');
    if (querySnapshot.docs.isNotEmpty) {
      final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
      print('DEBUG: First recommendation date: ${data['date']}');
    }

    // Sort in Dart after fetching
    final recommendations = querySnapshot.docs
        .map((doc) => FoodRecommendation.fromFirestore(doc))
        .toList();

    return recommendations;
  }

  Future<void> updateRecommendation(
      String id, Map<String, dynamic> data) async {
    final userId = _requireUserId;
    final docRef = _foodRecommendationsCollection.doc(id);

    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception('Recommendation not found');
    }

    final docData = doc.data() as Map<String, dynamic>;
    if (docData['userId'] != userId) {
      throw Exception('Unauthorized: Cannot update recommendation');
    }

    final updateData = Map<String, dynamic>.from(data);
    updateData['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.update(updateData);
  }

  Future<void> deleteRecommendation(String id) async {
    final userId = _requireUserId;
    final docRef = _foodRecommendationsCollection.doc(id);

    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception('Recommendation not found');
    }

    final data = doc.data() as Map<String, dynamic>;
    if (data['userId'] != userId) {
      throw Exception('Unauthorized: Cannot delete recommendation');
    }

    await docRef.delete();
  }

  // FIXED: generateRecommendations method with proper query
  Future<void> generateRecommendations(String date) async {
    try {
      print('Starting recommendation generation for date: $date');

      final userId = _requireUserId;

      // Get recent logs (last 7 days) - FIXED QUERY
      final DateTime targetDate = DateTime.parse(date);
      final DateTime weekAgo = targetDate.subtract(Duration(days: 7));
      final String weekAgoStr = weekAgo.toIso8601String().split('T')[0];

      // Fetch all logs for user (Firebase doesn't allow range + equality queries)
      final querySnapshot = await _foodLogsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(100) // Limit to last 100 logs for performance
          .get();

      print('Fetched ${querySnapshot.docs.length} total logs');

      // Filter in code for last 7 days
      final recentDocs = querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final logDate = data['date'] as String;
        return logDate.compareTo(weekAgoStr) >= 0 &&
            logDate.compareTo(date) <= 0;
      }).toList();

      print(
          'Found ${recentDocs.length} logs for recommendation context (last 7 days)');

      if (recentDocs.isEmpty) {
        print('No food logs found for recommendation generation');
        return;
      }

      // Convert logs to API format
      final logsForApi = recentDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'name': data['name'],
          'calories': data['calories'],
          'mealType': data['mealType'],
          'date': data['date'],
          'quantity': data['quantity'] ?? 1.0,
        };
      }).toList();

      // Prepare request body matching FastAPI structure
      final requestBody = {
        'date': date,
        'logs': logsForApi,
        'preferences': [],
      };

      print(
          'Sending recommendation request to: ${ApiConfig.baseUrl}/recommendations/generate');
      print(
          'Request body preview: date=$date, logs count=${logsForApi.length}');

      // Send to FastAPI endpoint
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/recommendations/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: 30));

      print('API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Parsed response data: success=${responseData['success']}');

        if (responseData['success'] == true &&
            responseData['recommendations'] != null) {
          // Clear existing recommendations for this date
          final existingRecsQuery = await _foodRecommendationsCollection
              .where('userId', isEqualTo: userId)
              .where('date', isEqualTo: date)
              .get();

          final batch = _firestore.batch();
          for (final doc in existingRecsQuery.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();

          print(
              'Deleted ${existingRecsQuery.docs.length} existing recommendations for $date');

          // Save new recommendations to Firestore
          final recommendations = responseData['recommendations'] as List;
          print('Processing ${recommendations.length} recommendations');

          final recommendationsBatch = _firestore.batch();
          int insertedCount = 0;

          for (var recJson in recommendations) {
            try {
              final recommendation =
                  FoodRecommendation.fromJson(recJson, userId);
              final dataToSave = recommendation.toFirestoreMap();
              // Force the stored date to the requested date to match UI queries
              dataToSave['date'] = date;
              final docRef = _foodRecommendationsCollection.doc();
              recommendationsBatch.set(docRef, dataToSave);
              insertedCount++;
            } catch (e) {
              print('Error preparing recommendation: $e');
              print('Problematic data: $recJson');
            }
          }

          await recommendationsBatch.commit();
          print('Successfully saved $insertedCount recommendations');

          // Verify insertion (without orderBy since timestamps aren't populated yet)
          final verifyQuery = await _foodRecommendationsCollection
              .where('userId', isEqualTo: userId)
              .where('date', isEqualTo: date)
              .get();
          print(
              'Verification: Found ${verifyQuery.docs.length} recommendations in Firestore');

          if (verifyQuery.docs.isEmpty) {
            print(
                'WARNING: Recommendations were saved but verification query returned 0 results');
            print('This might be a timing issue. Checking again...');

            // Wait a moment and try again
            await Future.delayed(Duration(milliseconds: 500));
            final retryQuery = await _foodRecommendationsCollection
                .where('userId', isEqualTo: userId)
                .where('date', isEqualTo: date)
                .get();
            print(
                'Retry verification: Found ${retryQuery.docs.length} recommendations');
          }
        } else {
          print('API returned success=false or no recommendations');
          print('Response message: ${responseData['message'] ?? "No message"}');
        }
      } else {
        print('Failed to get recommendations. Status: ${response.statusCode}');
        print('Response body: ${response.body}');

        try {
          final errorData = jsonDecode(response.body);
          print(
              'Error details: ${errorData['detail'] ?? errorData['message'] ?? "No details"}');
        } catch (e) {
          print('Could not parse error response as JSON');
        }
      }
    } catch (e, stackTrace) {
      print('Error calling recommendation API: $e');
      print('Stack trace: $stackTrace');

      if (e is http.ClientException) {
        print('Network error: Check if API server is running');
      } else if (e is FormatException) {
        print('JSON parsing error: API response might not be valid JSON');
      }
    }
  }

  Future<void> generateRecommendationsManually(String date) async {
    print('Manual recommendation generation triggered for: $date');

    try {
      await generateRecommendations(date);
      print('Manual recommendation generation completed successfully');
    } catch (e) {
      print('Manual recommendation generation failed: $e');
      rethrow;
    }
  }

  // Stream methods for real-time updates
  Stream<List<FoodLog>> getLogsByDateStream(String date) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _foodLogsCollection
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: date)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FoodLog.fromFirestore(doc)).toList());
  }

  Stream<List<FoodRecommendation>> getRecommendationsByDateStream(String date) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    // Remove orderBy to avoid index issues with serverTimestamp
    return _foodRecommendationsCollection
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FoodRecommendation.fromFirestore(doc))
            .toList());
  }
}
