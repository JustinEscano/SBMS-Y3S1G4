import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../Screens/RegisterScreen.dart';
import '../Screens/DashboardScreen.dart';
import '../Screens/OtpScreen.dart';
import '../Services/auth_service.dart';
import '../utils/constants.dart';

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
  String _errorMessage = '';

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadStoredEmail();
  }

  Future<void> _loadStoredEmail() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final storedEmail = await authService.getStoredEmail();
      if (storedEmail != null && storedEmail.isNotEmpty) {
        _emailController.text = storedEmail;
      }
    } catch (e) {
      print('Error loading stored email: $e');
    }
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

          final authService = Provider.of<AuthService>(context, listen: false);
          await authService.setTokens(accessToken, refreshToken, email: email);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(accessToken: accessToken),
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
            _errorMessage = 'Error: ${e.message ?? e.toString()}';
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
    return Scaffold(
      backgroundColor: const Color(0xFF161C28),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Image.asset(
                    'assets/icons/ORBIT.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Login To Continue',
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFFFFFFFF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email',
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      hintStyle: const TextStyle(
                        fontFamily: 'Arial',
                        color: Color(0xFF676767),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF28292E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: Color(0xFFFFFFFF),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: const TextStyle(
                        fontFamily: 'Arial',
                        color: Color(0xFF676767),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF28292E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: Color(0xFFFFFFFF),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OtpScreen()),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          color: Color(0xFF4D6BFE),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF28292E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4D6BFE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFFFFF)),
                        ),
                      )
                          : const Text(
                        'Login',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: Color(0xFFFFFFFF),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          color: Color(0xFFFFFFFF),
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          'Sign Up',
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            color: Color(0xFF4D6BFE),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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