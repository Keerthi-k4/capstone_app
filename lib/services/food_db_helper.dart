import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart'; // import at top

class FoodLog {
  final int? id;
  final String name;
  final int calories;
  final String mealType; // breakfast, lunch, dinner
  final String date;
  final double quantity; // quantity in servings

  FoodLog(
      {this.id,
      required this.name,
      required this.calories,
      required this.mealType,
      required this.date,
      this.quantity = 1.0});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'mealType': mealType,
      'date': date,
      'quantity': quantity,
    };
  }

  // Convert to API format (without id field for API calls)
  Map<String, dynamic> toApiFormat() {
    return {
      'name': name,
      'calories': calories,
      'mealType': mealType,
      'date': date,
      'quantity': quantity,
    };
  }
}

// Model for API recommendation response
class FoodRecommendation {
  final String item;
  final int calories;
  final String mealType;
  final String date;
  final String reasoning;
  final double quantity;

  FoodRecommendation({
    required this.item,
    required this.calories,
    required this.mealType,
    required this.date,
    required this.reasoning,
    this.quantity = 1.0,
  });

  factory FoodRecommendation.fromJson(Map<String, dynamic> json) {
    return FoodRecommendation(
      item: json['item'] ?? '',
      calories: json['calories'] ?? 0,
      mealType: json['mealType'] ?? 'snack',
      date: json['date'] ?? '',
      reasoning: json['reasoning'] ?? '',
      quantity: (json['quantity'] ?? 1.0).toDouble(),
    );
  }

  // Convert to local DB format
  Map<String, dynamic> toDbMap() {
    return {
      'name': item,
      'calories': calories,
      'mealType': mealType,
      'date': date,
      'reason': reasoning,
      'accepted': 0, // default to not accepted
    };
  }
}

