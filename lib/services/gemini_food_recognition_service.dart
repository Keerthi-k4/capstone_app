import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/food_model.dart';

class GeminiFoodRecognitionService {
  // Updated to use available model
  static const String _model =
      'gemini-2.0-flash'; // Vision-capable Gemini model

  String? get _apiKey => dotenv.env['GEMINI_API_KEY'];

  Future<MLFoodRecognitionResponse> predictFoodWithNutrition(
      File imageFile) async {
    try {
      final apiKey = _apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        return MLFoodRecognitionResponse(
          success: false,
          error: 'GEMINI_API_KEY is not set',
        );
      }

      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Updated to v1 endpoint
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent?key=$apiKey',
      );

      // Prompt for JSON-only output
      final prompt = '''
You are a food recognition assistant. Given an image, identify the single most likely food item name (concise, generic label like "grilled chicken salad", "apple", "pizza", etc.) and up to 4 alternative candidates if relevant. Then provide approximate nutrition per 100g for the top item using fields:
- food_name (string)
- energy_kcal (number)
- protein_g (number)
- carbohydrate_g (number)
- fat_g (number)
- fibre_g (number)
- sugars_g (number)
- sodium_mg (number)
- cholesterol_mg (number)

Return ONLY a JSON object with this structure:
{
  "success": true,
  "predictions": [
    { "name": "string", "confidence": 0.0 }
  ],
  "top_prediction": {
    "name": "string",
    "confidence": 0.0,
    "nutrition": {
      "food_name": "string",
      "energy_kcal": 0,
      "protein_g": 0,
      "carbohydrate_g": 0,
      "fat_g": 0,
      "fibre_g": 0,
      "sugars_g": 0,
      "sodium_mg": 0,
      "cholesterol_mg": 0
    }
  }
}
Do NOT include extra explanation. Only JSON.
''';

      // Request body with correct structure
      final body = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {
                  // Note: use snake_case for v1 API
                  "mime_type": "image/jpeg",
                  "data": base64Image,
                }
              }
            ]
          }
        ],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 800}
      };

      // Make request
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        return MLFoodRecognitionResponse(
          success: false,
          error: 'Gemini error (${resp.statusCode}): ${resp.body}',
        );
      }

      // Extract response
      final data = jsonDecode(resp.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return MLFoodRecognitionResponse(
          success: false,
          error: 'No candidates returned by Gemini',
        );
      }

      final parts = candidates[0]['content']?['parts'] as List?;
      final text = (parts != null && parts.isNotEmpty)
          ? (parts[0]['text'] as String? ?? '')
          : '';

      if (text.isEmpty) {
        return MLFoodRecognitionResponse(
          success: false,
          error: 'Empty response from Gemini',
        );
      }

      // Parse JSON
      Map<String, dynamic> jsonOut;
      try {
        jsonOut = jsonDecode(text);
      } catch (_) {
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start >= 0 && end >= start) {
          jsonOut = jsonDecode(text.substring(start, end + 1));
        } else {
          return MLFoodRecognitionResponse(
            success: false,
            error: 'Failed to parse Gemini output: $text',
          );
        }
      }

      // Map predictions
      final predictionsList = (jsonOut['predictions'] as List?)
              ?.map((p) => FoodPrediction(
                    name: p['name']?.toString() ?? '',
                    confidence: (p['confidence'] ?? 0.0).toDouble(),
                    isCustomModel: false,
                  ))
              .toList() ??
          <FoodPrediction>[];

      // Top prediction
      FoodPredictionWithNutrition? top;
      final topJson = jsonOut['top_prediction'];
      if (topJson != null) {
        NutritionData? nutrition;
        if (topJson['nutrition'] != null) {
          nutrition = NutritionData.fromJson(
              Map<String, dynamic>.from(topJson['nutrition']));
        }
        top = FoodPredictionWithNutrition(
          name: topJson['name']?.toString() ?? '',
          confidence: (topJson['confidence'] ?? 0.0).toDouble(),
          nutrition: nutrition,
        );
      }

      return MLFoodRecognitionResponse(
        success:
            jsonOut['success'] == true || (top != null && top.name.isNotEmpty),
        predictions: predictionsList,
        topPrediction: top,
      );
    } catch (e) {
      return MLFoodRecognitionResponse(
        success: false,
        error: 'Gemini exception: $e',
      );
    }
  }
}
