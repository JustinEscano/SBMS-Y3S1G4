import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/constants.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    apiService = ApiService(this);
  }

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _emailKey = 'user_email';

  String? _accessToken;
  String? _refreshToken;
  late final ApiService apiService;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> setTokens(String access, String refresh, {String? email}) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, access);
    await prefs.setString(_refreshTokenKey, refresh);
    if (email != null) {
      await prefs.setString(_emailKey, email);
    }
  }

  Future<String?> getStoredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<bool> loadStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    return _accessToken != null && _refreshToken != null;
  }

  Map<String, String> getAuthHeaders({bool useRefresh = false}) {
    final token = useRefresh ? _refreshToken : _accessToken;
    if (token == null) return {'Content-Type': 'application/json'};
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<bool> verifyToken() async {
    if (_accessToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': _accessToken}),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> refresh() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.refreshToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        _refreshToken = data['refresh'] ?? _refreshToken;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, _accessToken!);
        if (data['refresh'] != null) {
          await prefs.setString(_refreshTokenKey, data['refresh']);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Refresh failed: $e');
      return false;
    }
  }

  Future<bool> ensureValidToken() async {
    if (_accessToken == null) {
      await loadStoredTokens();
      if (_accessToken == null) return false;
    }
    final isValid = await verifyToken();
    if (isValid) return true;
    return await refresh();
  }

  Future<void> logout() async {
    await clearTokens();
  }

  Future<String?> getCurrentUserId() async {
    if (!(await ensureValidToken())) {
      throw Exception('Invalid or expired token');
    }
    try {
      final headers = getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.userInfo),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        return userData['id']?.toString();
      }
      throw Exception('Failed to load user ID: ${response.statusCode}');
    } catch (e) {
      print('Failed to fetch user ID: $e');
      return null;
    }
  }
}