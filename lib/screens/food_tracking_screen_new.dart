/*
File: lib/screens/food_tracking_screen.dart
*/
import 'package:flutter/material.dart';
import 'dart:io';
import '../services/food_firestore_service.dart';
import '../services/image_capture_service.dart';
import '../services/ml_food_recognition_service.dart';
import 'food_confirmation_screen.dart';
import 'manual_food_search_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FoodTrackingScreen extends StatefulWidget {
  const FoodTrackingScreen({super.key});

  @override
  State<FoodTrackingScreen> createState() => _FoodTrackingScreenState();
}

class _FoodTrackingScreenState extends State<FoodTrackingScreen> {
  final FoodFirestoreService _firestoreService = FoodFirestoreService();
  final ImageCaptureService _imageService = ImageCaptureService();
  final MLFoodRecognitionService _mlService = MLFoodRecognitionService();

  List<FoodLog> _todayLogs = [];
  late String _today;
  bool _isServerHealthy = false;
  bool _checkingServer = false;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now().toIso8601String().split('T').first;
    _loadLogs();
    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    setState(() => _checkingServer = true);
    try {
      final isHealthy = await _mlService.isServerHealthy();
      setState(() => _isServerHealthy = isHealthy);
    } catch (e) {
      setState(() => _isServerHealthy = false);
    } finally {
      setState(() => _checkingServer = false);
    }
  }

  Future<void> _loadLogs() async {
    final logs = await _firestoreService.getLogsByDate(_today);
    setState(() {
      _todayLogs = logs;
    });
  }

  Future<void> _navigateToManualSearch() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const ManualFoodSearchScreen(),
      ),
    );

    if (result == true) {
      _loadLogs(); // Refresh the logs
    }
  }

  Future<void> _captureAndRecognizeFood() async {
    if (!_isServerHealthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'ML server is not available. Please try manual search instead.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Capture image
      final imageFile = await _imageService.selectImageSource(context);

      if (imageFile != null) {
        // Show processing dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing food image...'),
              ],
            ),
          ),
        );

        // Get ML predictions
        final mlResponse = await _mlService.predictFoodWithNutrition(imageFile);

        // Close processing dialog
        Navigator.of(context).pop();

        if (mlResponse.success && mlResponse.predictions.isNotEmpty) {
          // Navigate to confirmation screen
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => FoodConfirmationScreen(
                imageFile: imageFile,
                mlResponse: mlResponse,
              ),
            ),
          );

          if (result == true) {
            _loadLogs(); // Refresh the logs
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  mlResponse.error ?? 'Could not recognize food in the image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close any open dialogs
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Your Food'),
        actions: [
          IconButton(
            icon: Icon(
              _isServerHealthy ? Icons.cloud_done : Icons.cloud_off,
              color: _isServerHealthy ? Colors.green : Colors.red,
            ),
            onPressed: _checkServerHealth,
            tooltip:
                _isServerHealthy ? 'ML Server Online' : 'ML Server Offline',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Action buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Food',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _navigateToManualSearch,
                            icon: const Icon(Icons.search),
                            label: const Text('Search Food'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _captureAndRecognizeFood,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor:
                                  _isServerHealthy ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_isServerHealthy && !_checkingServer)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Note: Photo recognition requires ML server connection',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Today's logs header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Food Log',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_todayLogs.isNotEmpty)
                  Text(
                    '${_todayLogs.length} items',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Today's logs list
            Expanded(
              child: _todayLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No food logged today',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by searching for food or taking a photo',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _todayLogs.length,
                      itemBuilder: (context, index) {
                        final log = _todayLogs[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getMealTypeColor(log.mealType),
                              child: Icon(
                                _getMealTypeIcon(log.mealType),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(log.name),
                            subtitle: Text(
                              'Calories: ${log.calories} · Meal: ${log.mealType}',
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteLog(log);
                                }
                                // TODO: Implement edit functionality
                              },
                            ),
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

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      case 'snack':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny;
      case 'lunch':
        return Icons.wb_sunny_outlined;
      case 'dinner':
        return Icons.nightlight_round;
      case 'snack':
        return Icons.local_cafe;
      default:
        return Icons.restaurant;
    }
  }

  Future<void> _deleteLog(FoodLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Food Log'),
        content: Text('Are you sure you want to delete "${log.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement delete functionality in FoodDBHelper
      // await _dbHelper.deleteLog(log.id!);
      _loadLogs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${log.name}"')),
      );
    }
  }
}

class ExerciseTrackingScreen extends StatefulWidget {
  const ExerciseTrackingScreen({Key? key}) : super(key: key);

  @override
  State<ExerciseTrackingScreen> createState() => _ExerciseTrackingScreenState();
}

class _ExerciseTrackingScreenState extends State<ExerciseTrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _muscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Legs', 'Abs', 'Glutes', 'Other'
  ];
  List<String> _selectedMuscleGroups = [];
  String? _workoutType; // 'Weights' or 'Bodyweight'
  final _durationController = TextEditingController();
  String? _workoutPlanResult;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Exercise'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 600),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Muscle Group(s)',
                                border: OutlineInputBorder(),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  hint: const Text('Select muscle group'),
                                  value: null,
                                  items: _muscleGroups
                                      .where((mg) => !_selectedMuscleGroups.contains(mg))
                                      .map((group) => DropdownMenuItem(
                                            value: group,
                                            child: Text(group),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null && !_selectedMuscleGroups.contains(val)) {
                                      setState(() => _selectedMuscleGroups.add(val));
                                    }
                                  },
                                ),
                              ),
                            ),
                            if (_selectedMuscleGroups.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Wrap(
                                  spacing: 8,
                                  children: _selectedMuscleGroups
                                      .map((mg) => Chip(
                                            label: Text(mg),
                                            onDeleted: () {
                                              setState(() => _selectedMuscleGroups.remove(mg));
                                            },
                                          ))
                                      .toList(),
                                ),
                              ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _workoutType,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'Weights', child: Text('Weights')),
                                DropdownMenuItem(value: 'Bodyweight', child: Text('Bodyweight')),
                              ],
                              onChanged: (val) => setState(() => _workoutType = val),
                              decoration: const InputDecoration(
                                labelText: 'Workout Type',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (minutes)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0)
                                  ? 'Enter valid duration' : null,
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    if (_selectedMuscleGroups.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please select at least one muscle group')));
                                      return;
                                    }
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) => const Center(child: CircularProgressIndicator()),
                                    );

                                    final profile = Provider.of<AuthProvider>(context, listen: false).currentUser;
                                    final groqApiKey = dotenv.env['WORKOUT_API_KEY'];

                                    final prompt = """
You are a certified fitness trainer. Create a safe, personalized workout plan ONLY as a numbered list based on:

- Age:  ${profile?.age ?? 'unknown'}
- Gender: ${profile?.gender ?? 'unknown'}
- Weight: ${profile?.weight ?? 'unknown'}
- Target Weight: ${profile?.healthMetrics?['targetWeight'] ?? 'unknown'}
- Medical Concerns/Injuries: ${profile?.healthMetrics?['medicalConcerns'] ?? 'none'}
- Muscle Groups: ${_selectedMuscleGroups.join(", ")}
- Workout Type: $_workoutType
- Duration: ${_durationController.text} minutes

The plan should be suitable for a beginner unless otherwise suggested by profile. Make sure to adjust for medical issues, if any.
Return ONLY the plan as numbered steps.
""";

                                    String result = 'Failed to connect to Groq API.';
                                    try {
                                      final response = await http.post(
                                        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
                                        headers: {
                                          'Authorization': 'Bearer $groqApiKey',
                                          'Content-Type': 'application/json',
                                        },
                                        body: json.encode({
                                          "model": "meta-llama/llama-4-scout-17b-16e-instruct",
                                          "messages": [
                                            {"role": "user", "content": prompt}
                                          ],
                                          "max_tokens": 500,
                                          "temperature": 0.7,
                                        }),
                                      );

                                      if (response.statusCode == 200) {
                                        final data = json.decode(response.body);
                                        result = data['choices'][0]['message']['content'].toString();
                                      } else {
                                        result = "Groq API error: ${response.body}";
                                      }
                                    } catch (e) {
                                      result = "Failed to contact Groq API: $e";
                                    }

                                    if (mounted) Navigator.of(context).pop();
                                    if (mounted) {
                                      setState(() {
                                        _workoutPlanResult = result;
                                      });
                                    }
                                  }
                                },
                                child: const Text('Create Workout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (_workoutPlanResult != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 24.0),
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      _workoutPlanResult!,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}