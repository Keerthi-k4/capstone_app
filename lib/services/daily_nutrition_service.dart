import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'food_firestore_service.dart';
import 'user_goals_service.dart';
import 'health_connect_service.dart';
import '../models/health_data_model.dart';

class DailyNutrition {
  final int caloriesConsumed;
  final int caloriesBurned;
  final int caloriesRemaining;
  final int proteinConsumed;
  final int proteinTarget;
  final int proteinRemaining;
  final int carbsConsumed;
  final int carbsTarget;
  final int carbsRemaining;
  final int fatsConsumed;
  final int fatsTarget;
  final int fatsRemaining;
  final int fiberConsumed;
  final int fiberTarget;
  final int fiberRemaining;
  final int waterGlasses;
  final int waterTarget;
  final int steps;
  final int stepsTarget;
  final int exerciseMinutes;
  final int exerciseTarget;
  
  // Additional health metrics from Health Connect
  final int heartRate;
  final int restingHeartRate;
  final double oxygenSaturation; // SpO2 percentage
  final double sleepHours; // hours of sleep
  final double respiratoryRate;

  const DailyNutrition({
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.caloriesRemaining,
    required this.proteinConsumed,
    required this.proteinTarget,
    required this.proteinRemaining,
    required this.carbsConsumed,
    required this.carbsTarget,
    required this.carbsRemaining,
    required this.fatsConsumed,
    required this.fatsTarget,
    required this.fatsRemaining,
    required this.fiberConsumed,
    required this.fiberTarget,
    required this.fiberRemaining,
    required this.waterGlasses,
    required this.waterTarget,
    required this.steps,
    required this.stepsTarget,
    required this.exerciseMinutes,
    required this.exerciseTarget,
    this.heartRate = 0,
    this.restingHeartRate = 0,
    this.oxygenSaturation = 0.0,
    this.sleepHours = 0.0,
    this.respiratoryRate = 0.0,
  });

  bool get isCalorieDeficit => caloriesRemaining > 0;
  bool get isCalorieSurplus => caloriesRemaining < 0;
  double get calorieProgress =>
      (caloriesConsumed / (caloriesConsumed + caloriesBurned)).clamp(0.0, 1.0);
  double get proteinProgress =>
      (proteinConsumed / proteinTarget).clamp(0.0, 1.0);
  double get carbsProgress =>
      (carbsConsumed / carbsTarget).clamp(0.0, 1.0);
  double get fatsProgress =>
      (fatsConsumed / fatsTarget).clamp(0.0, 1.0);
  double get fiberProgress =>
      (fiberConsumed / fiberTarget).clamp(0.0, 1.0);
  double get waterProgress => (waterGlasses / waterTarget).clamp(0.0, 1.0);
  double get stepsProgress => (steps / stepsTarget).clamp(0.0, 1.0);
  double get exerciseProgress =>
      (exerciseMinutes / exerciseTarget).clamp(0.0, 1.0);
      
  /// Estimate stress level based on respiratory rate and heart rate
  int get stressLevel {
    if (respiratoryRate == 0 || heartRate == 0 || restingHeartRate == 0) {
      return 0;
    }
    final respiratoryStress = ((respiratoryRate - 16).abs() / 16 * 50).clamp(0, 50);
    final heartRateStress = restingHeartRate > 0 
        ? ((heartRate - restingHeartRate) / restingHeartRate * 50).clamp(0, 50)
        : 0;
    return (respiratoryStress + heartRateStress).round().clamp(0, 100);
  }
  
  String get stressDescription {
    final level = stressLevel;
    if (level == 0) return 'Unknown';
    if (level < 25) return 'Relaxed';
    if (level < 50) return 'Normal';
    if (level < 75) return 'Elevated';
    return 'High';
  }
}

class DailyNutritionService {
  final FoodFirestoreService _foodService = FoodFirestoreService();
  final UserGoalsService _goalsService = UserGoalsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HealthConnectService _healthConnectService = HealthConnectService();

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
    final carbsConsumed = _estimateCarbsFromLogs(foodLogs);
    final fatsConsumed = _estimateFatsFromLogs(foodLogs);
    final fiberConsumed = _estimateFiberFromLogs(foodLogs);

    // Get water intake
    final waterGlasses = await _goalsService.getWaterCountForDate(today);

    // Get activity data (steps, exercise) - placeholder for now
    final activityData = await _getTodayActivity(today);

    // Calculate calories burned (basic estimation)
    final caloriesBurned = _calculateCaloriesBurned(
        activityData['steps'] ?? 0, activityData['exerciseMinutes'] ?? 0);

    // Calculate remaining calories and macros
    final caloriesRemaining =
        goals.caloriesTarget - caloriesConsumed + caloriesBurned;
    final proteinRemaining = goals.proteinGramsTarget - proteinConsumed;
    final carbsRemaining = goals.carbsGramsTarget - carbsConsumed;
    final fatsRemaining = goals.fatsGramsTarget - fatsConsumed;
    final fiberRemaining = goals.fiberGramsTarget - fiberConsumed;

