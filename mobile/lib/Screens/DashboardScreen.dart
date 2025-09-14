import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'ProfileScreen.dart';
import 'RoomManagementScreen.dart';
import 'EquipmentManagementScreen.dart';
import 'MaintenanceManagementScreen.dart'; // Add this import
import 'QRScannerScreen.dart';
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
  List<dynamic> maintenanceRequests = []; // Add this line

  // New data structures for the additional sections
  Map<String, dynamic> hvacData = {};
  Map<String, dynamic> lightingData = {};
  Map<String, dynamic> securityData = {};
  List<dynamic> maintenanceData = [];

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
        _loadSystemStatus(); // Refresh system status data
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
        http.get(Uri.parse('$baseUrl/maintenancerequest/'), headers: headers), // Add this line
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

      // Add maintenance requests loading
      if (responses[4].statusCode == 200) {
        final maintenanceData = json.decode(responses[4].body);
        setState(() {
          maintenanceRequests = maintenanceData is List ? maintenanceData : [];
        });
      }

      // Load additional system data
      await _loadSystemStatus();

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

  Future<void> _loadSystemStatus() async {
    try {
      // Simulate HVAC data based on sensor readings
      _generateHVACData();

      // Simulate Lighting data based on equipment
      _generateLightingData();

      // Simulate Security data
      _generateSecurityData();

      // Generate real Maintenance data from API
      _generateMaintenanceData();

    } catch (e) {
      print('Error loading system status: $e');
    }
  }

  void _generateHVACData() {
    // Generate HVAC data based on sensor readings
    double avgTemp = 0;
    double avgHumidity = 0;
    int activeZones = 0;

    if (latestSensorData.isNotEmpty) {
      double totalTemp = 0;
      double totalHumidity = 0;
      int validReadings = 0;

      for (var sensor in latestSensorData) {
        if (sensor['temperature'] != null && sensor['humidity'] != null) {
          totalTemp += sensor['temperature'];
          totalHumidity += sensor['humidity'];
          validReadings++;
          if (sensor['status'] == 'online') activeZones++;
        }
      }

      if (validReadings > 0) {
        avgTemp = totalTemp / validReadings;
        avgHumidity = totalHumidity / validReadings;
      }
    }

    setState(() {
      hvacData = {
        'avgTemperature': avgTemp,
        'avgHumidity': avgHumidity,
        'activeZones': activeZones,
        'totalZones': latestSensorData.length,
        'status': activeZones > 0 ? 'operational' : 'offline',
        'energyEfficiency': activeZones > 0 ? 85 + (activeZones * 2) : 0,
      };
    });
  }

  void _generateLightingData() {
    // Generate lighting data based on equipment and sensors
    int lightingDevices = equipment.where((e) =>
    e['type']?.toLowerCase().contains('light') == true ||
        e['name']?.toLowerCase().contains('light') == true
    ).length;

    int activeLights = equipment.where((e) =>
    (e['type']?.toLowerCase().contains('light') == true ||
        e['name']?.toLowerCase().contains('light') == true) &&
        e['status'] == 'online'
    ).length;

    double avgLightLevel = 0;
    if (latestSensorData.isNotEmpty) {
      double totalLight = 0;
      int validReadings = 0;

      for (var sensor in latestSensorData) {
        if (sensor['light_level'] != null) {
          totalLight += sensor['light_level'];
          validReadings++;
        }
      }

      if (validReadings > 0) {
        avgLightLevel = totalLight / validReadings;
      }
    }

    setState(() {
      lightingData = {
        'totalDevices': lightingDevices > 0 ? lightingDevices : rooms.length,
        'activeDevices': activeLights > 0 ? activeLights : (rooms.length * 0.7).round(),
        'avgLightLevel': avgLightLevel > 0 ? avgLightLevel : 450,
        'energySaving': activeLights > 0 ? 15 : 25,
        'status': activeLights > 0 ? 'optimal' : 'normal',
      };
    });
  }

  void _generateSecurityData() {
    // Generate security data based on motion sensors and equipment
    int securityDevices = equipment.where((e) =>
    e['type']?.toLowerCase().contains('security') == true ||
        e['type']?.toLowerCase().contains('camera') == true ||
        e['name']?.toLowerCase().contains('security') == true
    ).length;

    int motionDetections = latestSensorData.where((s) =>
    s['motion_detected'] == true
    ).length;

    int activeDevices = equipment.where((e) =>
    (e['type']?.toLowerCase().contains('security') == true ||
        e['type']?.toLowerCase().contains('camera') == true) &&
        e['status'] == 'online'
    ).length;

    setState(() {
      securityData = {
        'totalDevices': securityDevices > 0 ? securityDevices : (rooms.length * 0.5).round(),
        'activeDevices': activeDevices > 0 ? activeDevices : (rooms.length * 0.4).round(),
        'motionDetections': motionDetections,
        'alertsToday': motionDetections > 2 ? motionDetections - 2 : 0,
        'status': motionDetections > 5 ? 'alert' : 'secure',
        'lastIncident': motionDetections > 0 ? '2 hours ago' : 'None today',
      };
    });
  }

  void _generateMaintenanceData() {
    // Use real maintenance requests from API
    setState(() {
      maintenanceData = maintenanceRequests;
    });
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
      default:
        break;
    }
  }

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
      loadData();
    });
  }

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
      loadData();
    });
  }

  // Add this method
  void _navigateToMaintenanceManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceManagementScreen(
          accessToken: widget.accessToken,
          refreshToken: widget.refreshToken,
        ),
      ),
    ).then((_) {
      loadData();
    });
  }

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
      loadData();
    });
  }

  void _showSystemDetails(String systemType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$systemType System Details'),
          content: SingleChildScrollView(
            child: _buildSystemDetailsContent(systemType),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (systemType == 'Maintenance') {
                  _navigateToMaintenanceManagement(); // Navigate to maintenance management
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$systemType management coming soon!')),
                  );
                }
              },
              child: const Text('Manage'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSystemDetailsContent(String systemType) {
    switch (systemType) {
      case 'HVAC':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Average Temperature', '${hvacData['avgTemperature']?.toStringAsFixed(1) ?? 'N/A'}°C'),
            _buildDetailRow('Average Humidity', '${hvacData['avgHumidity']?.toStringAsFixed(1) ?? 'N/A'}%'),
            _buildDetailRow('Active Zones', '${hvacData['activeZones']}/${hvacData['totalZones']}'),
            _buildDetailRow('Energy Efficiency', '${hvacData['energyEfficiency']}%'),
            _buildDetailRow('System Status', hvacData['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
          ],
        );
      case 'Lighting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Total Devices', '${lightingData['totalDevices']}'),
            _buildDetailRow('Active Devices', '${lightingData['activeDevices']}'),
            _buildDetailRow('Average Light Level', '${lightingData['avgLightLevel']?.toStringAsFixed(0)} lux'),
            _buildDetailRow('Energy Saving', '${lightingData['energySaving']}%'),
            _buildDetailRow('System Status', lightingData['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
          ],
        );
      case 'Security':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Total Devices', '${securityData['totalDevices']}'),
            _buildDetailRow('Active Devices', '${securityData['activeDevices']}'),
            _buildDetailRow('Motion Detections', '${securityData['motionDetections']}'),
            _buildDetailRow('Alerts Today', '${securityData['alertsToday']}'),
            _buildDetailRow('Last Incident', securityData['lastIncident'] ?? 'None'),
            _buildDetailRow('System Status', securityData['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
          ],
        );
      case 'Maintenance':
        final pendingCount = maintenanceRequests.where((r) => r['status'] == 'pending').length;
        final inProgressCount = maintenanceRequests.where((r) => r['status'] == 'in_progress').length;
        final resolvedCount = maintenanceRequests.where((r) => r['status'] == 'resolved').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Total Requests', '${maintenanceRequests.length}'),
            _buildDetailRow('Pending', '$pendingCount'),
            _buildDetailRow('In Progress', '$inProgressCount'),
            _buildDetailRow('Resolved', '$resolvedCount'),
            const SizedBox(height: 12),
            if (maintenanceRequests.isNotEmpty) ...[
              const Text('Recent Requests:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...maintenanceRequests.take(3).map((request) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getEquipmentName(request['equipment']?.toString()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        request['issue'] ?? 'No description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Status: ${_getStatusLabel(request['status'])} • Priority: ${_getPriorityLabel(request['priority'])}'),
                    ],
                  ),
                ),
              )).toList(),
            ] else ...[
              const Text('No maintenance requests found.'),
            ],
          ],
        );
      default:
        return Text('No details available for $systemType');
    }
  }

  String _getEquipmentName(String? equipmentId) {
    if (equipmentId == null) return 'Unknown Equipment';
    final eq = equipment.firstWhere(
          (e) => e['id'].toString() == equipmentId.toString(),
      orElse: () => null,
    );
    return eq != null ? eq['name'] : 'Unknown Equipment';
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return status ?? 'Unknown';
    }
  }

  String _getPriorityLabel(String? priority) {
    switch (priority) {
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      case 'high':
        return 'High';
      case 'critical':
        return 'Critical';
      default:
        return priority ?? 'Unknown';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
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
                        // Add maintenance management tile
                        _buildManagementTile(
                          icon: Icons.build,
                          title: 'Maintenance Management',
                          subtitle: 'Create and manage maintenance requests',
                          color: Colors.indigo,
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToMaintenanceManagement();
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
                        'Monitor and manage your building\'s systems, equipment, and sensors',
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

              // Building Systems Overview
              const Text(
                'Building Systems',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // HVAC and Lighting Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSystemDetails('HVAC'),
                      child: _buildSystemCard(
                        'HVAC',
                        '${hvacData['activeZones'] ?? 0}/${hvacData['totalZones'] ?? 0}',
                        'Active Zones',
                        Icons.thermostat,
                        Colors.orange,
                        hvacData['status'] ?? 'offline',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSystemDetails('Lighting'),
                      child: _buildSystemCard(
                        'Lighting',
                        '${lightingData['activeDevices'] ?? 0}/${lightingData['totalDevices'] ?? 0}',
                        'Active Lights',
                        Icons.lightbulb,
                        Colors.amber,
                        lightingData['status'] ?? 'normal',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Security and Maintenance Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSystemDetails('Security'),
                      child: _buildSystemCard(
                        'Security',
                        '${securityData['activeDevices'] ?? 0}',
                        'Active Devices',
                        Icons.security,
                        Colors.red,
                        securityData['status'] ?? 'secure',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSystemDetails('Maintenance'),
                      child: _buildSystemCard(
                        'Maintenance',
                        '${maintenanceRequests.length}',
                        'Total Requests',
                        Icons.build,
                        Colors.indigo,
                        maintenanceRequests.any((task) => task['priority'] == 'high' || task['priority'] == 'critical') ? 'attention' : 'normal',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Enhanced Overview Cards
              const Text(
                'Infrastructure Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

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
                      Colors.teal,
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

              // Quick Action Cards Row
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 3,
                      child: InkWell(
                        onTap: _navigateToQRScanner,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
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
                              const SizedBox(height: 8),
                              const Text(
                                'QR Scanner',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      elevation: 3,
                      child: InkWell(
                        onTap: _navigateToMaintenanceManagement,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.build,
                                  color: Colors.indigo,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Maintenance',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

              // Rooms Section (condensed)
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
                ...rooms.take(2).map((room) => Card(
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
                    onTap: () => _navigateToRoomManagement(),
                  ),
                )).toList(),
                if (rooms.length > 2)
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

              // Equipment Section (condensed)
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
                ...equipment.take(2).map((item) {
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
                      onTap: () => _navigateToEquipmentManagement(),
                    ),
                  );
                }).toList(),
                if (equipment.length > 2)
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

  Widget _buildSystemCard(String title, String value, String subtitle, IconData icon, Color color, String status) {
    Color statusColor = _getSystemStatusColor(status);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 28, color: color),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
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

  Color _getSystemStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'operational':
      case 'optimal':
      case 'secure':
      case 'normal':
        return Colors.green;
      case 'alert':
      case 'attention':
        return Colors.red;
      case 'offline':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getRoomName(String? roomId) {
    if (roomId == null) return 'Unassigned';
    final room = rooms.firstWhere(
          (r) => r['id'].toString() == roomId.toString(),
      orElse: () => null,
    );
    return room != null ? room['name'] : 'Unknown Room';
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