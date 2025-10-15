import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../Config/api.dart';
import 'LoginScreen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedRole = 'client';

  final Dio _dio = Dio();

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'role': _selectedRole,
        },
        options: Options(
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 201) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please login with your email.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Registration failed. Server returned ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionError) {
            _errorMessage = 'Cannot connect to server. Check if Django is running on port 8000';
          } else if (e.response?.statusCode == 400) {
            final data = e.response?.data;
            if (data is Map) {
              _errorMessage = data.entries
                  .map((e) => "${e.key}: ${(e.value is List ? e.value.first : e.value)}")
                  .join(', ');
            } else {
              _errorMessage = 'Invalid input format';
            }
          } else {
            _errorMessage = 'Error: ${e.message}';
          }
        } else {
          _errorMessage = 'Error: $e';
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF161C28);
    const fieldBg = Color(0xFF28292E);
    const textColor = Color(0xFFFFFFFF);
    const accentColor = Color(0xFF4D6BFE);
    const hintColor = Color(0xFF9E9E9E);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
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
                  const Text(
                    'Create Your Account',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Username
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: hintColor),
                      prefixIcon: const Icon(Icons.person, color: hintColor),
                      filled: true,
                      fillColor: fieldBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: accentColor, width: 1.5),
                      ),
                      floatingLabelStyle: const TextStyle(color: accentColor),
                    ),
                    style: const TextStyle(color: textColor),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your username';
                      if (value.length < 3) return 'Username must be at least 3 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: hintColor),
                      prefixIcon: const Icon(Icons.email, color: hintColor),
                      filled: true,
                      fillColor: fieldBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: accentColor, width: 1.5),
                      ),
                      floatingLabelStyle: const TextStyle(color: accentColor),
                    ),
                    style: const TextStyle(color: textColor),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: fieldBg,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      labelStyle: const TextStyle(color: hintColor),
                      prefixIcon: const Icon(Icons.work, color: hintColor),
                      filled: true,
                      fillColor: fieldBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: accentColor, width: 1.5),
                      ),
                      floatingLabelStyle: const TextStyle(color: accentColor),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'client',
                        child: Text('Client', style: TextStyle(color: textColor)),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Admin', style: TextStyle(color: textColor)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedRole = value!),
                    style: const TextStyle(color: textColor),
                  ),
                  const SizedBox(height: 24),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: hintColor),
                      prefixIcon: const Icon(Icons.lock, color: hintColor),
                      filled: true,
                      fillColor: fieldBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: accentColor, width: 1.5),
                      ),
                      floatingLabelStyle: const TextStyle(color: accentColor),
                    ),
                    style: const TextStyle(color: textColor),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a password';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: hintColor),
                      prefixIcon: const Icon(Icons.lock_outline, color: hintColor),
                      filled: true,
                      fillColor: fieldBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: accentColor, width: 1.5),
                      ),
                      floatingLabelStyle: const TextStyle(color: accentColor),
                    ),
                    style: const TextStyle(color: textColor),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
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
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      )
                          : const Text(
                        'Register',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login Redirect
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: textColor,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontFamily: 'Arial',
                            color: accentColor,
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
