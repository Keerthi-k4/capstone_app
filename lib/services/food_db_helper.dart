import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FoodLog {
  final int? id;
  final String name;
  final int calories;
  final String mealType; // breakfast, lunch, dinner
  final String date;

  FoodLog(
      {this.id,
      required this.name,
      required this.calories,
      required this.mealType,
      required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'mealType': mealType,
      'date': date,
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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE food_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        calories INTEGER,
        mealType TEXT,
        date TEXT
      )
    ''');
  }

  Future<int> insertLog(FoodLog log) async {
    final db = await database;
    return await db.insert('food_logs', log.toMap());
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
            ))
        .toList();
  }

  Future<void> deleteAllLogs() async {
    final db = await database;
    await db.delete('food_logs');
  }
}