    return DailyNutrition(
      caloriesConsumed: caloriesConsumed,
      caloriesBurned: caloriesBurned,
      caloriesRemaining: caloriesRemaining,
      proteinConsumed: proteinConsumed,
      proteinTarget: goals.proteinGramsTarget,
      proteinRemaining: proteinRemaining,
      carbsConsumed: carbsConsumed,
      carbsTarget: goals.carbsGramsTarget,
      carbsRemaining: carbsRemaining,
      fatsConsumed: fatsConsumed,
      fatsTarget: goals.fatsGramsTarget,
      fatsRemaining: fatsRemaining,
      fiberConsumed: fiberConsumed,
      fiberTarget: goals.fiberGramsTarget,
      fiberRemaining: fiberRemaining,
      waterGlasses: waterGlasses,
      waterTarget: goals.waterGlassesTarget,
      steps: activityData['steps'] ?? 0,
      stepsTarget: goals.stepsTarget,
      exerciseMinutes: activityData['exerciseMinutes'] ?? 0,
      exerciseTarget: goals.exerciseMinutesTarget,
      // Health Connect metrics
      heartRate: activityData['heartRate'] ?? 0,
      restingHeartRate: activityData['restingHeartRate'] ?? 0,
      oxygenSaturation: (activityData['oxygenSaturation'] ?? 0.0).toDouble(),
      sleepHours: (activityData['sleepHours'] ?? 0.0).toDouble(),
      respiratoryRate: (activityData['respiratoryRate'] ?? 0.0).toDouble(),
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

  int _estimateCarbsFromLogs(List<FoodLog> logs) {
    // Estimate carbs from food logs (typically 45-65% of calories for carb-rich foods)
    int totalCarbs = 0;
    for (final log in logs) {
      final name = log.name.toLowerCase();
      if (name.contains('rice') || name.contains('pasta') || name.contains('noodle')) {
        totalCarbs += (log.calories * 0.55 / 4).round(); // ~55% calories from carbs, 4 cal/g
      } else if (name.contains('bread') || name.contains('roti') || name.contains('chapati')) {
        totalCarbs += (log.calories * 0.50 / 4).round();
      } else if (name.contains('fruit') || name.contains('banana') || name.contains('apple')) {
        totalCarbs += (log.calories * 0.90 / 4).round(); // Fruits are mostly carbs
      } else if (name.contains('potato') || name.contains('sweet potato')) {
        totalCarbs += (log.calories * 0.75 / 4).round();
      } else if (name.contains('dal') || name.contains('lentil') || name.contains('bean')) {
        totalCarbs += (log.calories * 0.45 / 4).round();
      } else {
        totalCarbs += (log.calories * 0.40 / 4).round(); // Default 40% carbs
      }
    }
    return totalCarbs;
  }

  int _estimateFatsFromLogs(List<FoodLog> logs) {
    // Estimate fats from food logs (typically 20-35% of calories for fatty foods)
    int totalFats = 0;
    for (final log in logs) {
      final name = log.name.toLowerCase();
      if (name.contains('oil') || name.contains('butter') || name.contains('ghee')) {
        totalFats += (log.calories * 0.95 / 9).round(); // Almost pure fat, 9 cal/g
      } else if (name.contains('nuts') || name.contains('almond') || name.contains('cashew')) {
        totalFats += (log.calories * 0.70 / 9).round();
      } else if (name.contains('avocado')) {
        totalFats += (log.calories * 0.75 / 9).round();
      } else if (name.contains('cheese') || name.contains('paneer')) {
        totalFats += (log.calories * 0.60 / 9).round();
      } else if (name.contains('fish') || name.contains('salmon')) {
        totalFats += (log.calories * 0.50 / 9).round();
      } else if (name.contains('chicken') || name.contains('meat')) {
        totalFats += (log.calories * 0.30 / 9).round();
      } else {
        totalFats += (log.calories * 0.25 / 9).round(); // Default 25% fats
      }
    }
    return totalFats;
  }

  int _estimateFiberFromLogs(List<FoodLog> logs) {
    // Estimate fiber from food logs (roughly based on food type)
    int totalFiber = 0;
    for (final log in logs) {
      final name = log.name.toLowerCase();
      if (name.contains('lentil') || name.contains('dal') || name.contains('bean')) {
        totalFiber += (log.calories * 0.03).round(); // High fiber
      } else if (name.contains('vegetable') || name.contains('broccoli') || name.contains('spinach')) {
        totalFiber += (log.calories * 0.08).round(); // Very high fiber per calorie
      } else if (name.contains('fruit') || name.contains('apple') || name.contains('banana')) {
        totalFiber += (log.calories * 0.02).round();
      } else if (name.contains('whole wheat') || name.contains('brown rice') || name.contains('oats')) {
        totalFiber += (log.calories * 0.025).round();
      } else if (name.contains('bread') || name.contains('roti') || name.contains('chapati')) {
        totalFiber += (log.calories * 0.015).round();
      } else {
        totalFiber += (log.calories * 0.01).round(); // Default low fiber
      }
    }
    return totalFiber;
  }

  Future<Map<String, dynamic>> _getTodayActivity(String date) async {
    try {
      // Use Health Connect service to get data
      // This will automatically handle demo mode vs actual mode
      final HealthData healthData = await _healthConnectService.getTodayHealthData();
      
      return {
        'steps': healthData.steps,
        'exerciseMinutes': healthData.exerciseMinutes,
        'heartRate': healthData.heartRate,
        'restingHeartRate': healthData.restingHeartRate,
        'oxygenSaturation': healthData.oxygenSaturation,
        'sleepHours': healthData.sleepHours,
        'respiratoryRate': healthData.respiratoryRate,
      };
    } catch (e) {
      print('Error fetching activity data from Health Connect: $e');
      // Fallback to zeros if there's an error
      return {
        'steps': 0,
        'exerciseMinutes': 0,
        'heartRate': 0,
        'restingHeartRate': 0,
        'distance': 0,
        'floorsClimbed': 0,
        'respiratoryRate': 0.0,
      };
    }
  }

  int _calculateCaloriesBurned(int steps, int exerciseMinutes) {
    // Basic calorie burn estimation
    final stepsCalories = (steps * 0.04).round(); // ~0.04 cal per step
    final exerciseCalories =
        exerciseMinutes * 8; // ~8 cal per minute of exercise
    return stepsCalories + exerciseCalories;
  }
}
