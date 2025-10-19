import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'food_firestore_service.dart';
import 'user_goals_service.dart';

class DailyNutrition {
  final int caloriesConsumed;
  final int caloriesBurned;
  final int caloriesRemaining;
  final int proteinConsumed;
  final int proteinTarget;
  final int proteinRemaining;
  final int waterGlasses;
  final int waterTarget;
  final int steps;
  final int stepsTarget;
  final int exerciseMinutes;
  final int exerciseTarget;

  const DailyNutrition({
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.caloriesRemaining,
    required this.proteinConsumed,
    required this.proteinTarget,
    required this.proteinRemaining,
    required this.waterGlasses,
    required this.waterTarget,
    required this.steps,
    required this.stepsTarget,
    required this.exerciseMinutes,
    required this.exerciseTarget,
  });

  bool get isCalorieDeficit => caloriesRemaining > 0;
  bool get isCalorieSurplus => caloriesRemaining < 0;
  double get calorieProgress =>
      (caloriesConsumed / (caloriesConsumed + caloriesBurned)).clamp(0.0, 1.0);
  double get proteinProgress =>
      (proteinConsumed / proteinTarget).clamp(0.0, 1.0);
  double get waterProgress => (waterGlasses / waterTarget).clamp(0.0, 1.0);
  double get stepsProgress => (steps / stepsTarget).clamp(0.0, 1.0);
  double get exerciseProgress =>
      (exerciseMinutes / exerciseTarget).clamp(0.0, 1.0);
}

class DailyNutritionService {
  final FoodFirestoreService _foodService = FoodFirestoreService();
  final UserGoalsService _goalsService = UserGoalsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  bool get _isAuth => _uid != null;

  CollectionReference<Map<String, dynamic>> get _stepsCol =>
      FirebaseFirestore.instance.collection('daily_activity');

  Future<DailyNutrition> getTodayNutrition() async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Get goals
    final goals = await _goalsService.getGoalsOnce();

    // Get food logs for today
    final foodLogs = await _foodService.getLogsByDate(today);
    final caloriesConsumed = foodLogs.fold(0, (sum, log) => sum + log.calories);
    final proteinConsumed = _estimateProteinFromLogs(foodLogs);

    // Get water intake
    final waterGlasses = await _goalsService.getWaterCountForDate(today);

    // Get activity data (steps, exercise) - placeholder for now
    final activityData = await _getTodayActivity(today);

    // Calculate calories burned (basic estimation)
    final caloriesBurned = _calculateCaloriesBurned(
        activityData['steps'] ?? 0, activityData['exerciseMinutes'] ?? 0);

    // Calculate remaining calories
    final caloriesRemaining =
        goals.caloriesTarget - caloriesConsumed + caloriesBurned;
    final proteinRemaining = goals.proteinGramsTarget - proteinConsumed;

    return DailyNutrition(
      caloriesConsumed: caloriesConsumed,
      caloriesBurned: caloriesBurned,
      caloriesRemaining: caloriesRemaining,
      proteinConsumed: proteinConsumed,
      proteinTarget: goals.proteinGramsTarget,
      proteinRemaining: proteinRemaining,
      waterGlasses: waterGlasses,
      waterTarget: goals.waterGlassesTarget,
      steps: activityData['steps'] ?? 0,
      stepsTarget: goals.stepsTarget,
      exerciseMinutes: activityData['exerciseMinutes'] ?? 0,
      exerciseTarget: goals.exerciseMinutesTarget,
    );
  }

  Stream<DailyNutrition> getTodayNutritionStream() {
    return Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => getTodayNutrition());
  }

  int _estimateProteinFromLogs(List<FoodLog> logs) {
    // Simple protein estimation based on food names
    int totalProtein = 0;
    for (final log in logs) {
      final name = log.name.toLowerCase();
      if (name.contains('chicken') || name.contains('poultry')) {
        totalProtein += (log.calories * 0.25).round(); // ~25% protein
      } else if (name.contains('fish') ||
          name.contains('salmon') ||
          name.contains('tuna')) {
        totalProtein += (log.calories * 0.22).round(); // ~22% protein
      } else if (name.contains('egg')) {
        totalProtein += (log.calories * 0.35).round(); // ~35% protein
      } else if (name.contains('dal') ||
          name.contains('lentil') ||
          name.contains('bean')) {
        totalProtein += (log.calories * 0.20).round(); // ~20% protein
      } else if (name.contains('paneer') || name.contains('cheese')) {
        totalProtein += (log.calories * 0.25).round(); // ~25% protein
      } else if (name.contains('milk') || name.contains('yogurt')) {
        totalProtein += (log.calories * 0.15).round(); // ~15% protein
      } else if (name.contains('rice') ||
          name.contains('bread') ||
          name.contains('roti')) {
        totalProtein += (log.calories * 0.08).round(); // ~8% protein
      } else {
        totalProtein += (log.calories * 0.10).round(); // ~10% default
      }
    }
    return totalProtein;
  }

  Future<Map<String, int>> _getTodayActivity(String date) async {
    if (!_isAuth) {
      // Return mock data for demo
      return {'steps': 4200, 'exerciseMinutes': 10};
    }

    try {
      final snap = await _stepsCol
          .where('userId', isEqualTo: _uid)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        return {
          'steps': data['steps'] ?? 0,
          'exerciseMinutes': data['exerciseMinutes'] ?? 0,
        };
      }
    } catch (e) {
      print('Error fetching activity data: $e');
    }

    return {'steps': 0, 'exerciseMinutes': 0};
  }

  int _calculateCaloriesBurned(int steps, int exerciseMinutes) {
    // Basic calorie burn estimation
    final stepsCalories = (steps * 0.04).round(); // ~0.04 cal per step
    final exerciseCalories =
        exerciseMinutes * 8; // ~8 cal per minute of exercise
    return stepsCalories + exerciseCalories;
  }
}
