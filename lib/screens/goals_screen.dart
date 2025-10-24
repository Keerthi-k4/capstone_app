import 'package:flutter/material.dart';
import 'package:attempt2/services/user_goals_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final UserGoalsService _service = UserGoalsService();
  UserGoals? _goals;
  bool _loading = true;

  final _caloriesCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  final _exerciseCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatsCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final goals = await _service.getGoalsOnce();
    setState(() {
      _goals = goals;
      _loading = false;
    });
    _syncControllers(goals);
  }

  void _syncControllers(UserGoals goals) {
    _caloriesCtrl.text = goals.caloriesTarget.toString();
    _stepsCtrl.text = goals.stepsTarget.toString();
    _exerciseCtrl.text = goals.exerciseMinutesTarget.toString();
    _waterCtrl.text = goals.waterGlassesTarget.toString();
    _proteinCtrl.text = goals.proteinGramsTarget.toString();
    _carbsCtrl.text = goals.carbsGramsTarget.toString();
    _fatsCtrl.text = goals.fatsGramsTarget.toString();
    _fiberCtrl.text = goals.fiberGramsTarget.toString();
  }

  Future<void> _applyPlan(GoalPlan plan) async {
    if (_goals == null) return;
    final updated = _service.presetForPlan(plan, base: _goals);
    setState(() => _goals = updated);
    _syncControllers(updated);
  }

  Future<void> _save() async {
    if (_goals == null) return;
    final parsed = _goals!.copyWith(
      caloriesTarget:
          int.tryParse(_caloriesCtrl.text) ?? _goals!.caloriesTarget,
      stepsTarget: int.tryParse(_stepsCtrl.text) ?? _goals!.stepsTarget,
      exerciseMinutesTarget:
          int.tryParse(_exerciseCtrl.text) ?? _goals!.exerciseMinutesTarget,
      waterGlassesTarget:
          int.tryParse(_waterCtrl.text) ?? _goals!.waterGlassesTarget,
      proteinGramsTarget:
          int.tryParse(_proteinCtrl.text) ?? _goals!.proteinGramsTarget,
      carbsGramsTarget:
          int.tryParse(_carbsCtrl.text) ?? _goals!.carbsGramsTarget,
      fatsGramsTarget:
          int.tryParse(_fatsCtrl.text) ?? _goals!.fatsGramsTarget,
      fiberGramsTarget:
          int.tryParse(_fiberCtrl.text) ?? _goals!.fiberGramsTarget,
      plan: GoalPlan.custom,
    );

    setState(() => _loading = true);
    await _service.saveGoals(parsed);
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goals saved')),
      );
      Navigator.pop(context, parsed);
    }
  }

  @override
  void dispose() {
    _caloriesCtrl.dispose();
    _stepsCtrl.dispose();
    _exerciseCtrl.dispose();
    _waterCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatsCtrl.dispose();
    _fiberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Goals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a plan',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _planChip('Weight loss', GoalPlan.weightLoss),
                      _planChip('Muscle building', GoalPlan.muscleBuilding),
                      _planChip('Maintenance', GoalPlan.maintenance),
                      _planChip('Custom', GoalPlan.custom),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _numberField('Daily calories (kcal)', _caloriesCtrl),
                  _numberField('Daily steps', _stepsCtrl),
                  _numberField('Exercise minutes', _exerciseCtrl),
                  _numberField('Water (glasses)', _waterCtrl),
                  _numberField('Protein (g)', _proteinCtrl),
                  _numberField('Carbohydrates (g)', _carbsCtrl),
                  _numberField('Fats (g)', _fatsCtrl),
                  _numberField('Fiber (g)', _fiberCtrl),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: const Text('Save Goals'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _planChip(String label, GoalPlan plan) {
    final selected = _goals?.plan == plan;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => _applyPlan(plan),
    );
  }

  Widget _numberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
