import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'ProfileScreen.dart';
import 'dart:convert';
import 'dart:async';
import 'LoginScreen.dart';
import '../Widgets/bottom_navbar.dart';

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

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'analytics':
      case 'notifications':
      case 'orb_chat':
      case 'about':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${value.replaceAll('_', ' ').toUpperCase()} feature coming soon!')),
        );
        break;
      case 'dashboard':
      default: // Do nothing - already on dashboard
        break;
    }
  }

  // void _logout() {
  //   _refreshTimer?.cancel();
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(builder: (context) => const LoginScreen()),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Dashboard'),
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
          icon: const Icon(Icons.person),
          tooltip: 'Profile',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  accessToken: widget.accessToken,
                  refreshToken: widget.refreshToken,
                ),
              ),
            );
          },
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
            if (isAutoRefresh)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isAutoRefresh)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.autorenew,
                              size: 16, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Auto-refresh ON (10s)',
                            style:
                                TextStyle(color: Colors.green[700], fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(), // Placeholder to maintain layout                  
                ],
              ),

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
      bottomNavigationBar: BottomNavBar(
        onMenuSelection: _handleMenuSelection,
        currentScreen: 'dashboard',
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