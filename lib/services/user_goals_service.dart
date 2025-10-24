import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GoalPlan { weightLoss, muscleBuilding, maintenance, custom }

class UserGoals {
  final int caloriesTarget;
  final int stepsTarget;
  final int exerciseMinutesTarget;
  final int waterGlassesTarget;
  final int proteinGramsTarget;
  final int carbsGramsTarget;
  final int fatsGramsTarget;
  final int fiberGramsTarget;
  final GoalPlan plan;
  final Map<String, int> waterIntake; // date -> count

  const UserGoals({
    required this.caloriesTarget,
    required this.stepsTarget,
    required this.exerciseMinutesTarget,
    required this.waterGlassesTarget,
    required this.proteinGramsTarget,
    required this.carbsGramsTarget,
    required this.fatsGramsTarget,
    required this.fiberGramsTarget,
    this.plan = GoalPlan.maintenance,
    this.waterIntake = const {},
  });

  UserGoals copyWith({
    int? caloriesTarget,
    int? stepsTarget,
    int? exerciseMinutesTarget,
    int? waterGlassesTarget,
    int? proteinGramsTarget,
    int? carbsGramsTarget,
    int? fatsGramsTarget,
    int? fiberGramsTarget,
    GoalPlan? plan,
    Map<String, int>? waterIntake,
  }) {
    return UserGoals(
      caloriesTarget: caloriesTarget ?? this.caloriesTarget,
      stepsTarget: stepsTarget ?? this.stepsTarget,
      exerciseMinutesTarget:
          exerciseMinutesTarget ?? this.exerciseMinutesTarget,
      waterGlassesTarget: waterGlassesTarget ?? this.waterGlassesTarget,
      proteinGramsTarget: proteinGramsTarget ?? this.proteinGramsTarget,
      carbsGramsTarget: carbsGramsTarget ?? this.carbsGramsTarget,
      fatsGramsTarget: fatsGramsTarget ?? this.fatsGramsTarget,
      fiberGramsTarget: fiberGramsTarget ?? this.fiberGramsTarget,
      plan: plan ?? this.plan,
      waterIntake: waterIntake ?? this.waterIntake,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caloriesTarget': caloriesTarget,
      'stepsTarget': stepsTarget,
      'exerciseMinutesTarget': exerciseMinutesTarget,
      'waterGlassesTarget': waterGlassesTarget,
      'proteinGramsTarget': proteinGramsTarget,
      'carbsGramsTarget': carbsGramsTarget,
      'fatsGramsTarget': fatsGramsTarget,
      'fiberGramsTarget': fiberGramsTarget,
      'plan': describeEnum(plan),
      'waterIntake': waterIntake,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'caloriesTarget': caloriesTarget,
      'stepsTarget': stepsTarget,
      'exerciseMinutesTarget': exerciseMinutesTarget,
      'waterGlassesTarget': waterGlassesTarget,
      'proteinGramsTarget': proteinGramsTarget,
      'carbsGramsTarget': carbsGramsTarget,
      'fatsGramsTarget': fatsGramsTarget,
      'fiberGramsTarget': fiberGramsTarget,
      'plan': describeEnum(plan),
      'waterIntake': waterIntake,
    };
  }

  factory UserGoals.fromMap(Map<String, dynamic> map) {
    return UserGoals(
      caloriesTarget: (map['caloriesTarget'] ?? 2400) as int,
      stepsTarget: (map['stepsTarget'] ?? 10000) as int,
      exerciseMinutesTarget: (map['exerciseMinutesTarget'] ?? 30) as int,
      waterGlassesTarget: (map['waterGlassesTarget'] ?? 8) as int,
      proteinGramsTarget: (map['proteinGramsTarget'] ?? 60) as int,
      carbsGramsTarget: (map['carbsGramsTarget'] ?? 250) as int,
      fatsGramsTarget: (map['fatsGramsTarget'] ?? 65) as int,
      fiberGramsTarget: (map['fiberGramsTarget'] ?? 25) as int,
      plan: _planFromString(map['plan'] as String?),
      waterIntake: Map<String, int>.from(map['waterIntake'] ?? {}),
    );
  }

  static GoalPlan _planFromString(String? value) {
    switch (value) {
      case 'weightLoss':
        return GoalPlan.weightLoss;
      case 'muscleBuilding':
        return GoalPlan.muscleBuilding;
      case 'maintenance':
        return GoalPlan.maintenance;
      case 'custom':
        return GoalPlan.custom;
      default:
        return GoalPlan.maintenance;
    }
  }

  String toJson() => jsonEncode(toLocalMap());

