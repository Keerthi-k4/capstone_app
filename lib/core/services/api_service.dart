import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:attempt2/core/constants.dart';

/// Service for handling API requests
class ApiService {
  final String baseUrl;
  final Map<String, String> defaultHeaders;

  ApiService({
    this.baseUrl = AppConstants.nutritionApiBaseUrl,
    this.defaultHeaders = const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  });

  /// Make a GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final response = await http.get(
        uri,
        headers: {...defaultHeaders, ...?headers},
      );

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Make a POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Object? body,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final response = await http.post(
        uri,
        headers: {...defaultHeaders, ...?headers},
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Make a PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Object? body,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final response = await http.put(
        uri,
        headers: {...defaultHeaders, ...?headers},
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Make a DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Object? body,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final response = await http.delete(
        uri,
        headers: {...defaultHeaders, ...?headers},
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Build URI with query parameters
  Uri _buildUri(String endpoint, Map<String, dynamic>? queryParams) {
    final uri = Uri.parse('$baseUrl/$endpoint');

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
    }

    return uri;
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }

      try {
        return jsonDecode(response.body);
      } catch (e) {
        return {
          'error': true,
          'message': 'Failed to parse response: $e',
          'statusCode': response.statusCode,
        };
      }
    } else {
      return {
        'error': true,
        'message': 'Request failed with status: ${response.statusCode}',
        'statusCode': response.statusCode,
        'body': response.body,
      };
    }
  }

  /// Handle errors
  Map<String, dynamic> _handleError(dynamic error) {
    return {'error': true, 'message': 'Request failed: $error'};
  }

  /// Search for food nutrition data
  Future<Map<String, dynamic>> searchFoodNutrition(String query) async {
    return await get('search', queryParams: {'query': query});
  }

  /// Get nutrition data for a specific food
  Future<Map<String, dynamic>> getFoodNutrition(String foodId) async {
    return await get('food/$foodId');
  }

  /// Get exercise data
  Future<Map<String, dynamic>> getExercises(String category) async {
    return await get('exercises', queryParams: {'category': category});
  }
}
