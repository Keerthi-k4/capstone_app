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
  final GoalPlan plan;

  const UserGoals({
    required this.caloriesTarget,
    required this.stepsTarget,
    required this.exerciseMinutesTarget,
    required this.waterGlassesTarget,
    required this.proteinGramsTarget,
    this.plan = GoalPlan.maintenance,
  });

  UserGoals copyWith({
    int? caloriesTarget,
    int? stepsTarget,
    int? exerciseMinutesTarget,
    int? waterGlassesTarget,
    int? proteinGramsTarget,
    GoalPlan? plan,
  }) {
    return UserGoals(
      caloriesTarget: caloriesTarget ?? this.caloriesTarget,
      stepsTarget: stepsTarget ?? this.stepsTarget,
      exerciseMinutesTarget:
          exerciseMinutesTarget ?? this.exerciseMinutesTarget,
      waterGlassesTarget: waterGlassesTarget ?? this.waterGlassesTarget,
      proteinGramsTarget: proteinGramsTarget ?? this.proteinGramsTarget,
      plan: plan ?? this.plan,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caloriesTarget': caloriesTarget,
      'stepsTarget': stepsTarget,
      'exerciseMinutesTarget': exerciseMinutesTarget,
      'waterGlassesTarget': waterGlassesTarget,
      'proteinGramsTarget': proteinGramsTarget,
      'plan': describeEnum(plan),
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
      'plan': describeEnum(plan),
    };
  }

  factory UserGoals.fromMap(Map<String, dynamic> map) {
    return UserGoals(
      caloriesTarget: (map['caloriesTarget'] ?? 2400) as int,
      stepsTarget: (map['stepsTarget'] ?? 10000) as int,
      exerciseMinutesTarget: (map['exerciseMinutesTarget'] ?? 30) as int,
      waterGlassesTarget: (map['waterGlassesTarget'] ?? 8) as int,
      proteinGramsTarget: (map['proteinGramsTarget'] ?? 60) as int,
      plan: _planFromString(map['plan'] as String?),
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
          stepsTarget: 10000,
          exerciseMinutesTarget: 35,
          waterGlassesTarget: 8,
        );
      case GoalPlan.muscleBuilding:
        return (base ?? UserGoals.defaults).copyWith(
          plan: GoalPlan.muscleBuilding,
          caloriesTarget: 2800,
          proteinGramsTarget: 120,
          stepsTarget: 8000,
          exerciseMinutesTarget: 45,
          waterGlassesTarget: 10,
        );
      case GoalPlan.maintenance:
        return (base ?? UserGoals.defaults).copyWith(
          plan: GoalPlan.maintenance,
          caloriesTarget: 2400,
          proteinGramsTarget: 80,
          stepsTarget: 9000,
          exerciseMinutesTarget: 30,
          waterGlassesTarget: 8,
        );
      case GoalPlan.custom:
        return (base ?? UserGoals.defaults).copyWith(plan: GoalPlan.custom);
    }
  }
}
