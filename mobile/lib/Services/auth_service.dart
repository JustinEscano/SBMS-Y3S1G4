import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Config/api.dart'; // Your API config

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  // Set tokens (call after login or on app start)
  void setTokens(String access, String refresh) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  // Clear tokens (logout)
  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  // Get headers with auth
  Map<String, String> getAuthHeaders({bool useRefresh = false}) {
    final token = useRefresh ? _refreshToken : _accessToken;
    if (token == null) return {'Content-Type': 'application/json'};
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // Refresh token
  Future<bool> refresh() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.refreshToken), // e.g., '/api/token/refresh/'
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        _refreshToken = data['refresh'] ?? _refreshToken; // Rotate if provided
        return true;
      }
      return false;
    } catch (e) {
      print('Refresh failed: $e'); // Use logger in prod
      return false;
    }
  }

  // Ensure valid token (refresh if needed)
  Future<bool> ensureValidToken() async {
    if (_accessToken == null) return false;
    // Optional: Add JWT decode to check exp (requires jwt_decode package)
    return await refresh(); // For now, refresh proactively or on 401
  }
}