/*
File: lib/screens/food_tracking_screen.dart
*/
import 'package:flutter/material.dart';
import '../services/food_db_helper.dart';

class FoodTrackingScreen extends StatefulWidget {
  const FoodTrackingScreen({super.key});

  @override
  State<FoodTrackingScreen> createState() => _FoodTrackingScreenState();
}

class _FoodTrackingScreenState extends State<FoodTrackingScreen> {
  final _foodController = TextEditingController();
  final FoodDBHelper _dbHelper = FoodDBHelper();
  List<FoodLog> _todayLogs = [];
  late String _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now().toIso8601String().split('T').first;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _dbHelper.getLogsByDate(_today);
    setState(() {
      _todayLogs = logs;
    });
  }

  Future<void> _logTextFood(String foodName) async {
    if (foodName.trim().isEmpty) return;
    final log = FoodLog(
      name: foodName.trim(),
      calories: 0, // placeholder, set actual calories later
      mealType: 'unspecified',
      date: _today,
    );
    await _dbHelper.insertLog(log);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged: ${foodName.trim()}')),
    );
    _foodController.clear();
    await _loadLogs();
  }

  Future<void> _logWithCamera() async {
    // TODO: integrate QR/image scanning to get foodName
    String scannedFood = 'Scanned Food';
    await _logTextFood(scannedFood);
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Your Food'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _foodController,
                    decoration: const InputDecoration(
                      labelText: 'What did you eat?',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _logTextFood,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.camera_alt, size: 32),
                  onPressed: _logWithCamera,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _todayLogs.isEmpty
                  ? const Center(child: Text('No logs for today.'))
                  : ListView.builder(
                      itemCount: _todayLogs.length,
                      itemBuilder: (context, index) {
                        final log = _todayLogs[index];
                        return ListTile(
                          title: Text(log.name),
                          subtitle: Text(
                            'Calories: ${log.calories} · Meal: ${log.mealType}',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
