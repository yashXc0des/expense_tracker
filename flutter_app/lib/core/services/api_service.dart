import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  // Update this base URL as needed or use --dart-define
  String baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://refinish-osmosis-domain.ngrok-free.dev/api');

  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _defaultHeaders(auth: auth);
    try {
      // Debug log
      final maskedHeaders = Map<String, String>.from(headers);
      if (maskedHeaders.containsKey('Authorization')) {
        maskedHeaders['Authorization'] = '[REDACTED]';
      }
      print('[ApiService] POST $uri');
      print('[ApiService] Headers: $maskedHeaders');
      print('[ApiService] Body: ${jsonEncode(body)}');

      final res = await http.post(uri, headers: headers, body: jsonEncode(body));

      print('[ApiService] Response ${res.statusCode}: ${res.body}');
      return _handleResponse(res);
    } catch (e, s) {
      print('[ApiService] POST error $uri -> $e');
      print(s);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> get(String path, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _defaultHeaders(auth: auth);
    try {
      final maskedHeaders = Map<String, String>.from(headers);
      if (maskedHeaders.containsKey('Authorization')) maskedHeaders['Authorization'] = '[REDACTED]';
      print('[ApiService] GET $uri');
      print('[ApiService] Headers: $maskedHeaders');
      final res = await http.get(uri, headers: headers);
      print('[ApiService] Response ${res.statusCode}: ${res.body}');
      return _handleResponse(res);
    } catch (e, s) {
      print('[ApiService] GET error $uri -> $e');
      print(s);
      rethrow;
    }
  }

  Future<bool> testConnectivity() async {
    try {
      final uri = Uri.parse('$baseUrl/health'.replaceAll('/api/health', '/health'));
      print('[ApiService] Testing connectivity to $uri');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      print('[ApiService] Health check response: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      print('[ApiService] Connectivity test FAILED: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSummary() async {
    final uri = Uri.parse('$baseUrl/expenses/summary');
    final headers = await _defaultHeaders(auth: true);
    try {
      print('[ApiService] GET $uri');
      final res = await http.get(uri, headers: headers);
      print('[ApiService] Response ${res.statusCode}: ${res.body}');
      return _handleResponse(res);
    } catch (e, s) {
      print('[ApiService] GET error $uri -> $e');
      print(s);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getJourneys({int page = 1, int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/journeys').replace(queryParameters: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    final headers = await _defaultHeaders(auth: true);
    try {
      print('[ApiService] GET $uri');
      final res = await http.get(uri, headers: headers);
      print('[ApiService] Response ${res.statusCode}: ${res.body}');
      return _handleResponse(res);
    } catch (e, s) {
      print('[ApiService] GET error $uri -> $e');
      print(s);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _handleResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    // For now, throw to let callers handle retries/refresh
    throw ApiException(res.statusCode, res.body);
  }

  Future<Map<String, String>> _defaultHeaders({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<Map<String, dynamic>?> delete(String path, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _defaultHeaders(auth: auth);
    try {
      final maskedHeaders = Map<String, String>.from(headers);
      if (maskedHeaders.containsKey('Authorization')) maskedHeaders['Authorization'] = '[REDACTED]';
      print('[ApiService] DELETE $uri');
      print('[ApiService] Headers: $maskedHeaders');
      final res = await http.delete(uri, headers: headers);
      print('[ApiService] Response ${res.statusCode}: ${res.body}');
      return _handleResponse(res);
    } catch (e, s) {
      print('[ApiService] DELETE error $uri -> $e');
      print(s);
      rethrow;
    }
  }

}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);
  @override
  String toString() => 'ApiException($statusCode): $body';
}
