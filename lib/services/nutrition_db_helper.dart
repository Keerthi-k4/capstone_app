import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Helper that exposes read-only access to the bundled nutrition database.
///
/// This class copies the pre-populated SQLite database from assets to the
/// device's database directory on first access, then opens the file in
/// read-only mode. All subsequent queries reuse the same [Database] instance.
class NutritionDBHelper {
  NutritionDBHelper._internal();

  static final NutritionDBHelper instance = NutritionDBHelper._internal();

  Database? _database;

  /// Lazily open the nutrition database, copying the asset on first launch.
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB();
    return _database!;
  }

  /// Copy the bundled nutrition.db into the device storage (if needed) and
  /// open it in read-only mode.
  Future<Database> _initDB() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'nutrition.db');

      final exists = await databaseExists(path);
      if (!exists) {
        print('[NutritionDBHelper] Copying nutrition.db to $path');
        await Directory(p.dirname(path)).create(recursive: true);
        final data = await rootBundle.load('assets/data/nutrition.db');
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      } else {
        print('[NutritionDBHelper] Using cached nutrition.db at $path');
      }

      final db = await openDatabase(path, readOnly: true);
      print('[NutritionDBHelper] Database opened successfully');
      return db;
    } catch (e, stackTrace) {
      print('[NutritionDBHelper] Failed to initialize database: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Search the nutrition table with token-based LIKE matching and return up to 20 food names.
  Future<List<String>> searchFoods(String? query) async {
    final trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return [];
    }

    try {
      final db = await database;
      final sanitized = _sanitizeQuery(trimmed);
      final tokens =
          sanitized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.isEmpty) {
        return [];
      }

      final whereClause =
          List.filled(tokens.length, 'LOWER(food_name) LIKE ?').join(' AND ');
      final args = tokens.map((token) => '%$token%').toList();

      final rows = await db.rawQuery(
        'SELECT food_name FROM foods_fts WHERE $whereClause LIMIT 20',
        args,
      );

      final results =
          rows.map((row) => row['food_name']).whereType<String>().toList();

      print('[NutritionDBHelper] searchFoods("$trimmed") -> '
          '${results.length} hits (tokens: $tokens)');
      return results;
    } catch (e, stackTrace) {
      print('[NutritionDBHelper] searchFoods error for "$query": $e');
      print(stackTrace);
      return [];
    }
  }

  /// Fetch nutrition data for the exact food name. Returns null if not found.
  Future<Map<String, double>?> getNutrition(String foodName) async {
    final trimmed = foodName.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT food_name, energy_kcal, protein_g, fat_g, carbs_g, fiber_g '
        'FROM foods_fts WHERE food_name = ? COLLATE NOCASE LIMIT 1',
        [trimmed],
      );

      if (rows.isEmpty) {
        print('[NutritionDBHelper] getNutrition("$trimmed") -> not found');
        return null;
      }

      final row = rows.first;
      final nutrition = <String, double>{
        'calories': (row['energy_kcal'] as num?)?.toDouble() ?? 0,
        'protein': (row['protein_g'] as num?)?.toDouble() ?? 0,
        'fat': (row['fat_g'] as num?)?.toDouble() ?? 0,
        'carbs': (row['carbs_g'] as num?)?.toDouble() ?? 0,
        'fiber': (row['fiber_g'] as num?)?.toDouble() ?? 0,
      };

      print(
          '[NutritionDBHelper] getNutrition("$trimmed") -> ${nutrition['calories']} kcal');
      return nutrition;
    } catch (e, stackTrace) {
      print('[NutritionDBHelper] getNutrition error for "$foodName": $e');
      print(stackTrace);
      return null;
    }
  }

  /// Close the cached database instance. Optional (called on app shutdown).
  Future<void> close() async {
    if (_database == null) {
      return;
    }

    try {
      await _database!.close();
      print('[NutritionDBHelper] Database closed');
    } catch (e) {
      print('[NutritionDBHelper] Error closing database: $e');
    } finally {
      _database = null;
    }
  }

  /// Fetch a deterministic slice of foods for default suggestions.
  Future<List<String>> getDefaultFoods({int limit = 10}) async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT food_name FROM foods_fts LIMIT $limit',
      );

      final results =
          rows.map((row) => row['food_name']).whereType<String>().toList();

      print('[NutritionDBHelper] getDefaultFoods -> ${results.length} entries');
      return results;
    } catch (e, stackTrace) {
      print('[NutritionDBHelper] getDefaultFoods error: $e');
      print(stackTrace);
      return [];
    }
  }

  /// Sanitize free-form text so it can be safely used in LIKE clauses.
  String _sanitizeQuery(String input) {
    // Replace punctuation with spaces and collapse repeats to avoid malformed tokens.
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^0-9a-z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
