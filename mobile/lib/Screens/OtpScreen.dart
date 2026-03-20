import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../Screens/DashboardScreen.dart';
import '../Services/auth_service.dart';
import '../Config/api.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  int _step = 1; // 1: Email, 2: OTP, 3: New Password

  final Dio _dio = Dio();

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/otp-password/request/',
        data: {'email': email},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _step = 2;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to send OTP. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/otp-password/verify-otp/',
        data: {'email': email, 'otp': otp},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _step = 3;
        });
      } else {
        setState(() {
          _errorMessage = 'Invalid OTP. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _dio.patch(
        '${ApiConfig.baseUrl}/otp-password/verify/',
        data: {'email': email, 'otp': otp, 'password': password},
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

          final authService = AuthService();
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
      } else {
        setState(() {
          _errorMessage = 'Failed to reset password. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
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
                    'Reset Password',
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFFFFFFFF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  if (_step == 1) ...[
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
                  ] else if (_step == 2) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'OTP',
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
                      controller: _otpController,
                      decoration: InputDecoration(
                        hintText: 'Enter OTP',
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
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter OTP';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ] else if (_step == 3) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'New Password',
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
                        hintText: 'Enter new password',
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
                          return 'Please enter new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Confirm Password',
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
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        hintText: 'Confirm new password',
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
                          return 'Please confirm password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
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
                      onPressed: _isLoading
                          ? null
                          : () {
                        if (_step == 1) {
                          _requestOtp();
                        } else if (_step == 2) {
                          _verifyOtp();
                        } else if (_step == 3) {
                          _resetPassword();
                        }
                      },
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
                          : Text(
                        _step == 1
                            ? 'Send OTP'
                            : _step == 2
                            ? 'Verify OTP'
                            : 'Reset Password',
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          color: Color(0xFFFFFFFF),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Back to Login',
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}