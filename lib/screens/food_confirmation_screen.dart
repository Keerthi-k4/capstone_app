import 'package:flutter/material.dart';
import 'dart:io';
import '../models/food_model.dart';
import '../services/food_firestore_service.dart';
import '../services/ml_food_recognition_service.dart';

class FoodConfirmationScreen extends StatefulWidget {
  final File? imageFile;
  final MLFoodRecognitionResponse? mlResponse;
  final FoodItem? prefilledFood;

  const FoodConfirmationScreen({
    super.key,
    this.imageFile,
    this.mlResponse,
    this.prefilledFood,
  });

  @override
  State<FoodConfirmationScreen> createState() => _FoodConfirmationScreenState();
}

class _FoodConfirmationScreenState extends State<FoodConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  final FoodFirestoreService _firestoreService = FoodFirestoreService();
  final MLFoodRecognitionService _mlService = MLFoodRecognitionService();

  String _selectedMealType = 'breakfast';
  bool _isLoading = false;
  int _selectedPredictionIndex = 0;

  // Base nutrition values (per 100g) for scaling
  double _baseCalories = 0;
  double _baseProtein = 0;
  double _baseCarbs = 0;
  double _baseFat = 0;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    // If we have prefilled food (from manual search)
    if (widget.prefilledFood != null) {
      final food = widget.prefilledFood!;
      _foodNameController.text = food.name;
      _quantityController.text = '100';
      _caloriesController.text = food.calories.toString();
      _proteinController.text = food.protein.toString();
      _carbsController.text = food.carbs.toString();
      _fatController.text = food.fat.toString();
    }
    // If we have ML predictions
    else if (widget.mlResponse != null &&
        widget.mlResponse!.predictions.isNotEmpty) {
      final topPrediction = widget.mlResponse!.predictions[0];
      _foodNameController.text = topPrediction.name;
      _quantityController.text = '100';

      // If we have nutrition data from the prediction
      if (widget.mlResponse!.topPrediction?.nutrition != null) {
        final nutrition = widget.mlResponse!.topPrediction!.nutrition!;
        _caloriesController.text = nutrition.calories.toString();
        _proteinController.text = nutrition.protein.toString();
        _carbsController.text = nutrition.carbohydrates.toString();
        _fatController.text = nutrition.fat.toString();
      } else {
        // Default values or fetch from API
        _fetchNutritionData(topPrediction.name);
      }
    }
    // Default values
    else {
      _quantityController.text = '100';
      _caloriesController.text = '0';
      _proteinController.text = '0';
      _carbsController.text = '0';
      _fatController.text = '0';
    }
  }

  Future<void> _fetchNutritionData(String foodName) async {
    setState(() => _isLoading = true);

    try {
      final nutrition = await _mlService.getNutrition(foodName);
      if (nutrition != null && mounted) {
        // Store base values (per 100g) for scaling calculations
        _baseCalories = nutrition.calories;
        _baseProtein = nutrition.protein;
        _baseCarbs = nutrition.carbohydrates;
        _baseFat = nutrition.fat;

        // Set initial values
        _caloriesController.text = nutrition.calories.toString();
        _proteinController.text = nutrition.protein.toString();
        _carbsController.text = nutrition.carbohydrates.toString();
        _fatController.text = nutrition.fat.toString();
      }
    } catch (e) {
      print('Error fetching nutrition: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateNutritionBasedOnQuantity() {
    final quantityText = _quantityController.text.trim();
    if (quantityText.isEmpty) return;

    final quantity = double.tryParse(quantityText);
    if (quantity == null || quantity <= 0) return;

    // Scale nutrition values based on quantity (base values are per 100g)
    final scaleFactor = quantity / 100.0;

    _caloriesController.text = (_baseCalories * scaleFactor).toStringAsFixed(1);
    _proteinController.text = (_baseProtein * scaleFactor).toStringAsFixed(1);
    _carbsController.text = (_baseCarbs * scaleFactor).toStringAsFixed(1);
    _fatController.text = (_baseFat * scaleFactor).toStringAsFixed(1);

    setState(() {});
  }

  void _onPredictionSelected(int index) {
    setState(() {
      _selectedPredictionIndex = index;
      final prediction = widget.mlResponse!.predictions[index];
      _foodNameController.text = prediction.name;
      _fetchNutritionData(prediction.name);
    });
  }

  Future<void> _saveFoodLog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final foodLog = FoodLog(
        name: _foodNameController.text.trim(),
        calories: double.tryParse(_caloriesController.text)?.round() ?? 0,
        mealType: _selectedMealType,
        date: DateTime.now().toIso8601String().split('T').first,
        quantity: double.tryParse(_quantityController.text) ?? 100.0,
        userId: '', // Will be set by Firestore service
      );

      await _firestoreService.insertLog(foodLog);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_foodNameController.text} logged successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving food log: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Food'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveFoodLog,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'SAVE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview
              if (widget.imageFile != null) ...[
                Center(
                  child: Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(widget.imageFile!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ML Predictions
              if (widget.mlResponse != null &&
                  widget.mlResponse!.predictions.isNotEmpty) ...[
                const Text(
                  'ML Predictions:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.mlResponse!.predictions.length,
                    itemBuilder: (context, index) {
                      final prediction = widget.mlResponse!.predictions[index];
                      final isSelected = index == _selectedPredictionIndex;

                      return GestureDetector(
                        onTap: () => _onPredictionSelected(index),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1)
                                : Colors.grey[100],
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 10),
                              ),
                              if (prediction.isCustomModel)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Custom Model',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Food details form
              const Text(
                'Food Details:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _foodNameController,
                decoration: const InputDecoration(
                  labelText: 'Food Name *',
                  hintText: 'Enter food name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter food name';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Optional: Auto-fetch nutrition data when typing
                },
              ),
              const SizedBox(height: 16),

              // Meal type selection
              DropdownButtonFormField<String>(
                value: _selectedMealType,
                decoration: const InputDecoration(
                  labelText: 'Meal Type',
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'breakfast', child: Text('Breakfast')),
                  DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                  DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                  DropdownMenuItem(value: 'snack', child: Text('Snack')),
                ],
                onChanged: (value) {
                  setState(() => _selectedMealType = value!);
                },
              ),
              const SizedBox(height: 16),

              // Nutrition information
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity (g)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _updateNutritionBasedOnQuantity();
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _caloriesController,
                      decoration: const InputDecoration(
                        labelText: 'Calories',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _fatController,
                decoration: const InputDecoration(
                  labelText: 'Fat (g)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveFoodLog,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Save Food Log',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _quantityController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }
}
