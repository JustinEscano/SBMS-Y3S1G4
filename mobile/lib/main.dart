import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  final String baseUrl = 'http://10.0.2.2:8000/api';

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('access') && data.containsKey('refresh')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                accessToken: data['access'],
                refreshToken: data['refresh'],
              ),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Invalid response from server';
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Invalid username or password';
        });
      } else {
        setState(() {
          _errorMessage = 'Login failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('SocketException')) {
          _errorMessage = 'Cannot connect to server. Please check your connection.';
        } else if (e.toString().contains('TimeoutException')) {
          _errorMessage = 'Request timed out. Please try again.';
        } else {
          _errorMessage = 'An error occurred. Please try again.';
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
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
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
    _usernameController.dispose();
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

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'role': _selectedRole,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = 'Registration failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                  color: Colors.blue,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
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
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator()
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

      // Load all data concurrently
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/rooms/'), headers: headers),
        http.get(Uri.parse('$baseUrl/equipment/'), headers: headers),
        http.get(Uri.parse('$baseUrl/sensorlog/'), headers: headers),
        http.get(Uri.parse('$baseUrl/esp32/latest/')), // New ESP32 endpoint
      ]).timeout(const Duration(seconds: 10));

      // Process rooms
      if (responses[0].statusCode == 200) {
        final roomsData = json.decode(responses[0].body);
        setState(() {
          rooms = roomsData is List ? roomsData : [];
        });
      }

      // Process equipment
      if (responses[1].statusCode == 200) {
        final equipmentData = json.decode(responses[1].body);
        setState(() {
          equipment = equipmentData is List ? equipmentData : [];
        });
      }

      // Process sensor logs
      if (responses[2].statusCode == 200) {
        final sensorData = json.decode(responses[2].body);
        setState(() {
          sensorLogs = sensorData is List ? sensorData : [];
        });
      }

      // Process latest ESP32 sensor data
      if (responses[3].statusCode == 200) {
        final latestData = json.decode(responses[3].body);
        if (latestData['success'] == true) {
          setState(() {
            latestSensorData = latestData['data'] ?? [];
          });
        }
      }
    } catch (e) {
      print('Error loading data: $e');
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
      // Silently handle errors for background refresh
      print('Error loading latest sensor data: $e');
    }
  }

  void _logout() {
    _refreshTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Smart Building Dashboard'),
        actions: [
          IconButton(
            icon: Icon(isAutoRefresh ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleAutoRefresh,
            tooltip: isAutoRefresh ? 'Pause Auto Refresh' : 'Start Auto Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto-refresh indicator
            if (isAutoRefresh)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.autorenew, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-refresh ON (10s)',
                      style: TextStyle(color: Colors.green[700], fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Overview Cards
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    'Rooms',
                    rooms.length.toString(),
                    Icons.room,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildOverviewCard(
                    'Equipment',
                    equipment.length.toString(),
                    Icons.devices,
                    Colors.green,
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
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildOverviewCard(
                    'Online',
                    latestSensorData.where((e) => e['status'] == 'online').length.toString(),
                    Icons.online_prediction,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Real-time ESP32 Sensor Data
            if (latestSensorData.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.sensors, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Live ESP32 Sensor Data',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.orange[700],
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
                            color: sensorData['status'] == 'online' ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sensorData['equipment_name'] ?? 'Unknown Device',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: sensorData['status'] == 'online'
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              sensorData['status']?.toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(
                                color: sensorData['status'] == 'online'
                                    ? Colors.green[700]
                                    : Colors.red[700],
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSensorValue(
                              'Temperature',
                              '${sensorData['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C',
                              Icons.thermostat,
                              Colors.red,
                            ),
                          ),
                          Expanded(
                            child: _buildSensorValue(
                              'Humidity',
                              '${sensorData['humidity']?.toStringAsFixed(1) ?? 'N/A'}%',
                              Icons.water_drop,
                              Colors.blue,
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
                              Colors.amber,
                            ),
                          ),
                          Expanded(
                            child: _buildSensorValue(
                              'Motion',
                              sensorData['motion_detected'] == true ? 'Detected' : 'None',
                              Icons.motion_photos_on,
                              sensorData['motion_detected'] == true ? Colors.orange : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last Update: ${_formatDateTime(sensorData['recorded_at'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...rooms.map((room) => Card(
                child: ListTile(
                  leading: const Icon(Icons.room),
                  title: Text(room['name'] ?? 'Unknown Room'),
                  subtitle: Text('Floor ${room['floor']} • Capacity: ${room['capacity']}'),
                  trailing: Chip(
                    label: Text(room['type'] ?? 'Unknown'),
                    backgroundColor: Colors.blue[100],
                  ),
                ),
              )).toList(),
              const SizedBox(height: 24),
            ],

            // Equipment Section
            if (equipment.isNotEmpty) ...[
              const Text(
                'Equipment',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...equipment.map((item) {
                Color statusColor = item['status'] == 'online' ? Colors.green : Colors.red;
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.devices, color: statusColor),
                    title: Text(item['name'] ?? 'Unknown Equipment'),
                    subtitle: Text('Type: ${item['type']} • Device ID: ${item['device_id'] ?? 'N/A'}'),
                    trailing: Chip(
                      label: Text(item['status'] ?? 'Unknown'),
                      backgroundColor: statusColor.withOpacity(0.2),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ],

            // Empty state
            if (rooms.isEmpty && equipment.isEmpty && sensorLogs.isEmpty && latestSensorData.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No Data Available',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Add some rooms and equipment in Django admin to see them here.'),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ESP32 QR Scanner coming soon!')),
          );
        },
        tooltip: 'Scan ESP32 QR Code',
        child: const Icon(Icons.qr_code_scanner),
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorValue(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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