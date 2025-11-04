import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attempt2/providers/auth_provider.dart';
import 'package:attempt2/models/user_model.dart';

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
    // Assume a custom field in UserModel or use healthMetrics for 'targetWeight'
    _targetWeightController = TextEditingController(text: user?.healthMetrics?['targetWeight']?.toString() ?? '');
    _medicalConcernsController = TextEditingController(text: user?.healthMetrics?['medicalConcerns']?.toString() ?? '');
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
    final String medicalConcerns = _medicalConcernsController.text.trim();
    // Calculate height in cm
    double heightCm = feet * 30.48 + inches * 2.54;

    bool updated = await authProvider.updateUserProfile(
      name: name,
      age: age,
      weight: weight,
      height: heightCm > 0 ? heightCm : null,
    );

    if (updated) {
      // Save targetWeight in healthMetrics if available
      var user = authProvider.currentUser;
      if (user != null) {
        final updatedHealthMetrics = {
          ...?user.healthMetrics,
          if (targetWeight != null) 'targetWeight': targetWeight,
          'medicalConcerns': medicalConcerns,
        };
        await authProvider.updateUserProfile(
          name: user.name,
          age: user.age,
          weight: user.weight,
          height: user.height,
          gender: user.gender,
          healthMetrics: updatedHealthMetrics,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved!')));
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final bool needsProfile = (user?.name.isEmpty ?? true) || user?.age == null || user?.height == null || user?.weight == null;

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(_nameController, 'Name', TextInputType.text),
                    const SizedBox(height: 16),
                    _buildTextField(_ageController, 'Age', TextInputType.number),
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
                    _buildTextField(_medicalConcernsController, 'Injuries/Medical Concerns', TextInputType.multiline, maxLines: 3),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                        onPressed: _saveProfile,
                        child: Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType type, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if ((v ?? '').trim().isEmpty) return 'Required';
        return null;
      },
    );
  }
}
