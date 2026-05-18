import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  // Update this base URL as needed or use --dart-define
  String baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://refinish-osmosis-domain.ngrok-free.dev/api');

  bool _refreshInProgress = false;

  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    Map<String, String> headers = await _defaultHeaders(auth: auth);
    try {
      // Debug log
      final maskedHeaders = Map<String, String>.from(headers);
      if (maskedHeaders.containsKey('Authorization')) {
        maskedHeaders['Authorization'] = '[REDACTED]';
      }
      print('[ApiService] POST $uri');
      print('[ApiService] Headers: $maskedHeaders');
      print('[ApiService] Body: ${jsonEncode(body)}');

      var res = await http.post(uri, headers: headers, body: jsonEncode(body));

      if (auth && res.statusCode == 401) {
        final refreshed = await tryRefreshAccessToken();
        if (refreshed) {
          headers = await _defaultHeaders(auth: true);
          res = await http.post(uri, headers: headers, body: jsonEncode(body));
        }
      }

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
    Map<String, String> headers = await _defaultHeaders(auth: auth);
    try {
      final maskedHeaders = Map<String, String>.from(headers);
      if (maskedHeaders.containsKey('Authorization')) maskedHeaders['Authorization'] = '[REDACTED]';
      print('[ApiService] GET $uri');
      print('[ApiService] Headers: $maskedHeaders');
      var res = await http.get(uri, headers: headers);

      if (auth && res.statusCode == 401) {
        final refreshed = await tryRefreshAccessToken();
        if (refreshed) {
          headers = await _defaultHeaders(auth: true);
          res = await http.get(uri, headers: headers);
        }
      }
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
    Map<String, String> headers = await _defaultHeaders(auth: true);
    try {
      print('[ApiService] GET $uri');
      var res = await http.get(uri, headers: headers);
      if (res.statusCode == 401) {
        final refreshed = await tryRefreshAccessToken();
        if (refreshed) {
          headers = await _defaultHeaders(auth: true);
          res = await http.get(uri, headers: headers);
        }
      }
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
    Map<String, String> headers = await _defaultHeaders(auth: auth);
    try {
      final maskedHeaders = Map<String, String>.from(headers);
      if (maskedHeaders.containsKey('Authorization')) maskedHeaders['Authorization'] = '[REDACTED]';
      print('[ApiService] DELETE $uri');
      print('[ApiService] Headers: $maskedHeaders');
      var res = await http.delete(uri, headers: headers);
      if (auth && res.statusCode == 401) {
        final refreshed = await tryRefreshAccessToken();
        if (refreshed) {
          headers = await _defaultHeaders(auth: true);
          res = await http.delete(uri, headers: headers);
        }
      }
      print('[ApiService] Response ${res.statusCode}: ${res.body}');
      return _handleResponse(res);
    } catch (e, s) {
      print('[ApiService] DELETE error $uri -> $e');
      print(s);
      rethrow;
    }
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  Future<bool> tryRefreshAccessToken() async {
    if (_refreshInProgress) {
      // If another request is refreshing already, let caller retry after a short wait.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final token = await getToken();
      return token != null && token.isNotEmpty;
    }

    _refreshInProgress = true;
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final uri = Uri.parse('$baseUrl/auth/refresh');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': refreshToken}),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final access = decoded['accessToken'] ?? decoded['access_token'];
      final refresh = decoded['refreshToken'] ?? decoded['refresh_token'] ?? refreshToken;

      if (access == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', access.toString());
      await prefs.setString('refreshToken', refresh.toString());
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshInProgress = false;
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
