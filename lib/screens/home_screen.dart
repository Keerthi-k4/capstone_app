import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attempt2/providers/auth_provider.dart';
import 'package:attempt2/models/user_model.dart';
import 'food_tracking_screen_new.dart';
import 'diet_plan_screen.dart';
import 'goals_screen.dart';
import 'package:attempt2/services/user_goals_service.dart';
import 'package:attempt2/services/water_service.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final UserGoalsService _goalsService = UserGoalsService();
  UserGoals _goals = UserGoals.defaults;
  final WaterService _waterService = WaterService();
  int _todayWater = 0;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadWater();
  }

  Future<void> _loadGoals() async {
    final g = await _goalsService.getGoalsOnce();
    if (mounted) {
      setState(() => _goals = g);
    }
  }

  Future<void> _loadWater() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final c = await _waterService.getCountForDate(today);
    if (mounted) setState(() => _todayWater = c);
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
                    await _waterService.setCount(today, newCount);
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'BMI',
                            user.bmi?.toStringAsFixed(1) ?? 'N/A',
                            user.bmiCategory,
                          ),
                          _buildStatItem(
                            'Weight',
                            user.weight != null
                                ? '${user.weight} kg'
                                : 'Not set',
                            'Tap to update',
                          ),
                          _buildStatItem(
                            'Height',
                            user.height != null
                                ? '${user.height} cm'
                                : 'Not set',
                            'Tap to update',
                          ),
                        ],
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
                      'Track Exercise',
                      Icons.fitness_center,
                      Colors.blue,
                      () {
                        // TODO: Navigate to exercise tracking screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Exercise tracking coming soon!'),
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
                        // TODO: Navigate to profile screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile screen coming soon!'),
                          ),
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
                                progress: 1320 /
                                    (_goals.caloriesTarget == 0
                                            ? 1
                                            : _goals.caloriesTarget)
                                        .clamp(1, 100000),
                                color: Colors.pink,
                                strokeWidth: 18,
                              ),
                            ),
                            // Steps Ring (middle)
                            CustomPaint(
                              size: const Size(160, 160),
                              painter: ActivityRingPainter(
                                progress: 4200 /
                                    (_goals.stepsTarget == 0
                                            ? 1
                                            : _goals.stepsTarget)
                                        .clamp(1, 100000),
                                color: Colors.green,
                                strokeWidth: 18,
                              ),
                            ),
                            // Exercise Ring (innermost)
                            CustomPaint(
                              size: const Size(120, 120),
                              painter: ActivityRingPainter(
                                progress: 10 /
                                    (_goals.exerciseMinutesTarget == 0
                                            ? 1
                                            : _goals.exerciseMinutesTarget)
                                        .clamp(1, 100000),
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
                                  '1,320',
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
                            '1,320',
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
                            '4,200',
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
                            '10',
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

              // Additional Goals
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
                      '45',
                      '${_goals.proteinGramsTarget}g',
                      (45 /
                              (_goals.proteinGramsTarget == 0
                                  ? 1
                                  : _goals.proteinGramsTarget))
                          .clamp(0.0, 1.0),
                      Colors.orange,
                      Icons.egg,
                    ),
                  ),
                ],
              ),
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
                    } else {
                      await _loadGoals();
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
