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
    final proteinConsumed = foodLogs.fold(0.0, (sum, log) => sum + log.protein).round();
    final carbsConsumed = foodLogs.fold(0.0, (sum, log) => sum + log.carbs).round();
    final fatsConsumed = foodLogs.fold(0.0, (sum, log) => sum + log.fat).round();
    final fiberConsumed = foodLogs.fold(0.0, (sum, log) => sum + log.fiber).round();

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
