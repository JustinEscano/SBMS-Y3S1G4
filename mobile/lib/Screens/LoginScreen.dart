import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'RegisterScreen.dart';
import 'DashboardScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingStoredLogin = true;
  String _errorMessage = '';

  final String baseUrl = 'http://10.0.2.2:8000/api';

  // SharedPreferences keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _emailKey = 'user_email';

  @override
  void initState() {
    super.initState();
    _checkStoredLogin();
  }

  /// Check if user is already logged in with stored tokens
  Future<void> _checkStoredLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      final storedEmail = prefs.getString(_emailKey);

      if (accessToken != null && refreshToken != null) {
        // Verify token is still valid by making a test request
        final isValid = await _verifyToken(accessToken);

        if (isValid) {
          // Navigate to dashboard if token is valid
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  accessToken: accessToken,
                  refreshToken: refreshToken,
                ),
              ),
            );
          }
          return;
        } else {
          // Token expired, try to refresh
          if (refreshToken.isNotEmpty) {
            final newTokens = await _refreshAccessToken(refreshToken);
            if (newTokens != null &&
                newTokens['access'] != null &&
                newTokens['refresh'] != null) {
              final newAccessToken = newTokens['access']!;
              final newRefreshToken = newTokens['refresh']!;

              await _saveTokens(newAccessToken, newRefreshToken, storedEmail ?? '');
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DashboardScreen(
                      accessToken: newAccessToken,
                      refreshToken: newRefreshToken,
                    ),
                  ),
                );
              }
              return;
            }
          }
          // Clear invalid tokens
          await _clearStoredTokens();
        }
      }

      // Pre-fill email if stored
      if (storedEmail != null && storedEmail.isNotEmpty) {
        _emailController.text = storedEmail;
      }
    } catch (e) {
      print('Error checking stored login: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStoredLogin = false;
        });
      }
    }
  }

  /// Verify if the access token is still valid
  Future<bool> _verifyToken(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/verify-token/'), // Adjust endpoint as needed
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Refresh the access token using refresh token
  Future<Map<String, String>?> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'refresh': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('access') && data['access'] != null) {
          return {
            'access': data['access'] as String,
            'refresh': refreshToken, // Keep the same refresh token
          };
        }
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
    return null;
  }

  /// Save tokens to SharedPreferences
  Future<void> _saveTokens(String accessToken, String refreshToken, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_emailKey, email);
  }

  /// Clear stored tokens from SharedPreferences
  Future<void> _clearStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    // Keep email for convenience
  }

  /// Static method to logout from anywhere in the app
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final requestBody = {
        'email': email,
        'password': password,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/token/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('access') &&
            data.containsKey('refresh') &&
            data['access'] != null &&
            data['refresh'] != null) {
          final accessToken = data['access'] as String;
          final refreshToken = data['refresh'] as String;

          // Save tokens to SharedPreferences
          await _saveTokens(accessToken, refreshToken, email);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  accessToken: accessToken,
                  refreshToken: refreshToken,
                ),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Invalid response from server - missing tokens';
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Invalid email or password';
        });
      } else if (response.statusCode == 400) {
        try {
          final errorData = json.decode(response.body);
          String errorMsg = 'Login failed: ';
          if (errorData is Map) {
            List<String> errors = [];
            errorData.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                errors.add('$key: ${value.first}');
              } else if (value is String) {
                errors.add('$key: $value');
              }
            });
            errorMsg += errors.join(', ');
          } else {
            errorMsg += 'Invalid request format';
          }

          setState(() {
            _errorMessage = errorMsg;
          });
        } catch (e) {
          setState(() {
            _errorMessage = 'Login failed. Please check your credentials.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Login failed. Server returned ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('SocketException')) {
          _errorMessage = 'Cannot connect to server. Check if Django is running on port 8000';
        } else if (e.toString().contains('TimeoutException')) {
          _errorMessage = 'Request timed out. Server might be slow or down';
        } else {
          _errorMessage = 'Error: ${e.toString()}';
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking stored login
    if (_isCheckingStoredLogin) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking login status...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Building Login'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.business,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                'Smart Building Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red[800]),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text('Don\'t have an account? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}