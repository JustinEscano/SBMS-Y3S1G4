import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../Config/api.dart';
import '../Services/auth_service.dart';
import './ProfileScreen.dart';
import './LoginScreen.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const ChangePasswordScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  int _step = 1; // 1: Email, 2: OTP, 3: New Password

  final Dio _dio = Dio();

  Future<bool> _refreshToken() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.refresh();
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, authService.accessToken!);
        await prefs.setString(_refreshTokenKey, authService.refreshToken!);
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Token refresh failed: $e', name: 'ChangePasswordScreen.Token');
      return false;
    }
  }

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
            'Authorization': 'Bearer ${widget.accessToken}',
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
      if (e.toString().contains('401')) {
        final success = await _refreshToken();
        if (success) {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final response = await _dio.post(
              '${ApiConfig.baseUrl}/otp-password/request/',
              data: {'email': email},
              options: Options(
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer ${authService.accessToken}',
                },
              ),
            );

            if (response.statusCode == 200) {
              setState(() {
                _step = 2;
              });
            } else {
              setState(() {
                _errorMessage = 'Failed to send OTP after retry. Please try again.';
              });
            }
            return;
          } catch (retryError) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error sending OTP after retry: $retryError', style: GoogleFonts.urbanist()),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
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
            'Authorization': 'Bearer ${widget.accessToken}',
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
      if (e.toString().contains('401')) {
        final success = await _refreshToken();
        if (success) {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final response = await _dio.post(
              '${ApiConfig.baseUrl}/otp-password/verify-otp/',
              data: {'email': email, 'otp': otp},
              options: Options(
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer ${authService.accessToken}',
                },
              ),
            );

            if (response.statusCode == 200) {
              setState(() {
                _step = 3;
              });
            } else {
              setState(() {
                _errorMessage = 'Invalid OTP after retry. Please try again.';
              });
            }
            return;
          } catch (retryError) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error verifying OTP after retry: $retryError', style: GoogleFonts.urbanist()),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
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
            'Authorization': 'Bearer ${widget.accessToken}',
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
                builder: (context) => ProfileScreen(
                  accessToken: accessToken,
                  refreshToken: refreshToken,
                ),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Password changed successfully', style: GoogleFonts.urbanist()),
                backgroundColor: Color(0xFF184BFB),
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
          _errorMessage = 'Failed to change password. Please try again.';
        });
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        final success = await _refreshToken();
        if (success) {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final response = await _dio.patch(
              '${ApiConfig.baseUrl}/otp-password/verify/',
              data: {'email': email, 'otp': otp, 'password': password},
              options: Options(
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer ${authService.accessToken}',
                },
              ),
            );

            if (response.statusCode == 200) {
              final data = response.data;
              if (data.containsKey('access') && data.containsKey('refresh')) {
                final accessToken = data['access'] as String;
                final refreshToken = data['refresh'] as String;

                await authService.setTokens(accessToken, refreshToken, email: email);
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        accessToken: accessToken,
                        refreshToken: refreshToken,
                      ),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password changed successfully', style: GoogleFonts.urbanist()),
                      backgroundColor: Color(0xFF184BFB),
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
                _errorMessage = 'Failed to change password after retry. Please try again.';
              });
            }
            return;
          } catch (retryError) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error changing password after retry: $retryError', style: GoogleFonts.urbanist()),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 50.0,
              floating: false,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Change Password',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  color: Color(0xFF1F1E23),
                ),
              ),
              foregroundColor: Colors.white,
              backgroundColor: Color(0xFF1F1E23),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_step == 1) ...[
                        Text(
                          'Email',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: GoogleFonts.urbanist(color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF121822),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: GoogleFonts.urbanist(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                      ] else if (_step == 2) ...[
                        Text(
                          'OTP',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otpController,
                          decoration: InputDecoration(
                            hintText: 'Enter OTP',
                            hintStyle: GoogleFonts.urbanist(color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF121822),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: GoogleFonts.urbanist(color: Colors.white),
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
                        Text(
                          'New Password',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            hintText: 'Enter new password',
                            hintStyle: GoogleFonts.urbanist(color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF121822),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: GoogleFonts.urbanist(color: Colors.white),
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
                        Text(
                          'Confirm Password',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            hintText: 'Confirm new password',
                            hintStyle: GoogleFonts.urbanist(color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF121822),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: GoogleFonts.urbanist(color: Colors.white),
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
                            color: Color(0xFF121822),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage,
                            style: GoogleFonts.urbanist(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
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
                            backgroundColor: Color(0xFF184BFB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : Text(
                            _step == 1
                                ? 'Send OTP'
                                : _step == 2
                                ? 'Verify OTP'
                                : 'Change Password',
                            style: GoogleFonts.urbanist(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ).animate().scale(duration: 200.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
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