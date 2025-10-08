import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Screens/RegisterScreen.dart';
import '../Screens/DashboardScreen.dart';
import '../Config/api.dart';

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

  // SharedPreferences keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _emailKey = 'user_email';

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _checkStoredLogin();
  }

  // Check if user is already logged in with stored tokens
  Future<void> _checkStoredLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      final storedEmail = prefs.getString(_emailKey);

      if (accessToken != null && refreshToken != null) {
        // Verify token is still valid
        final isValid = await _verifyToken(accessToken);
        if (isValid) {
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
          // Try refreshing token
          final newToken = await _refreshToken(refreshToken);
          if (newToken != null) {
            await prefs.setString(_accessTokenKey, newToken);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    accessToken: newToken,
                    refreshToken: refreshToken,
                  ),
                ),
              );
            }
            return;
          }
          // Clear invalid tokens
          await _clearStoredTokens();
        }
      }

      // Pre-fill email if stored
      if (storedEmail != null && storedEmail.isNotEmpty) {
        _emailController.text = storedEmail;
      }

      // Fetch username from profile if available
      if (accessToken != null) {
        try {
          final response = await _dio.get(
            ApiConfig.profile,
            options: Options(
              headers: {'Authorization': 'Bearer $accessToken'},
            ),
          );
          if (response.statusCode == 200 && response.data['username'] != null) {
            _emailController.text = response.data['username'];
          }
        } catch (e) {
          // Ignore profile fetch errors
        }
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

  // Verify token
  Future<bool> _verifyToken(String accessToken) async {
    try {
      final response = await _dio.get(
        ApiConfig.verifyToken,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Refresh token
  Future<String?> _refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        ApiConfig.refreshToken,
        data: {'refresh': refreshToken},
      );
      if (response.statusCode == 200) {
        return response.data['access'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Save tokens
  Future<void> _saveTokens(String accessToken, String refreshToken, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_emailKey, email);
  }

  // Clear tokens
  Future<void> _clearStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    // Keep email for convenience
  }

  // Static logout method
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  // Login
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
      final response = await _dio.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data.containsKey('access') && data.containsKey('refresh')) {
          final accessToken = data['access'] as String;
          final refreshToken = data['refresh'] as String;

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
        setState(() {
          final errorData = response.data;
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
          _errorMessage = errorMsg;
        });
      } else {
        setState(() {
          _errorMessage = 'Login failed. Server returned ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            _errorMessage = 'Request timed out. Server might be slow or down';
          } else if (e.type == DioExceptionType.connectionError) {
            _errorMessage = 'Cannot connect to server. Check if Django is running on port 8000';
          } else {
            _errorMessage = 'Error: ${e.message}';
          }
        } else {
          _errorMessage = 'Error: $e';
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
                  labelText: 'Email or Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email or username';
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