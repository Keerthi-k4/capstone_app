import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attempt2/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightFeetController;
  late TextEditingController _heightInchesController;
  late TextEditingController _weightController;
  late TextEditingController _targetWeightController;
  late TextEditingController _medicalConcernsController;
  
  String? _selectedGender;
  String? _selectedActivityLevel;
  bool _useWatchData = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _ageController = TextEditingController(text: user?.age?.toString() ?? '');
    double? heightCm = user?.height;
    int feet = heightCm != null ? (heightCm / 30.48).floor() : 0;
    int inches = heightCm != null ? (((heightCm % 30.48) / 2.54).round()) : 0;
    _heightFeetController = TextEditingController(text: feet > 0 ? feet.toString() : '');
    _heightInchesController = TextEditingController(text: inches > 0 ? inches.toString() : '');
    _weightController = TextEditingController(text: user?.weight?.toString() ?? '');
    _targetWeightController = TextEditingController(text: user?.targetWeight?.toString() ?? '');
    _medicalConcernsController = TextEditingController(text: user?.medicalConcerns ?? '');
    _selectedGender = user?.gender;
    _selectedActivityLevel = user?.activityLevel;
    _useWatchData = user?.useWatchDataForTDEE ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _medicalConcernsController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String name = _nameController.text.trim();
    final int? age = int.tryParse(_ageController.text.trim());
    final int feet = int.tryParse(_heightFeetController.text.trim()) ?? 0;
    final int inches = int.tryParse(_heightInchesController.text.trim()) ?? 0;
    final double? weight = double.tryParse(_weightController.text.trim());
    final double? targetWeight = double.tryParse(_targetWeightController.text.trim());
    final String? medicalConcerns = _medicalConcernsController.text.trim().isNotEmpty 
        ? _medicalConcernsController.text.trim() 
        : null;
    // Calculate height in cm
    double heightCm = feet * 30.48 + inches * 2.54;

    bool updated = await authProvider.updateUserProfile(
      name: name,
      age: age,
      weight: weight,
      height: heightCm > 0 ? heightCm : null,
      gender: _selectedGender,
      activityLevel: _selectedActivityLevel,
      targetWeight: targetWeight,
      medicalConcerns: medicalConcerns,
      useWatchDataForTDEE: _useWatchData,
    );

    if (updated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved to database!')));
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.error ?? 'Failed to update profile.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: Center(
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(_nameController, 'Name', TextInputType.text),
                      const SizedBox(height: 16),
                      _buildTextField(_ageController, 'Age', TextInputType.number),
                      const SizedBox(height: 16),
                      // Gender dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(value: 'female', child: Text('Female')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedGender = value);
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_heightFeetController, 'Height (ft)', TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTextField(_heightInchesController, 'Height (in)', TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_weightController, 'Weight (kg)', TextInputType.numberWithOptions(decimal: true)),
                      const SizedBox(height: 16),
                      _buildTextField(_targetWeightController, 'Target Weight (kg)', TextInputType.numberWithOptions(decimal: true)),
                      const SizedBox(height: 16),
                      // Activity level dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedActivityLevel,
                        decoration: const InputDecoration(
                          labelText: 'Activity Level',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'sedentary', child: Text('Sedentary (little/no exercise)')),
                          DropdownMenuItem(value: 'lightly_active', child: Text('Lightly Active (1-3 days/week)')),
                          DropdownMenuItem(value: 'moderately_active', child: Text('Moderately Active (3-5 days/week)')),
                          DropdownMenuItem(value: 'very_active', child: Text('Very Active (6-7 days/week)')),
                          DropdownMenuItem(value: 'extremely_active', child: Text('Extremely Active (athlete)')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedActivityLevel = value);
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      // Use watch data toggle
                      SwitchListTile(
                        title: const Text('Use Watch Data for TDEE'),
                        subtitle: const Text('Use smart watch calories instead of calculated'),
                        value: _useWatchData,
                        onChanged: (value) {
                          setState(() => _useWatchData = value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_medicalConcernsController, 'Injuries/Medical Concerns (Optional)', TextInputType.multiline, maxLines: 3, required: false),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          onPressed: _saveProfile,
                          child: const Text('Save to Database', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType type, {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required ? (v) {
        if ((v ?? '').trim().isEmpty) return 'Required';
        return null;
      } : null,
    );
  }
}
