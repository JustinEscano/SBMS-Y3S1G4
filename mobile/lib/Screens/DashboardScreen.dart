import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'ProfileScreen.dart';
import 'RoomManagementScreen.dart';
import 'EquipmentManagementScreen.dart';
import 'QRScannerScreen.dart'; // Add QR Scanner import
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
  String _errorMessage = '';
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
    _refreshTimer?.cancel();
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
      _errorMessage = '';
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
      ]).timeout(const Duration(seconds: 15));

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
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
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
      print('Error refreshing sensor data: $e');
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

  // Navigate to Room Management Screen
  void _navigateToRoomManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomManagementScreen(
          accessToken: widget.accessToken,
          refreshToken: widget.refreshToken,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from room management
      loadData();
    });
  }

  // Navigate to Equipment Management Screen
  void _navigateToEquipmentManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EquipmentManagementScreen(
          accessToken: widget.accessToken,
          refreshToken: widget.refreshToken,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from equipment management
      loadData();
    });
  }

  // Navigate to QR Scanner Screen
  void _navigateToQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          accessToken: widget.accessToken,
          refreshToken: widget.refreshToken,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from QR scanner
      loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final onlineEquipment = equipment.where((e) => e['status'] == 'online').length;
    final esp32Count = equipment.where((e) => e['type']?.toLowerCase() == 'esp32').length;
    final totalCapacity = rooms.fold<int>(0, (sum, room) => sum + (room['capacity'] as int? ?? 0));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Smart Building Dashboard'),
        actions: [
          // Management button with enhanced modal
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (BuildContext context) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Icon(Icons.settings, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            const Text(
                              'Management Center',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildManagementTile(
                          icon: Icons.room,
                          title: 'Room Management',
                          subtitle: 'Add, edit, and manage building rooms',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToRoomManagement();
                          },
                        ),
                        _buildManagementTile(
                          icon: Icons.devices,
                          title: 'Equipment Management',
                          subtitle: 'Add, edit, and manage equipment',
                          color: Colors.green,
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToEquipmentManagement();
                          },
                        ),
                        _buildManagementTile(
                          icon: Icons.qr_code_scanner,
                          title: 'QR Code Scanner',
                          subtitle: 'Scan equipment QR codes for quick access',
                          color: Colors.deepPurple,
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToQRScanner();
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  );
                },
              );
            },
            tooltip: 'Management Center',
          ),
          IconButton(
            icon: Icon(isAutoRefresh ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleAutoRefresh,
            tooltip: isAutoRefresh ? 'Pause Auto Refresh' : 'Start Auto Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
            tooltip: 'Refresh Data',
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
          : RefreshIndicator(
        onRefresh: loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error Message
              if (_errorMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // Welcome Section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dashboard, color: Colors.blue[700], size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Welcome to Smart Building',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Monitor and manage your building\'s rooms, equipment, and sensors',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

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

              // Enhanced Overview Cards
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _navigateToRoomManagement,
                      child: _buildOverviewCard(
                        'Rooms',
                        rooms.length.toString(),
                        Icons.room,
                        Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: _navigateToEquipmentManagement,
                      child: _buildOverviewCard(
                        'Equipment',
                        equipment.length.toString(),
                        Icons.devices,
                        Colors.green,
                      ),
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
                      esp32Count.toString(),
                      Icons.memory,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOverviewCard(
                      'Online',
                      onlineEquipment.toString(),
                      Icons.online_prediction,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quick Actions Section
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // QR Scanner Prominent Card
              Card(
                elevation: 3,
                child: InkWell(
                  onTap: _navigateToQRScanner,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.deepPurple,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QR Code Scanner',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Scan equipment QR codes for quick access',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Live Sensor Data Section
              if (latestSensorData.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.sensors, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Live ESP32 Sensor Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(sensorData['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.memory,
                                color: _getStatusColor(sensorData['status']),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sensorData['equipment_name'] ?? 'Unknown Device',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Device: ${sensorData['device_id'] ?? 'N/A'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(sensorData['status']).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                sensorData['status']?.toUpperCase() ?? 'UNKNOWN',
                                style: TextStyle(
                                  color: _getStatusColor(sensorData['status']),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                                'Light',
                                '${sensorData['light_level']?.toStringAsFixed(0) ?? 'N/A'} lux',
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
                Row(
                  children: [
                    const Text(
                      'Rooms',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _navigateToRoomManagement,
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...rooms.take(3).map((room) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        room['floor']?.toString() ?? '?',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(room['name'] ?? 'Unknown Room'),
                    subtitle: Text('Floor ${room['floor']} • Capacity: ${room['capacity']} • ${room['type'] ?? 'Unknown'}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Show room details in a dialog
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(room['name'] ?? 'Room Details'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Floor: ${room['floor']}'),
                                Text('Capacity: ${room['capacity']} people'),
                                Text('Type: ${room['type']}'),
                                const SizedBox(height: 16),
                                const Text('Equipment in this room:'),
                                const SizedBox(height: 8),
                                ...equipment
                                    .where((eq) => eq['room'] == room['id'])
                                    .map((eq) => Padding(
                                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                                  child: Text('• ${eq['name']}'),
                                ))
                                    .toList(),
                                if (equipment.where((eq) => eq['room'] == room['id']).isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 16),
                                    child: Text('No equipment assigned', style: TextStyle(color: Colors.grey)),
                                  ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _navigateToRoomManagement();
                                },
                                child: const Text('Manage Rooms'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                )).toList(),
                if (rooms.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: TextButton(
                        onPressed: _navigateToRoomManagement,
                        child: Text('View all ${rooms.length} rooms'),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],

              // Equipment Section
              if (equipment.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'Equipment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _navigateToEquipmentManagement,
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...equipment.take(3).map((item) {
                  Color statusColor = _getStatusColor(item['status']);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.2),
                        child: Icon(Icons.devices, color: statusColor),
                      ),
                      title: Text(item['name'] ?? 'Unknown Equipment'),
                      subtitle: Text('Type: ${item['type']} • Device ID: ${item['device_id'] ?? 'N/A'}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['status']?.toUpperCase() ?? 'UNKNOWN',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        // Show equipment details in a dialog
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(item['name'] ?? 'Equipment Details'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Type: ${item['type']}'),
                                  Text('Device ID: ${item['device_id'] ?? 'N/A'}'),
                                  Text('Status: ${item['status']}'),
                                  if (item['room'] != null)
                                    Text('Room: ${rooms.firstWhere((r) => r['id'] == item['room'], orElse: () => {'name': 'Unknown'})['name']}')
                                  else
                                    const Text('Room: Unassigned'),
                                  if (item['qr_code'] != null)
                                    Text('QR Code: ${item['qr_code']}'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _navigateToEquipmentManagement();
                                  },
                                  child: const Text('Manage Equipment'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  );
                }).toList(),
                if (equipment.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: TextButton(
                        onPressed: _navigateToEquipmentManagement,
                        child: Text('View all ${equipment.length} equipment'),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],

              // Empty State
              if (rooms.isEmpty && equipment.isEmpty && sensorLogs.isEmpty && latestSensorData.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Welcome to Smart Building!',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Get started by adding rooms and equipment to your building.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _navigateToRoomManagement,
                              icon: const Icon(Icons.room),
                              label: const Text('Add Rooms'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _navigateToEquipmentManagement,
                              icon: const Icon(Icons.devices),
                              label: const Text('Add Equipment'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToQRScanner,
        tooltip: 'QR Code Scanner',
        child: const Icon(Icons.qr_code_scanner),
      ),
      bottomNavigationBar: BottomNavBar(
        onMenuSelection: _handleMenuSelection,
        currentScreen: 'dashboard',
      ),
    );
  }

  Widget _buildManagementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
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

  Widget _buildSensorValue(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      case 'maintenance':
        return Colors.orange;
      case 'error':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
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