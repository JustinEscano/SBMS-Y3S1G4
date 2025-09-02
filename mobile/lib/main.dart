import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const SmartBuildingApp());
}

class SmartBuildingApp extends StatelessWidget {
  const SmartBuildingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Building Management',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF323339),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4D6BFE),
          secondary: const Color(0xFF81C784),
          surface: const Color(0xFF424242),
          background: const Color(0xFF323339),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF424242),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF424242),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4D6BFE),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4D6BFE),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF4D6BFE),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF424242),
          selectedItemColor: Color(0xFF4D6BFE),
          unselectedItemColor: Color(0xFF757575),
          type: BottomNavigationBarType.fixed,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF424242),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF616161)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF616161)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4D6BFE), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFBDBDBD)),
          hintStyle: const TextStyle(color: Color(0xFF757575)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF616161),
          labelStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// New AuthWrapper to check for existing tokens
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _accessToken;
  String? _refreshToken;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');

      if (accessToken != null && refreshToken != null) {
        // Verify token is still valid
        final isValid = await _verifyToken(accessToken);
        if (isValid) {
          setState(() {
            _isLoggedIn = true;
            _accessToken = accessToken;
            _refreshToken = refreshToken;
          });
        } else {
          // Try to refresh the token
          final newTokens = await _refreshAccessToken(refreshToken);
          if (newTokens != null) {
            final newAccessToken = newTokens['access'] as String?;
            final newRefreshToken = newTokens['refresh'] as String?;

            if (newAccessToken != null && newRefreshToken != null) {
              await _saveTokens(newAccessToken, newRefreshToken);
              setState(() {
                _isLoggedIn = true;
                _accessToken = newAccessToken;
                _refreshToken = newRefreshToken;
              });
            } else {
              await _clearTokens();
            }
          } else {
            // Clear invalid tokens
            await _clearTokens();
          }
        }
      }
    } catch (e) {
      print('Error checking auth status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/rooms/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>?> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/token/refresh/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'refresh': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'access': data['access'] as String,
          'refresh': refreshToken, // Keep the same refresh token
        };
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
    return null;
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF4D6BFE)),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn && _accessToken != null && _refreshToken != null) {
      return MainScreen(
        accessToken: _accessToken!,
        refreshToken: _refreshToken!,
      );
    }

    return const LoginScreen();
  }
}

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

  final String baseUrl = 'http://10.0.2.2:8000/api';

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
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

        if (data.containsKey('access') && data.containsKey('refresh')) {
          final accessToken = data['access'] as String;
          final refreshToken = data['refresh'] as String;

          // Save tokens to persistent storage
          await _saveTokens(accessToken, refreshToken);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(
                accessToken: accessToken,
                refreshToken: refreshToken,
              ),
            ),
          );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Building Login'),
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
                color: Color(0xFF4D6BFE),
              ),
              const SizedBox(height: 32),
              const Text(
                'Smart Building Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email, color: Color(0xFF4D6BFE)),
                ),
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
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
                  prefixIcon: Icon(Icons.lock, color: Color(0xFF4D6BFE)),
                ),
                obscureText: true,
                style: const TextStyle(color: Colors.white),
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
                    color: const Color(0xFF5D4037),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE57373)),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Color(0xFFFFCDD2)),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
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

  final String baseUrl = 'http://10.0.2.2:8000/api';

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

    final requestData = {
      'username': _usernameController.text,
      'email': _emailController.text,
      'password': _passwordController.text,
      'role': _selectedRole,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please login with your email.'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = 'Registration failed. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
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
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Icon(
                  Icons.person_add,
                  size: 80,
                  color: Color(0xFF4D6BFE),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person, color: Color(0xFF4D6BFE)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: Color(0xFF4D6BFE)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work, color: Color(0xFF4D6BFE)),
                  ),
                  dropdownColor: const Color(0xFF424242),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'client', child: Text('Client')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: Color(0xFF4D6BFE)),
                  ),
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF4D6BFE)),
                  ),
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
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
                      color: const Color(0xFF5D4037),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE57373)),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Color(0xFFFFCDD2)),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Register'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Already have an account? Login'),
                ),
              ],
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