  factory UserGoals.fromJson(String source) =>
      UserGoals.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static const UserGoals defaults = UserGoals(
    caloriesTarget: 2400,
    stepsTarget: 10000,
    exerciseMinutesTarget: 30,
    waterGlassesTarget: 8,
    proteinGramsTarget: 60,
    carbsGramsTarget: 250,
    fatsGramsTarget: 65,
    fiberGramsTarget: 25,
    plan: GoalPlan.maintenance,
  );
}

class UserGoalsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get _isAuthenticated => _auth.currentUser != null;
  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _goalsDocRef {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('goals');
  }

  Future<UserGoals> getGoalsOnce() async {
    // Try Firestore first
    if (_isAuthenticated) {
      final ref = _goalsDocRef!;
      final snap = await ref.get();
      if (snap.exists && snap.data() != null) {
        return UserGoals.fromMap(snap.data()!);
      }
    }

    // Fallback to local storage
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('user_goals');
    if (str != null) {
      return UserGoals.fromJson(str);
    }

    // Defaults
    return UserGoals.defaults;
  }

  Stream<UserGoals> getGoalsStream() {
    final ref = _goalsDocRef;
    if (ref == null) {
      return Stream.value(UserGoals.defaults);
    }
    return ref.snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return UserGoals.fromMap(snap.data()!);
      }
      return UserGoals.defaults;
    });
  }

  Future<void> saveGoals(UserGoals goals) async {
    // Save locally always
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_goals', goals.toJson());

    // Save to Firestore if logged in
    if (_isAuthenticated) {
      final ref = _goalsDocRef!;
      await ref.set(goals.toMap(), SetOptions(merge: true));
    }
  }

  UserGoals presetForPlan(GoalPlan plan, {UserGoals? base}) {
    switch (plan) {
      case GoalPlan.weightLoss:
        return (base ?? UserGoals.defaults).copyWith(
          plan: GoalPlan.weightLoss,
          caloriesTarget: 2000,
          proteinGramsTarget: 80,
          carbsGramsTarget: 200,
          fatsGramsTarget: 55,
          fiberGramsTarget: 28,
          stepsTarget: 10000,
          exerciseMinutesTarget: 35,
          waterGlassesTarget: 8,
        );
      case GoalPlan.muscleBuilding:
        return (base ?? UserGoals.defaults).copyWith(
          plan: GoalPlan.muscleBuilding,
          caloriesTarget: 2800,
          proteinGramsTarget: 120,
          carbsGramsTarget: 300,
          fatsGramsTarget: 75,
          fiberGramsTarget: 30,
          stepsTarget: 8000,
          exerciseMinutesTarget: 45,
          waterGlassesTarget: 10,
        );
      case GoalPlan.maintenance:
        return (base ?? UserGoals.defaults).copyWith(
          plan: GoalPlan.maintenance,
          caloriesTarget: 2400,
          proteinGramsTarget: 80,
          carbsGramsTarget: 250,
          fatsGramsTarget: 65,
          fiberGramsTarget: 25,
          stepsTarget: 9000,
          exerciseMinutesTarget: 30,
          waterGlassesTarget: 8,
        );
      case GoalPlan.custom:
        return (base ?? UserGoals.defaults).copyWith(plan: GoalPlan.custom);
    }
  }

  // Water intake methods
  Future<int> getWaterCountForDate(String date) async {
    final goals = await getGoalsOnce();
    return goals.waterIntake[date] ?? 0;
  }

  Stream<int> getWaterCountStream(String date) {
    final ref = _goalsDocRef;
    if (ref == null) {
      return Stream.fromFuture(getWaterCountForDate(date));
    }
    return ref.snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        final goals = UserGoals.fromMap(snap.data()!);
        return goals.waterIntake[date] ?? 0;
      }
      return 0;
    });
  }

  Future<void> setWaterCount(String date, int count) async {
    final currentGoals = await getGoalsOnce();
    final updatedWaterIntake = Map<String, int>.from(currentGoals.waterIntake);
    updatedWaterIntake[date] = count;

    final updatedGoals = currentGoals.copyWith(waterIntake: updatedWaterIntake);
    await saveGoals(updatedGoals);
  }

  Future<int> incrementWater(String date, {int delta = 1}) async {
    final current = await getWaterCountForDate(date);
    final next = current + delta;
    await setWaterCount(date, next);
    return next;
  }

  Future<int> decrementWater(String date, {int delta = 1}) async {
    final current = await getWaterCountForDate(date);
    final next = current - delta;
    await setWaterCount(date, next < 0 ? 0 : next);
    return next;
  }
}