class FoodDBHelper {
  static final FoodDBHelper _instance = FoodDBHelper._internal();
  factory FoodDBHelper() => _instance;
  FoodDBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('food_logs.db');
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, fileName);

    return await openDatabase(
      path,
      version: 3, // Changed from 2 to 3
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    // Create food_logs table
    await db.execute('''
    CREATE TABLE food_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      calories INTEGER,
      mealType TEXT,
      date TEXT,
      quantity REAL DEFAULT 1.0
    )
  ''');

    // Create food_recommendations table
    await db.execute('''
    CREATE TABLE food_recommendations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      calories INTEGER,
      mealType TEXT,
      date TEXT,
      reason TEXT,
      accepted INTEGER DEFAULT 0
    )
  ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE food_logs ADD COLUMN quantity REAL DEFAULT 1.0');
    }

    if (oldVersion < 3) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS food_recommendations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        calories INTEGER,
        mealType TEXT,
        date TEXT,
        reason TEXT,
        accepted INTEGER DEFAULT 0
      )
    ''');
    }
  }

  Future<int> insertLog(FoodLog log) async {
    final db = await database;
    int id = await db.insert('food_logs', log.toMap());

    // Trigger recommendation generation asynchronously
    Future(() async {
      try {
        await _generateRecommendations(log.date);
      } catch (e, st) {
        // Handle errors silently or log them
        print("Error generating recommendations: $e\n$st");
      }
    });

    return id;
  }

  Future<List<FoodLog>> getLogsByDate(String date) async {
    final db = await database;
    final result =
        await db.query('food_logs', where: 'date = ?', whereArgs: [date]);
    return result
        .map((e) => FoodLog(
              id: e['id'] as int,
              name: e['name'] as String,
              calories: e['calories'] as int,
              mealType: e['mealType'] as String,
              date: e['date'] as String,
              quantity: (e['quantity'] as double?) ?? 1.0,
            ))
        .toList();
  }

  Future<int> deleteLog(int id) async {
    final db = await database;
    return await db.delete('food_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateLog(FoodLog log) async {
    final db = await database;
    return await db.update(
      'food_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<void> deleteAllLogs() async {
    final db = await database;
    await db.delete('food_logs');
  }

  Future<int> insertRecommendation(Map<String, dynamic> rec) async {
    final db = await database;
    return await db.insert('food_recommendations', rec);
  }

  Future<List<Map<String, dynamic>>> getRecommendationsByDate(
      String date) async {
    final db = await database;
    return await db.query(
      'food_recommendations',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<int> updateRecommendation(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'food_recommendations',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRecommendation(int id) async {
    final db = await database;
    return await db
        .delete('food_recommendations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _generateRecommendations(String date) async {
    try {
      print('Starting recommendation generation for date: $date');

      // Get recent logs (last 7 days) from local DB for better context
      final db = await database;
      final DateTime targetDate = DateTime.parse(date);
      final DateTime weekAgo = targetDate.subtract(Duration(days: 7));

      final logsList = await db.query(
        'food_logs',
        where: 'date >= ? AND date <= ?',
        whereArgs: [weekAgo.toIso8601String().split('T')[0], date],
        orderBy: 'date DESC',
      );

      print('Found ${logsList.length} logs for recommendation context');

      if (logsList.isEmpty) {
        print('No food logs found for recommendation generation');
        return;
      }

      // Convert logs to API format
      final logsForApi = logsList
          .map((log) => {
                'name': log['name'],
                'calories': log['calories'],
                'mealType': log['mealType'],
                'date': log['date'],
                'quantity': log['quantity'] ?? 1.0,
              })
          .toList();

      // Prepare request body matching FastAPI structure
      final requestBody = {
        'date': date,
        'logs': logsForApi,
        'preferences': [], // Add user preferences if available
      };

      print(
          'Sending recommendation request to: ${ApiConfig.baseUrl}/recommendations/generate');
      print('Request body: ${jsonEncode(requestBody)}');

      // Send to correct FastAPI endpoint
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/recommendations/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: 30)); // Add timeout

      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Parsed response data: $responseData');

        if (responseData['success'] == true &&
            responseData['recommendations'] != null) {
          // Clear existing recommendations for this date
          int deletedCount = await db.delete(
            'food_recommendations',
            where: 'date = ?',
            whereArgs: [date],
          );
          print('Deleted $deletedCount existing recommendations for $date');

          // Save new recommendations to local DB
          final recommendations = responseData['recommendations'] as List;
          print('Processing ${recommendations.length} recommendations');

          int insertedCount = 0;
          for (var recJson in recommendations) {
            print('Processing recommendation: $recJson');

            try {
              // Handle both 'item' and 'name' fields from API
              final recommendationData = {
                'name': recJson['item'] ?? recJson['name'] ?? 'Unknown Item',
                'calories': recJson['calories'] ?? 0,
                'mealType': recJson['mealType'] ?? 'snack',
                'date': date,
                'reason': recJson['reasoning'] ?? recJson['reason'] ?? '',
                'accepted': 0,
              };

              print('Inserting recommendation data: $recommendationData');
              await db.insert('food_recommendations', recommendationData);
              insertedCount++;
            } catch (e) {
              print('Error inserting recommendation: $e');
              print('Problematic data: $recJson');
            }
          }

          print('Successfully saved $insertedCount recommendations');

          // Verify insertion
          final verifyRecs = await db.query(
            'food_recommendations',
            where: 'date = ?',
            whereArgs: [date],
          );
          print(
              'Verification: Found ${verifyRecs.length} recommendations in DB');
          print(
              'Sample recommendation: ${verifyRecs.isNotEmpty ? verifyRecs.first : "None"}');
        } else {
          print('API returned success=false or no recommendations');
          print('Response message: ${responseData['message'] ?? "No message"}');
        }
      } else {
        print('Failed to get recommendations. Status: ${response.statusCode}');
        print('Response body: ${response.body}');

        // Try to parse error message
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

      // Log more details about the error
      if (e is http.ClientException) {
        print('Network error: Check if API server is running');
      } else if (e is FormatException) {
        print('JSON parsing error: API response might not be valid JSON');
      }
    }
  }

// Enhanced manual generation with better error reporting
  Future<void> generateRecommendationsManually(String date) async {
    print('Manual recommendation generation triggered for: $date');

    try {
      await _generateRecommendations(date);
      print('Manual recommendation generation completed successfully');
    } catch (e) {
      print('Manual recommendation generation failed: $e');
      rethrow; // Re-throw to let UI handle the error
    }
  }
}
