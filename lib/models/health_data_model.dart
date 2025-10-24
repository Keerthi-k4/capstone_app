/// Model class to represent health and activity data
/// Supports both demo mode (hardcoded data) and actual mode (Health Connect data)
class HealthData {
  final int steps;
  final int heartRate; // beats per minute - current/active heart rate
  final int restingHeartRate; // resting heart rate (baseline)
  final int caloriesBurned;
  final int exerciseMinutes;
  final double oxygenSaturation; // SpO2 percentage (95-100% is normal)
  final double sleepHours; // hours of sleep
  final double respiratoryRate; // breaths per minute (for stress assessment)
  final DateTime timestamp;
  final bool isDemoMode;

  const HealthData({
    required this.steps,
    required this.heartRate,
    this.restingHeartRate = 0,
    required this.caloriesBurned,
    required this.exerciseMinutes,
    this.oxygenSaturation = 0.0,
    this.sleepHours = 0.0,
    this.respiratoryRate = 0.0,
    required this.timestamp,
    this.isDemoMode = false,
  });

  /// Factory constructor for demo data
  factory HealthData.demo() {
    return HealthData(
      steps: 4200,
      heartRate: 72,
      restingHeartRate: 65,
      caloriesBurned: 280,
      exerciseMinutes: 15,
      oxygenSaturation: 98.0, // Normal SpO2 is 95-100%
      sleepHours: 7.5, // 7.5 hours of sleep
      respiratoryRate: 16.0, // normal breathing rate
      timestamp: DateTime.now(),
      isDemoMode: true,
    );
  }

  /// Factory constructor from JSON (for Health Connect data)
  factory HealthData.fromJson(Map<String, dynamic> json) {
    return HealthData(
      steps: json['steps'] ?? 0,
      heartRate: json['heartRate'] ?? 0,
      restingHeartRate: json['restingHeartRate'] ?? 0,
      caloriesBurned: json['caloriesBurned'] ?? 0,
      exerciseMinutes: json['exerciseMinutes'] ?? 0,
      oxygenSaturation: (json['oxygenSaturation'] ?? 0.0).toDouble(),
      sleepHours: (json['sleepHours'] ?? 0.0).toDouble(),
      respiratoryRate: (json['respiratoryRate'] ?? 0.0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isDemoMode: json['isDemoMode'] ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'steps': steps,
      'heartRate': heartRate,
      'restingHeartRate': restingHeartRate,
      'caloriesBurned': caloriesBurned,
      'exerciseMinutes': exerciseMinutes,
      'oxygenSaturation': oxygenSaturation,
      'sleepHours': sleepHours,
      'respiratoryRate': respiratoryRate,
      'timestamp': timestamp.toIso8601String(),
      'isDemoMode': isDemoMode,
    };
  }

  /// Create a copy with updated values
  HealthData copyWith({
    int? steps,
    int? heartRate,
    int? restingHeartRate,
    int? caloriesBurned,
    int? exerciseMinutes,
    double? oxygenSaturation,
    double? sleepHours,
    double? respiratoryRate,
    DateTime? timestamp,
    bool? isDemoMode,
  }) {
    return HealthData(
      steps: steps ?? this.steps,
      heartRate: heartRate ?? this.heartRate,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      oxygenSaturation: oxygenSaturation ?? this.oxygenSaturation,
      sleepHours: sleepHours ?? this.sleepHours,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      timestamp: timestamp ?? this.timestamp,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  /// Estimate stress level based on respiratory rate and heart rate
  /// Returns a value from 0-100 (0 = relaxed, 100 = very stressed)
  int get stressLevel {
    if (respiratoryRate == 0 || heartRate == 0 || restingHeartRate == 0) {
      return 0; // Cannot calculate without data
    }
    
    // Normal respiratory rate: 12-20 breaths/min
    // Normal resting HR: 60-100 bpm
    // Calculate deviation from normal ranges
    final respiratoryStress = ((respiratoryRate - 16).abs() / 16 * 50).clamp(0, 50);
    final heartRateStress = restingHeartRate > 0 
        ? ((heartRate - restingHeartRate) / restingHeartRate * 50).clamp(0, 50)
        : 0;
    
    return (respiratoryStress + heartRateStress).round().clamp(0, 100);
  }

  /// Get stress level description
  String get stressDescription {
    final level = stressLevel;
    if (level == 0) return 'Unknown';
    if (level < 25) return 'Relaxed';
    if (level < 50) return 'Normal';
    if (level < 75) return 'Elevated';
    return 'High';
  }

  @override
  String toString() {
    return 'HealthData(steps: $steps, heartRate: $heartRate, restingHeartRate: $restingHeartRate, '
        'caloriesBurned: $caloriesBurned, exerciseMinutes: $exerciseMinutes, '
        'oxygenSaturation: ${oxygenSaturation.toStringAsFixed(1)}%, sleepHours: ${sleepHours.toStringAsFixed(1)}h, '
        'respiratoryRate: $respiratoryRate, stressLevel: $stressDescription, isDemoMode: $isDemoMode)';
  }
}
