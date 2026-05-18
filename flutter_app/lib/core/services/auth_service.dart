import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  String? accessToken;
  String? refreshToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('accessToken');
    refreshToken = prefs.getString('refreshToken');
    // Debug
    if (accessToken != null) {
      print('[AuthService] init: accessToken present (masked) ${_mask(accessToken!)}');
    } else {
      print('[AuthService] init: no accessToken');
    }
    if (refreshToken != null) {
      print('[AuthService] init: refreshToken present (masked) ${_mask(refreshToken!)}');
    }
  }

  bool get isLoggedIn => accessToken != null;

  Future<void> saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', access);
    await prefs.setString('refreshToken', refresh);
    print('[AuthService] saveTokens: saved access (masked) ${_mask(access)} refresh (masked) ${_mask(refresh)}');
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    print('[AuthService] clear: tokens removed');
  }

  Future<bool> login(String email, String password) async {
    final api = ApiService.instance;
    print('[AuthService] login: email=$email, passwordLength=${password.length}');
    final res = await api.post('/auth/login', {'email': email, 'password': password}, auth: false);
    if (res == null) return false;
    final access = res['accessToken'] ?? res['access_token'] ?? res['access'];
    final refresh = res['refreshToken'] ?? res['refresh_token'] ?? res['refresh'];
    if (access != null && refresh != null) {
      await saveTokens(access, refresh);
      return true;
    }
    print('[AuthService] login: unexpected response $res');
    return false;
  }

  Future<bool> signup(String email, String password) async {
    final api = ApiService.instance;
    print('[AuthService] signup: email=$email, passwordLength=${password.length}');
    final res = await api.post('/auth/signup', {'email': email, 'password': password}, auth: false);
    if (res == null) return false;
    // after signup, automatically login if tokens returned
    final access = res['accessToken'] ?? res['access_token'];
    final refresh = res['refreshToken'] ?? res['refresh_token'];
    if (access != null && refresh != null) {
      await saveTokens(access, refresh);
      return true;
    }
    print('[AuthService] signup: unexpected response $res');
    return false;
  }

  Future<bool> refresh() async {
    if (refreshToken == null) return false;
    final api = ApiService.instance;
    try {
      print('[AuthService] refresh: refreshing with (masked) ${_mask(refreshToken!)}');
      final res = await api.post('/auth/refresh', {'token': refreshToken}, auth: false);
      if (res == null) return false;
      final access = res['accessToken'] ?? res['access_token'];
      final refresh = res['refreshToken'] ?? res['refresh_token'];
      if (access != null && refresh != null) {
        await saveTokens(access, refresh);
        return true;
      }
    } catch (_) {}
    return false;
  }

  String _mask(String s) {
    if (s.length <= 8) return '****';
    return s.substring(0,4) + '...' + s.substring(s.length-4);
  }
}
