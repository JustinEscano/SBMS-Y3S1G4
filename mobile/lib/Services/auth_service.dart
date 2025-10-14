import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jwt_decode/jwt_decode.dart';
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
  static const int _maxRefreshRetries = 3;

  String? _accessToken;
  String? _refreshToken;
  late final ApiService apiService;
  int _refreshRetryCount = 0;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> setTokens(String access, String refresh, {String? email}) async {
    _accessToken = access;
    _refreshToken = refresh;
    _refreshRetryCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, access);
    await prefs.setString(_refreshTokenKey, refresh);
    if (email != null) {
      await prefs.setString(_emailKey, email);
    }
    print('Tokens set successfully. Access expiry: ${Jwt.parseJwt(access)['exp']}');
  }

  Future<String?> getStoredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _refreshRetryCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<bool> loadStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    if (_accessToken != null && _refreshToken != null) {
      print('Loaded stored tokens. Access expiry: ${Jwt.parseJwt(_accessToken!)['exp']}');
    }
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

  // Restored verifyToken using expiry check instead of API call
  Future<bool> verifyToken() async {
    if (_accessToken == null) {
      await loadStoredTokens();
      if (_accessToken == null) return false;
    }
    return !_isTokenExpired(_accessToken!);
  }

  bool _isTokenExpired(String token) {
    try {
      final decoded = Jwt.parseJwt(token);
      final exp = decoded['exp'] as int?;
      if (exp == null) return true;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      final buffer = const Duration(minutes: 1);
      return now.add(buffer).isAfter(expiryDate);
    } catch (e) {
      print('Error parsing token expiry: $e');
      return true;
    }
  }

  Future<bool> refresh({int retryCount = 0}) async {
    if (_refreshToken == null) {
      print('No refresh token available');
      return false;
    }

    if (retryCount >= _maxRefreshRetries) {
      print('Max refresh retries exceeded ($retryCount). Logging out.');
      await logout();
      return false;
    }

    try {
      print('Attempting refresh (retry $retryCount)...');
      final response = await http.post(
        Uri.parse(ApiConfig.refreshToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      ).timeout(const Duration(seconds: 10));

      print('Refresh response status: ${response.statusCode}');
      print('Refresh response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access'] != null) {
          _accessToken = data['access'];
          _refreshToken = data['refresh'] ?? _refreshToken;
          _refreshRetryCount = 0;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_accessTokenKey, _accessToken!);
          if (data['refresh'] != null) {
            await prefs.setString(_refreshTokenKey, data['refresh']);
            _refreshToken = data['refresh'];
          }

          print('Refresh successful. New access expiry: ${Jwt.parseJwt(_accessToken!)['exp']}');
          return true;
        } else {
          print('Refresh response missing "access" field: $data');
          return false;
        }
      } else if (response.statusCode == 400) {
        print('Invalid refresh token (400). Logging out.');
        await logout();
        return false;
      } else if (response.statusCode == 401) {
        print('Unauthorized refresh (401). Retrying...');
        return await refresh(retryCount: retryCount + 1);
      } else {
        print('Unexpected refresh status: ${response.statusCode}. Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Refresh failed: $e');
      if (retryCount < _maxRefreshRetries - 1) {
        print('Retrying refresh...');
        return await refresh(retryCount: retryCount + 1);
      } else {
        await logout();
        return false;
      }
    }
  }

  Future<bool> ensureValidToken() async {
    if (_accessToken == null) {
      final loaded = await loadStoredTokens();
      if (!loaded) return false;
    }

    if (!_isTokenExpired(_accessToken!)) {
      print('Access token is still valid.');
      return true;
    }

    print('Access token expired. Attempting refresh...');
    return await refresh(retryCount: _refreshRetryCount);
  }

  Future<void> logout() async {
    _refreshRetryCount = 0;
    await clearTokens();
    print('Logged out successfully.');
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