// Main Screen with Bottom Navigation
class MainScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const MainScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        accessToken: widget.accessToken,
        refreshToken: widget.refreshToken,
      ),
      const AnalyticsScreen(),
      const NotificationsScreen(),
      const ChatbotScreen(),
    ];
  }

  Future<void> _logout() async {
    // Clear stored tokens
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chatbot',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Smart Building Dashboard';
      case 1:
        return 'Analytics';
      case 2:
        return 'Notifications';
      case 3:
        return 'AI Assistant';
      default:
        return 'Smart Building';
    }
  }
}

class DashboardScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const DashboardScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> rooms = [];
  List<dynamic> equipment = [];
  List<dynamic> sensorLogs = [];
  List<dynamic> latestSensorData = [];
  bool isLoading = true;
  bool isAutoRefresh = true;
  Timer? _refreshTimer;

  final String baseUrl = 'http://10.0.2.2:8000/api';

  @override
  void initState() {
    super.initState();
    loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (isAutoRefresh && mounted) {
        loadLatestSensorData();
      }
    });
  }

  void _toggleAutoRefresh() {
    setState(() {
      isAutoRefresh = !isAutoRefresh;
    });

    if (isAutoRefresh) {
      _startAutoRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final headers = {
        'Authorization': 'Bearer ${widget.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/rooms/'), headers: headers),
        http.get(Uri.parse('$baseUrl/equipment/'), headers: headers),
        http.get(Uri.parse('$baseUrl/sensorlog/'), headers: headers),
        http.get(Uri.parse('$baseUrl/esp32/latest/')),
      ]).timeout(const Duration(seconds: 10));

      if (responses[0].statusCode == 200) {
        final roomsData = json.decode(responses[0].body);
        setState(() {
          rooms = roomsData is List ? roomsData : [];
        });
      }

      if (responses[1].statusCode == 200) {
        final equipmentData = json.decode(responses[1].body);
        setState(() {
          equipment = equipmentData is List ? equipmentData : [];
        });
      }

      if (responses[2].statusCode == 200) {
        final sensorData = json.decode(responses[2].body);
        setState(() {
          sensorLogs = sensorData is List ? sensorData : [];
        });
      }

      if (responses[3].statusCode == 200) {
        final latestData = json.decode(responses[3].body);
        if (latestData['success'] == true) {
          setState(() {
            latestSensorData = latestData['data'] ?? [];
          });
        }
      }
    } catch (e) {
      // Handle errors silently in production
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadLatestSensorData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/esp32/latest/'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final latestData = json.decode(response.body);
        if (latestData['success'] == true && mounted) {
          setState(() {
            latestSensorData = latestData['data'] ?? [];
          });
        }
      }
    } catch (e) {
      // Handle errors silently for background refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D6BFE)))
        : SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto-refresh indicator and controls
          Row(
            children: [
              if (isAutoRefresh)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.autorenew, size: 16, color: Color(0xFF81C784)),
                      const SizedBox(width: 4),
                      const Text(
                        'Auto-refresh ON (10s)',
                        style: TextStyle(color: Color(0xFF81C784), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isAutoRefresh ? Icons.pause : Icons.play_arrow,
                  color: const Color(0xFF4D6BFE),
                ),
                onPressed: _toggleAutoRefresh,
                tooltip: isAutoRefresh ? 'Pause Auto Refresh' : 'Start Auto Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF4D6BFE)),
                onPressed: loadData,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overview Cards
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Rooms',
                  rooms.length.toString(),
                  Icons.room,
                  const Color(0xFF4D6BFE),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewCard(
                  'Equipment',
                  equipment.length.toString(),
                  Icons.devices,
                  const Color(0xFF81C784),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'ESP32 Devices',
                  latestSensorData.length.toString(),
                  Icons.memory,
                  const Color(0xFFBA68C8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewCard(
                  'Online',
                  latestSensorData.where((e) => e['status'] == 'online').length.toString(),
                  Icons.online_prediction,
                  const Color(0xFF81C784),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Live Sensor Data
          if (latestSensorData.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.sensors, color: Color(0xFFFFB74D)),
                const SizedBox(width: 8),
                const Text(
                  'Live ESP32 Sensor Data',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFFFFB74D),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...latestSensorData.map((sensorData) => Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.memory,
                          color: sensorData['status'] == 'online'
                              ? const Color(0xFF81C784)
                              : const Color(0xFFE57373),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sensorData['equipment_name'] ?? 'Unknown Device',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sensorData['status'] == 'online'
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF5D4037),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            sensorData['status']?.toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              color: sensorData['status'] == 'online'
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFFE57373),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Device ID: ${sensorData['device_id'] ?? 'N/A'}',
                      style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSensorValue(
                            'Temperature',
                            '${sensorData['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C',
                            Icons.thermostat,
                            const Color(0xFFE57373),
                          ),
                        ),
                        Expanded(
                          child: _buildSensorValue(
                            'Humidity',
                            '${sensorData['humidity']?.toStringAsFixed(1) ?? 'N/A'}%',
                            Icons.water_drop,
                            const Color(0xFF4D6BFE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSensorValue(
                            'Light Level',
                            '${sensorData['light_level']?.toStringAsFixed(0) ?? 'N/A'}',
                            Icons.light_mode,
                            const Color(0xFFFFD54F),
                          ),
                        ),
                        Expanded(
                          child: _buildSensorValue(
                            'Motion',
                            sensorData['motion_detected'] == true ? 'Detected' : 'None',
                            Icons.motion_photos_on,
                            sensorData['motion_detected'] == true
                                ? const Color(0xFFFFB74D)
                                : const Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Update: ${_formatDateTime(sensorData['recorded_at'])}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                    ),
                  ],
                ),
              ),
            )).toList(),
            const SizedBox(height: 24),
          ],

          // Rooms Section
          if (rooms.isNotEmpty) ...[
            const Text(
              'Rooms',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            ...rooms.map((room) => Card(
              child: ListTile(
                leading: const Icon(Icons.room, color: Color(0xFF4D6BFE)),
                title: Text(
                  room['name'] ?? 'Unknown Room',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Floor ${room['floor']} • Capacity: ${room['capacity']}',
                  style: const TextStyle(color: Color(0xFFBDBDBD)),
                ),
                trailing: Chip(
                  label: Text(room['type'] ?? 'Unknown'),
                  backgroundColor: const Color(0xFF1976D2),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
            )).toList(),
            const SizedBox(height: 24),
          ],

          // Equipment Section
          if (equipment.isNotEmpty) ...[
            const Text(
              'Equipment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            ...equipment.map((item) {
              Color statusColor = item['status'] == 'online'
                  ? const Color(0xFF81C784)
                  : const Color(0xFFE57373);
              return Card(
                child: ListTile(
                  leading: Icon(Icons.devices, color: statusColor),
                  title: Text(
                    item['name'] ?? 'Unknown Equipment',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Type: ${item['type']} • Device ID: ${item['device_id'] ?? 'N/A'}',
                    style: const TextStyle(color: Color(0xFFBDBDBD)),
                  ),
                  trailing: Chip(
                    label: Text(item['status'] ?? 'Unknown'),
                    backgroundColor: statusColor.withOpacity(0.3),
                    labelStyle: TextStyle(color: statusColor),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
          ],

          // Recent Sensor Data
          if (sensorLogs.isNotEmpty) ...[
            const Text(
              'Recent Sensor Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            ...sensorLogs.take(5).map((log) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equipment ID: ${log['equipment']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSensorValue('Temp', '${log['temperature']}°C', Icons.thermostat),
                        _buildSensorValue('Humidity', '${log['humidity']}%', Icons.water_drop),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSensorValue('Light', '${log['light_level']}', Icons.light_mode),
                        _buildSensorValue('Motion', log['motion_detected'] ? 'Yes' : 'No', Icons.motion_photos_on),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recorded: ${log['recorded_at']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ],

          // No Data Available
          if (rooms.isEmpty && equipment.isEmpty && sensorLogs.isEmpty && latestSensorData.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, size: 48, color: Color(0xFF757575)),
                    const SizedBox(height: 16),
                    const Text(
                      'No Data Available',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add some rooms and equipment in Django admin to see them here.',
                      style: TextStyle(color: Color(0xFFBDBDBD)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Data'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorValue(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? const Color(0xFF4D6BFE)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

// Empty Analytics Screen
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 80,
            color: Color(0xFF757575),
          ),
          SizedBox(height: 16),
          Text(
            'Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Empty Notifications Screen
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications,
            size: 80,
            color: Color(0xFF757575),
          ),
          SizedBox(height: 16),
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Empty Chatbot Screen
class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat,
            size: 80,
            color: Color(0xFF757575),
          ),
          SizedBox(height: 16),
          Text(
            'AI Assistant',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}