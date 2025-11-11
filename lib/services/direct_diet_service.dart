import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Direct Diet Service - Calls Groq API directly without FastAPI server
/// Similar to how exercise planning works, but uses kimi-k2-instruct model
class DirectDietService {
  /// Generate diet recommendations using Groq API directly
  static Future<List<Map<String, dynamic>>> generateRecommendations({
    required String date,
    required List<Map<String, dynamic>> recentLogs,
    Map<String, dynamic>? userProfile,
    Map<String, dynamic>? userGoals,
    Map<String, dynamic>? todayProgress,
  }) async {
    final apiKey = dotenv.env['DIET_API_KEY'];
    final model =
        dotenv.env['DIET_MODEL'] ?? ' moonshotai/kimi-k2-instruct-0905';

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DIET_API_KEY not configured in .env file');
    }

    print('🔑 Using API Key: ${apiKey.substring(0, 10)}...');
    print('🤖 Using Model: $model');
    print('📅 Generating recommendations for: $date');
    print('📊 Recent logs count: ${recentLogs.length}');

    // Build context from recent logs
    final logsContext = recentLogs.map((log) {
      return '- ${log['name']}: ${log['calories']} cal (${log['mealType'] ?? 'unknown'})';
    }).join('\n');

    // Calculate nutritional totals
    int totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final log in recentLogs) {
      totalCalories += (log['calories'] as num?)?.toInt() ?? 0;
      totalProtein += (log['protein'] as num?)?.toDouble() ?? 0;
      totalCarbs += (log['carbs'] as num?)?.toDouble() ?? 0;
      totalFat += (log['fat'] as num?)?.toDouble() ?? 0;
    }

    print(
        '📈 Total nutrition - Calories: $totalCalories, Protein: ${totalProtein.toStringAsFixed(1)}g, Carbs: ${totalCarbs.toStringAsFixed(1)}g, Fat: ${totalFat.toStringAsFixed(1)}g');

    // Build contexts
    final today = date;
    final todaysLogs = recentLogs.where((l) => l['date'] == today).toList();
    final todaysContext = todaysLogs.map((l) {
      return '- ${l['name']}: ${l['calories']} cal '
          'P:${(l['protein'] ?? 0).toString()}g C:${(l['carbs'] ?? 0).toString()}g F:${(l['fat'] ?? 0).toString()}g';
    }).join('\n');

    final goalsText = userGoals == null
        ? 'unknown'
        : 'Calories:${userGoals['caloriesTarget'] ?? 'unknown'}, '
            'Protein:${userGoals['proteinGramsTarget'] ?? 'unknown'}g, '
            'Carbs:${userGoals['carbsGramsTarget'] ?? 'unknown'}g, '
            'Fats:${userGoals['fatsGramsTarget'] ?? 'unknown'}g, '
            'Fiber:${userGoals['fiberGramsTarget'] ?? 'unknown'}g, '
            'Steps:${userGoals['stepsTarget'] ?? 'unknown'}, '
            'Exercise:${userGoals['exerciseMinutesTarget'] ?? 'unknown'} min';

    final progressText = todayProgress == null
        ? 'unknown'
        : [
            'Today so far:',
            'Calories Consumed: ${todayProgress['caloriesConsumed'] ?? 0}',
            'Protein: ${todayProgress['proteinConsumed'] ?? 0}/${todayProgress['proteinTarget'] ?? 0}g',
            'Carbs: ${todayProgress['carbsConsumed'] ?? 0}/${todayProgress['carbsTarget'] ?? 0}g',
            'Fats: ${todayProgress['fatsConsumed'] ?? 0}/${todayProgress['fatsTarget'] ?? 0}g',
            'Fiber: ${todayProgress['fiberConsumed'] ?? 0}/${todayProgress['fiberTarget'] ?? 0}g',
            'Steps: ${todayProgress['steps'] ?? 0}/${todayProgress['stepsTarget'] ?? 0}',
            'Exercise: ${todayProgress['exerciseMinutes'] ?? 0}/${todayProgress['exerciseTarget'] ?? 0} min',
            'Sleep: ${todayProgress['sleepHours'] ?? 0} h',
          ].join('\n');

    // Build the prompt for the AI
    final prompt = """
You are a practical nutrition expert providing simple, everyday meal recommendations for tomorrow.

CONTEXT:
Recent meals eaten:
$logsContext
Today's meals (same day):
$todaysContext

Total recent intake: $totalCalories cal, ${totalProtein.toStringAsFixed(1)}g protein, ${totalCarbs.toStringAsFixed(1)}g carbs, ${totalFat.toStringAsFixed(1)}g fat

USER PROFILE:
- Age: ${userProfile?['age'] ?? 'unknown'}
- Weight: ${userProfile?['weight'] ?? 'unknown'} kg
- Target Weight: ${userProfile?['targetWeight'] ?? 'unknown'} kg
- Goal: ${userProfile?['goal'] ?? 'maintenance'}
- Medical Concerns: ${userProfile?['medicalConcerns'] ?? 'none'}

USER GOALS (targets):
$goalsText

TODAY'S PROGRESS:
$progressText

TASK:
Suggest 3 regular, everyday meals for tomorrow that:
1. Balance the nutrition (add more protein if lacking, more vegetables if needed, etc.)
2. Are easy to prepare at home with common ingredients
3. Match the user's dietary goals and health profile
4. Avoid foods the user has eaten recently to add variety
5. Prefer meals that help close the remaining gaps toward today's macro targets (protein/carbs/fats/fiber) while keeping calories on target. If the user already exceeded a target, recommend lighter options.

IMPORTANT GUIDELINES:
- Keep it simple - basic home cooking, no fancy restaurant dishes
 - Distribute meals across breakfast, lunch, and dinner appropriately
- Consider portion sizes and realistic calorie counts
- Provide clear reasoning for each recommendation. What gaps it is filling and why it is a good choice. Why it is good based on the user's goals and health profile.

CRITICAL: Respond ONLY with valid JSON in this EXACT format, NO extra text before or after:
{
  "recommendations": [
    {
      "item": "Simple dish name",
      "calories": 300,
      "mealType": "breakfast",
      "reasoning": "Why this meal helps meet nutritional goals",
      "protein": 20,
      "carbs": 35,
      "fat": 10,
      "fiber": 5,
      "quantity": 100.0
    },
    {
      "item": "Another simple dish",
      "calories": 450,
      "mealType": "lunch",
      "reasoning": "Why this meal helps",
      "protein": 30,
      "carbs": 50,
      "fat": 15,
      "fiber": 6,
      "quantity": 100.0
    },
    {
      "item": "Third simple dish",
      "calories": 400,
      "mealType": "dinner",
      "reasoning": "Why this meal helps",
      "protein": 25,
      "carbs": 45,
      "fat": 12,
      "fiber": 7,
      "quantity": 100.0
    }
  ]
}

Return ONLY the JSON, nothing else.
""";

    try {
      print('🌐 Calling Groq API...');

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              "model": model,
              "messages": [
                {"role": "user", "content": prompt}
              ],
              "max_tokens": 1500,
              "temperature": 0.7,
            }),
          )
          .timeout(Duration(seconds: 30));

      print('📡 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'].toString();

        print('📝 Raw API Response:');
        print(content);

        // Parse JSON from response
        try {
          // Find JSON in response (handle cases where AI adds extra text)
          final jsonStart = content.indexOf('{');
          final jsonEnd = content.lastIndexOf('}') + 1;

          if (jsonStart != -1 && jsonEnd > jsonStart) {
            final jsonStr = content.substring(jsonStart, jsonEnd);
            final parsed = jsonDecode(jsonStr);

            if (parsed['recommendations'] != null) {
              final recommendations =
                  List<Map<String, dynamic>>.from(parsed['recommendations']);
              print(
                  '✅ Successfully parsed ${recommendations.length} recommendations');

              // Validate and clean recommendations
              final validRecommendations = <Map<String, dynamic>>[];
              for (var rec in recommendations) {
                if (rec['item'] != null && rec['item'].toString().isNotEmpty) {
                  // Ensure all required fields have valid values
                  validRecommendations.add({
                    'item': rec['item'].toString(),
                    'calories': (rec['calories'] as num?)?.toInt() ?? 300,
                    'mealType': rec['mealType']?.toString() ?? 'snack',
                    'reasoning':
                        rec['reasoning']?.toString() ?? 'Balanced meal',
                    'protein': (rec['protein'] as num?)?.toDouble() ?? 0,
                    'carbs': (rec['carbs'] as num?)?.toDouble() ?? 0,
                    'fat': (rec['fat'] as num?)?.toDouble() ?? 0,
                    'fiber': (rec['fiber'] as num?)?.toDouble() ?? 0,
                    'quantity': (rec['quantity'] as num?)?.toDouble() ?? 1.0,
                  });
                }
              }

              if (validRecommendations.isEmpty) {
                throw Exception(
                    'No valid recommendations found in AI response');
              }

              return validRecommendations;
            }
          }

          throw Exception('No recommendations array found in response');
        } catch (e) {
          print('❌ Error parsing recommendations: $e');
          print('Response content: $content');
          throw Exception('Failed to parse AI response: $e');
        }
      } else {
        final errorBody = response.body;
        print('❌ Groq API error: ${response.statusCode}');
        print('Error details: $errorBody');
        throw Exception('Groq API error: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      print('❌ Failed to generate recommendations: $e');
      rethrow;
    }
  }
}
