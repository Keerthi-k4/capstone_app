import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attempt2/providers/auth_provider.dart';
import 'package:attempt2/models/user_model.dart';
import 'food_tracking_screen_new.dart';
import 'diet_plan_screen.dart';
import 'goals_screen.dart';
import 'package:attempt2/services/user_goals_service.dart';
import 'package:attempt2/services/daily_nutrition_service.dart';
import 'package:attempt2/services/health_connect_service.dart';
import 'package:attempt2/services/food_firestore_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final UserGoalsService _goalsService = UserGoalsService();
  UserGoals _goals = UserGoals.defaults;
  final DailyNutritionService _nutritionService = DailyNutritionService();
  final HealthConnectService _healthConnectService = HealthConnectService();
  final FoodFirestoreService _foodService = FoodFirestoreService();
  int _todayWater = 0;
  DailyNutrition? _todayNutrition;
  bool _isDemoMode = true; // Default to demo mode
  StreamSubscription<List<FoodLog>>? _foodLogsSub;
  Timer? _midnightTimer;
  String _todayDateStr = DateTime.now().toIso8601String().split('T')[0];
  int _todayCalories = 0;
  double _todayProtein = 0;
  double _todayCarbs = 0;
  double _todayFats = 0;
  double _todayFiber = 0;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadWater();
    _loadNutrition();
    _loadHealthMode();
    _subscribeToTodayFoodLogs();
    _scheduleMidnightReset();
  }

  void _subscribeToTodayFoodLogs() {
    _foodLogsSub?.cancel();
    _foodLogsSub =
        _foodService.getLogsByDateStream(_todayDateStr).listen((logs) {
      int calories = 0;
      double protein = 0;
      double carbs = 0;
      double fats = 0;
      double fiber = 0;
      for (final log in logs) {
        calories += log.calories;
        protein += log.protein;
        carbs += log.carbs;
        fats += log.fat;
        fiber += log.fiber;
      }
      if (mounted) {
        setState(() {
          _todayCalories = calories;
          _todayProtein = protein;
          _todayCarbs = carbs;
          _todayFats = fats;
          _todayFiber = fiber;
        });
      }
    });
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 1),
    );
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, _onDateChangedToToday);
  }

  void _onDateChangedToToday() {
    _todayDateStr = DateTime.now().toIso8601String().split('T')[0];
    if (mounted) {
      setState(() {
        _todayCalories = 0;
        _todayProtein = 0;
        _todayCarbs = 0;
        _todayFats = 0;
        _todayFiber = 0;
      });
    }
    _subscribeToTodayFoodLogs();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _foodLogsSub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHealthMode() async {
    final isDemo = await _healthConnectService.isDemoMode();
    if (mounted) setState(() => _isDemoMode = isDemo);
  }

  Future<void> _loadGoals() async {
    final g = await _goalsService.getGoalsOnce();
    if (mounted) {
      setState(() => _goals = g);
    }
  }

  Future<void> _loadWater() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final c = await _goalsService.getWaterCountForDate(today);
    if (mounted) setState(() => _todayWater = c);
  }

  Future<void> _loadNutrition() async {
    final nutrition = await _nutritionService.getTodayNutrition();
    if (mounted) setState(() => _todayNutrition = nutrition);
  }

  Future<void> _showModeToggleDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Health Data Mode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose how to track your activity:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading:
                    const Icon(Icons.science_outlined, color: Colors.orange),
                title: const Text('Demo Mode'),
                subtitle: const Text('Uses hardcoded sample data'),
                selected: _isDemoMode,
                selectedTileColor: Colors.orange.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.watch_outlined, color: Colors.green),
                title: const Text('Actual Mode'),
                subtitle: const Text('Uses Health Connect & Wear OS'),
                selected: !_isDemoMode,
                selectedTileColor: Colors.green.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      // Update mode
      await _healthConnectService.setDemoMode(result);

      if (!result) {
        // Switching to actual mode - check availability and permissions
        final isAvailable =
            await _healthConnectService.isHealthConnectAvailable();
        if (!isAvailable) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Health Connect not available on this device. Install from Play Store.',
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          // Revert to demo mode
          await _healthConnectService.setDemoMode(true);
          if (mounted) setState(() => _isDemoMode = true);
          return;
        }

        final hasPermissions = await _healthConnectService.hasPermissions();
        if (!hasPermissions) {
          if (mounted) {
            final requestPermissions = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Permissions Required'),
                content: const Text(
                  'Health Connect needs permissions to read your activity data.\n\n'
                  'You\'ll be taken to Health Connect settings where you can grant permissions for:\n'
                  '• Steps\n'
                  '• Heart Rate & Resting Heart Rate\n'
                  '• Calories Burned (Active & Total)\n'
                  '• Exercise Sessions\n'
                  '• Oxygen Saturation (SpO2)\n'
                  '• Sleep\n'
                  '• Respiratory Rate (for stress assessment)\n\n'
                  'After granting permissions, return to the app.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );

            if (requestPermissions == true) {
              final granted = await _healthConnectService.requestPermissions();
              if (!granted) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Permissions not granted. Using demo mode.',
                      ),
                    ),
                  );
                }
                // Revert to demo mode
                await _healthConnectService.setDemoMode(true);
                if (mounted) setState(() => _isDemoMode = true);
                return;
              }
            } else {
              // User cancelled permission request, revert to demo mode
              await _healthConnectService.setDemoMode(true);
              if (mounted) setState(() => _isDemoMode = true);
              return;
            }
          }
        }
      }

      // Update state and reload data
      if (mounted) {
        setState(() => _isDemoMode = result);
        await _loadNutrition();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result ? 'Switched to Demo Mode' : 'Switched to Actual Mode',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openWaterEditor() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final countCtrl = TextEditingController(text: '$_todayWater');
    final targetCtrl =
        TextEditingController(text: '${_goals.waterGlassesTarget}');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Water intake',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: countCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Glasses today',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      final v = (int.tryParse(countCtrl.text) ?? 0) - 1;
                      countCtrl.text = v < 0 ? '0' : '$v';
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final v = (int.tryParse(countCtrl.text) ?? 0) + 1;
                      countCtrl.text = '$v';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily target (glasses)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final newCount =
                        int.tryParse(countCtrl.text) ?? _todayWater;
                    final newTarget = int.tryParse(targetCtrl.text) ??
                        _goals.waterGlassesTarget;
                    await _goalsService.setWaterCount(today, newCount);
                    final updatedGoals =
                        _goals.copyWith(waterGlassesTarget: newTarget);
                    await _goalsService.saveGoals(updatedGoals);
                    if (mounted) {
                      setState(() {
                        _todayWater = newCount;
                        _goals = updatedGoals;
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final UserModel? user = authProvider.currentUser;

    // Show a loading indicator if user data is not available
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet & Fitness App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await authProvider.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: user.photoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Image.network(
                                      user.photoUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Your Stats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream:
                            fb_auth.FirebaseAuth.instance.currentUser == null
                                ? const Stream.empty()
                                : FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(fb_auth
                                        .FirebaseAuth.instance.currentUser!.uid)
                                    .snapshots(),
                        builder: (context, snapshot) {
                          final data = snapshot.data?.data();
                          final double? weightKg = (data?['weight'] is num)
                              ? (data!['weight'] as num).toDouble()
                              : user.weight?.toDouble();
                          final double? heightCm = (data?['height'] is num)
                              ? (data!['height'] as num).toDouble()
                              : user.height?.toDouble();
                          final double? bmiFromDoc = (data?['bmi'] is num)
                              ? (data!['bmi'] as num).toDouble()
                              : user.bmi;

                          double? bmi = bmiFromDoc;
                          if (bmi == null &&
                              weightKg != null &&
                              heightCm != null &&
                              heightCm > 0) {
                            final heightM = heightCm / 100.0;
                            bmi = weightKg / (heightM * heightM);
                          }

                          String bmiCategory = user.bmiCategory;
                          if (bmi != null) {
                            if (bmi < 18.5) {
                              bmiCategory = 'Underweight';
                            } else if (bmi < 25) {
                              bmiCategory = 'Normal';
                            } else if (bmi < 30) {
                              bmiCategory = 'Overweight';
                            } else {
                              bmiCategory = 'Obese';
                            }
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                  'BMI',
                                  bmi != null ? bmi.toStringAsFixed(1) : 'N/A',
                                  bmi != null ? bmiCategory : 'Tap to update'),
                              _buildStatItem(
                                'Weight',
                                weightKg != null
                                    ? '${weightKg.toStringAsFixed(1)} kg'
                                    : 'Not set',
                                'Tap to update',
                              ),
                              _buildStatItem(
                                'Height',
                                heightCm != null
                                    ? '${heightCm.toStringAsFixed(0)} cm'
                                    : 'Not set',
                                'Tap to update',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick actions section
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Track Food',
                      Icons.restaurant,
                      Colors.orange,
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FoodTrackingScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Diet Plans',
                      Icons.calendar_today,
                      Colors.green,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DietPlansScreen(
                              date: DateTime.now()
                                  .toString()
                                  .split(' ')[0], // today's date in YYYY-MM-DD
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Plan Exercise',
                      Icons.fitness_center,
                      Colors.blue,
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ExerciseTrackingScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Profile',
                      Icons.person,
                      Colors.purple,
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Activity Summary Section
              Text(
                "Today's Activity",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Activity Rings Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Activity Rings
                      SizedBox(
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Calories Ring (outermost)
                            CustomPaint(
                              size: const Size(200, 200),
                              painter: ActivityRingPainter(
                                progress: _goals.caloriesTarget == 0
                                    ? 0.0
                                    : (_todayCalories / _goals.caloriesTarget)
                                        .clamp(0.0, 1.0),
                                color: Colors.pink,
                                strokeWidth: 18,
                              ),
                            ),
                            // Steps Ring (middle)
                            CustomPaint(
                              size: const Size(160, 160),
                              painter: ActivityRingPainter(
                                progress: _todayNutrition != null
                                    ? _todayNutrition!.stepsProgress
                                    : 0.0,
                                color: Colors.green,
                                strokeWidth: 18,
                              ),
                            ),
                            // Exercise Ring (innermost)
                            CustomPaint(
                              size: const Size(120, 120),
                              painter: ActivityRingPainter(
                                progress: _todayNutrition != null
                                    ? _todayNutrition!.exerciseProgress
                                    : 0.0,
                                color: Colors.cyan,
                                strokeWidth: 18,
                              ),
                            ),
                            // Center text
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  color: Colors.orange,
                                  size: 32,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_todayCalories',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                Text(
                                  'kcal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stats Grid
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActivityStat(
                            'Calories',
                            '$_todayCalories',
                            '${_goals.caloriesTarget}',
                            Colors.pink,
                            Icons.local_fire_department,
                          ),
                          Container(
                            height: 60,
                            width: 1,
                            color: Colors.grey[300],
                          ),
                          _buildActivityStat(
                            'Steps',
                            _todayNutrition != null
                                ? '${_todayNutrition!.steps}'
                                : '0',
                            '${_goals.stepsTarget}',
                            Colors.green,
                            Icons.directions_walk,
                          ),
                          Container(
                            height: 60,
                            width: 1,
                            color: Colors.grey[300],
                          ),
                          _buildActivityStat(
                            'Exercise',
                            _todayNutrition != null
                                ? '${_todayNutrition!.exerciseMinutes}'
                                : '0',
                            '${_goals.exerciseMinutesTarget} min',
                            Colors.cyan,
                            Icons.fitness_center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Demo/Actual Mode Toggle Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(_isDemoMode
                      ? Icons.science_outlined
                      : Icons.watch_outlined),
                  label: Text(_isDemoMode ? 'Demo Mode' : 'Actual Mode'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isDemoMode ? Colors.orange : Colors.green,
                    side: BorderSide(
                      color: _isDemoMode ? Colors.orange : Colors.green,
                    ),
                  ),
                  onPressed: () async {
                    await _showModeToggleDialog();
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Additional Health Metrics from Health Connect
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Health Metrics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // First row: Heart Rate and SpO2
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.favorite,
                              iconColor: Colors.red,
                              label: 'Heart Rate',
                              value: _todayNutrition != null &&
                                      _todayNutrition!.heartRate > 0
                                  ? '${_todayNutrition!.heartRate}'
                                  : '--',
                              unit: 'bpm',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.water_drop,
                              iconColor: Colors.blue,
                              label: 'SpO2',
                              value: _todayNutrition != null &&
                                      _todayNutrition!.oxygenSaturation > 0
                                  ? _todayNutrition!.oxygenSaturation
                                      .toStringAsFixed(1)
                                  : '--',
                              unit: '%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Second row: Sleep and Stress
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.bedtime,
                              iconColor: Colors.purple,
                              label: 'Sleep',
                              value: _todayNutrition != null &&
                                      _todayNutrition!.sleepHours > 0
                                  ? _todayNutrition!.sleepHours
                                      .toStringAsFixed(1)
                                  : '--',
                              unit: 'hours',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.psychology,
                              iconColor: _todayNutrition != null
                                  ? (_todayNutrition!.stressLevel < 25
                                      ? Colors.green
                                      : _todayNutrition!.stressLevel < 50
                                          ? Colors.blue
                                          : _todayNutrition!.stressLevel < 75
                                              ? Colors.orange
                                              : Colors.red)
                                  : Colors.grey,
                              label: 'Stress',
                              value: _todayNutrition != null &&
                                      _todayNutrition!.stressLevel > 0
                                  ? _todayNutrition!.stressDescription
                                  : '--',
                              unit: '',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Additional Goals - Row 1: Water and Protein
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _openWaterEditor,
                      child: _buildGoalCard(
                        'Water',
                        '$_todayWater',
                        '${_goals.waterGlassesTarget} glasses',
                        (_todayWater /
                                (_goals.waterGlassesTarget == 0
                                    ? 1
                                    : _goals.waterGlassesTarget))
                            .clamp(0.0, 1.0),
                        Colors.blue,
                        Icons.local_drink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGoalCard(
                      'Protein',
                      '${_todayProtein.round()}',
                      '${_goals.proteinGramsTarget}g',
                      _goals.proteinGramsTarget == 0
                          ? 0.0
                          : (_todayProtein / _goals.proteinGramsTarget)
                              .clamp(0.0, 1.0),
                      Colors.orange,
                      Icons.egg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Macros - Row 2: Carbs and Fats
              Row(
                children: [
                  Expanded(
                    child: _buildGoalCard(
                      'Carbs',
                      '${_todayCarbs.round()}',
                      '${_goals.carbsGramsTarget}g',
                      _goals.carbsGramsTarget == 0
                          ? 0.0
                          : (_todayCarbs / _goals.carbsGramsTarget)
                              .clamp(0.0, 1.0),
                      Colors.amber[700]!,
                      Icons.grain,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGoalCard(
                      'Fats',
                      '${_todayFats.round()}',
                      '${_goals.fatsGramsTarget}g',
                      _goals.fatsGramsTarget == 0
                          ? 0.0
                          : (_todayFats / _goals.fatsGramsTarget)
                              .clamp(0.0, 1.0),
                      Colors.yellow[800]!,
                      Icons.oil_barrel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Macros - Row 3: Fiber
              Row(
                children: [
                  Expanded(
                    child: _buildGoalCard(
                      'Fiber',
                      '${_todayFiber.round()}',
                      '${_goals.fiberGramsTarget}g',
                      _goals.fiberGramsTarget == 0
                          ? 0.0
                          : (_todayFiber / _goals.fiberGramsTarget)
                              .clamp(0.0, 1.0),
                      Colors.green[700]!,
                      Icons.grass,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Empty space for symmetry
                  Expanded(child: Container()),
                ],
              ),
              const SizedBox(height: 16),

              // Calorie Balance Meter
              // Calorie Balance Meter
              if (_goals.caloriesTarget > 0) _buildCalorieBalanceMeter(),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.flag),
                  label: const Text('Edit goals'),
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GoalsScreen()),
                    );
                    if (result is UserGoals) {
                      setState(() => _goals = result);
                      await _loadNutrition(); // Refresh nutrition data
                    } else {
                      await _loadGoals();
                      await _loadNutrition();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Show a message since these features are not implemented yet
          if (index != 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This feature is coming soon!')),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Diet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Exercise',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Progress',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityStat(
    String label,
    String current,
    String goal,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            current,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'of $goal',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    String title,
    String current,
    String goal,
    double progress,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  current,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'of $goal',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieBalanceMeter() {
    final int target = _goals.caloriesTarget;
    final int consumed = _todayCalories;
    final int balance = target - consumed;
    final bool isDeficit = balance > 0;
    final int balanceValue = balance.abs();
    final double maxValue = target.toDouble().clamp(1.0, 4000.0);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Calorie Balance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),

            // Semi-circular gauge
            SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gauge background
                  CustomPaint(
                    size: const Size(200, 120),
                    painter: CalorieGaugePainter(
                      deficitValue: isDeficit ? balanceValue.toDouble() : 0.0,
                      surplusValue: !isDeficit ? balanceValue.toDouble() : 0.0,
                      maxValue: maxValue,
                    ),
                  ),

                  // Center value and icon
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        '${isDeficit ? '-' : '+'}$balanceValue',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDeficit ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: $target\nConsumed: $consumed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Deficit/Surplus labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Deficit',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Surplus',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for Activity Rings
class ActivityRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  ActivityRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle (gray)
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(ActivityRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class CalorieGaugePainter extends CustomPainter {
  final double deficitValue;
  final double surplusValue;
  final double maxValue;

  CalorieGaugePainter({
    required this.deficitValue,
    required this.surplusValue,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    // Background arc (light gray)
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw background arc (semi-circle)
    canvas.drawArc(
      rect,
      math.pi, // start angle: 180 degrees (leftmost)
      math.pi, // sweep 180 degrees
      false,
      backgroundPaint,
    );

    // --- Deficit section (left side, green) ---
    if (deficitValue > 0) {
      final progress = (deficitValue / maxValue).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Colors.green.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      // Start from left (π) and move clockwise toward center
      canvas.drawArc(
        rect,
        math.pi, // leftmost
        math.pi / 2 * progress, // up to halfway
        false,
        paint,
      );
    }

    // --- Surplus section (right side, orange) ---
    if (surplusValue > 0) {
      final progress = (surplusValue / maxValue).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Colors.orange.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      // Start from center (3π/2) and move clockwise to rightmost
      canvas.drawArc(
        rect,
        1.5 * math.pi, // middle of the gauge
        math.pi / 2 * progress, // right side arc
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CalorieGaugePainter oldDelegate) {
    return oldDelegate.deficitValue != deficitValue ||
        oldDelegate.surplusValue != surplusValue ||
        oldDelegate.maxValue != maxValue;
  }
}
