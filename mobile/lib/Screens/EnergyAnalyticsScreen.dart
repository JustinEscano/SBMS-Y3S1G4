import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../Config/api.dart';
import '../Screens/MaintenanceManagementScreen.dart';
import '../Widgets/bottom_navbar.dart';
import '../Services/auth_service.dart'; // Import AuthService

class EnergyAnalyticsScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const EnergyAnalyticsScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<EnergyAnalyticsScreen> createState() => _EnergyAnalyticsScreenState();
}

class _EnergyAnalyticsScreenState extends State<EnergyAnalyticsScreen> {
  List<dynamic> sensorLogs = [];
  List<dynamic> rooms = [];
  List<dynamic> equipment = [];
  List<dynamic> latestSensorData = [];
  String? selectedRoomId;
  String? selectedComponentId;
  String selectedScope = 'room';
  bool isLoading = true;
  bool isRefreshingToken = false;
  String errorMessage = '';
  String timeFrame = 'daily';
  Map<String, dynamic> summaryData = {};
  Map<String, dynamic> billingData = {};
  Map<String, dynamic> hvacData = {};
  Map<String, List<dynamic>> _cachedSensorLogs = {};
  Map<String, Map<String, dynamic>> _cachedBillingData = {};
  DateTime? _lastCacheTime;
  String totalCost = '0.00';
  String effectiveRate = '0.00';

  final Map<String, Duration> _periodDurations = {
    'daily': Duration(hours: 24),
    'weekly': Duration(days: 7),
    'monthly': Duration(days: 30),
  };

  final Map<String, Duration> _binSizes = {
    'daily': Duration(hours: 1),
    'weekly': Duration(days: 1),
    'monthly': Duration(days: 1),
  };

  @override
  void initState() {
    super.initState();
    // Initialize AuthService with tokens
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
    _loadRooms();
    _loadEquipment();
    loadEnergyData();
  }

  Future<void> _loadRooms() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.get(Uri.parse(ApiConfig.rooms), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          rooms = data is List ? data : [];
          selectedRoomId = rooms.isNotEmpty ? rooms.first['id'] : null;
        });
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _loadRooms();
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        throw Exception('Failed to load rooms: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading rooms: $e';
      });
    }
  }

  Future<void> _loadEquipment() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.get(Uri.parse(ApiConfig.equipment), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          equipment = data is List ? data : [];
          if (equipment.isNotEmpty && selectedRoomId != null) {
            final matchingEquipment = equipment.firstWhere(
                  (eq) => eq['room'] == selectedRoomId,
              orElse: () => {},
            );
            selectedComponentId = matchingEquipment.isNotEmpty ? matchingEquipment['component_id'] : null;
          } else {
            selectedComponentId = null;
          }
        });
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _loadEquipment();
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        throw Exception('Failed to load equipment: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading equipment: $e';
      });
    }
  }

  Future<bool> _refreshToken() async {
    setState(() {
      isRefreshingToken = true;
      errorMessage = 'Refreshing session...';
    });
    try {
      final success = await AuthService().refresh();
      if (success) {
        return true;
      }
      setState(() {
        errorMessage = 'Failed to refresh session. Please log in again.';
      });
      return false;
    } catch (e) {
      setState(() {
        errorMessage = 'Error refreshing session: $e';
      });
      return false;
    } finally {
      setState(() {
        isRefreshingToken = false;
      });
    }
  }

  DateTime _getStartTime(DateTime now) {
    switch (timeFrame) {
      case 'daily':
        return DateTime(now.year, now.month, now.day);
      case 'weekly':
        return now.subtract(Duration(days: 7)).copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
      case 'monthly':
        return now.subtract(Duration(days: 30)).copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
      default:
        return now.subtract(Duration(hours: 24)).copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
    }
  }

  DateTime _getEndTime(DateTime startTime) {
    switch (timeFrame) {
      case 'daily':
        return startTime.add(Duration(hours: 23, minutes: 59, seconds: 59));
      case 'weekly':
        return startTime.add(Duration(days: 7));
      case 'monthly':
        return startTime.add(Duration(days: 30));
      default:
        return startTime.add(Duration(hours: 23, minutes: 59, seconds: 59));
    }
  }

  Future<void> loadEnergyData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      _cachedSensorLogs.clear();
      _cachedBillingData.clear();
      totalCost = '0.00';
      effectiveRate = '0.00';
      hvacData = {};
    });

    final cacheKey = '$selectedScope-$selectedRoomId-$selectedComponentId-$timeFrame';

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      DateTime now = DateTime.now();
      DateTime startTimeCalc = _getStartTime(now);
      DateTime endTimeCalc = _getEndTime(startTimeCalc);

      String billingUrl = ApiConfig.calculateEnergyCost;
      List<String> params = [
        'period_type=$timeFrame',
        if (selectedRoomId != null) 'room_id=$selectedRoomId',
        if (selectedComponentId != null) 'component=$selectedComponentId',
        'period_start=${startTimeCalc.toIso8601String()}Z',
        'period_end=${endTimeCalc.toIso8601String()}Z',
      ];
      billingUrl += '?' + params.join('&');

      print('Billing Request URL: $billingUrl');
      var billingResponse = await http.get(Uri.parse(billingUrl), headers: headers).timeout(const Duration(seconds: 15));
      print('Billing Response Status: ${billingResponse.statusCode}');
      print('Billing Response Body: ${billingResponse.body}');

      String sensorLogUrl = ApiConfig.sensorLog;
      List<String> sensorParams = [
        'timeframe=$timeFrame',
        'period_start=${startTimeCalc.toIso8601String()}Z',
        'limit=10000',
        if (selectedRoomId != null) 'room_id=$selectedRoomId',
        if (selectedComponentId != null) 'component_id=$selectedComponentId',
      ];
      sensorLogUrl += '?' + sensorParams.join('&');

      final responses = await Future.wait([
        http.get(Uri.parse(sensorLogUrl), headers: headers),
        Future.value(billingResponse),
        http.get(Uri.parse(ApiConfig.latestSensorData), headers: headers),
      ]).timeout(const Duration(seconds: 15));

      if (responses[0].statusCode == 401 || responses[2].statusCode == 401) {
        if (await _refreshToken()) {
          return loadEnergyData();
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (responses[0].statusCode != 200) {
        throw Exception('Failed to load sensor data: ${responses[0].statusCode} - ${responses[0].reasonPhrase}');
      } else if (responses[2].statusCode != 200) {
        throw Exception('Failed to load latest sensor data: ${responses[2].statusCode} - ${responses[2].reasonPhrase}');
      }

      final sensorData = json.decode(responses[0].body);
      print('Sensor Log Response: $sensorData');
      final latestData = json.decode(responses[2].body);
      print('Latest Sensor Data Response: $latestData');

      setState(() {
        sensorLogs = sensorData is List ? sensorData : [];
        _cachedSensorLogs[cacheKey] = sensorLogs;
        latestSensorData = latestData['success'] == true ? (latestData['data'] ?? []) : [];
      });

      if (responses[1].statusCode == 401) {
        if (await _refreshToken()) {
          return loadEnergyData();
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (responses[1].statusCode != 200) {
        throw Exception('Failed to load billing data: ${responses[1].statusCode} - ${responses[1].reasonPhrase}');
      }

      final billing = json.decode(responses[1].body);
      print('Raw Billing Data: $billing');
      Map<String, dynamic> parsedBillingData = {
        'total_cost': 0.0,
        'effective_rate': 0.0,
        'currency': 'PHP',
        'details': [],
      };
      if (billing is Map<String, dynamic> && billing.containsKey('data')) {
        final data = billing['data'] as Map<String, dynamic>;
        parsedBillingData = {
          'total_cost': (data['total_cost'] as num?)?.toDouble() ?? 0.0,
          'effective_rate': (data['effective_rate'] as num?)?.toDouble() ?? 0.0,
          'currency': data['currency'] ?? 'PHP',
          'details': data['details'] ?? [],
        };
      }
      print('Parsed Billing Data: $parsedBillingData');

      setState(() {
        billingData = parsedBillingData;
        _cachedBillingData[cacheKey] = billingData;
        _lastCacheTime = DateTime.now();
        totalCost = parsedBillingData['total_cost'].toStringAsFixed(2);
        effectiveRate = parsedBillingData['effective_rate'].toStringAsFixed(2);
      });

      _generateHVACData();
      await _loadSummaryData(startTimeCalc);
    } catch (e) {
      setState(() {
        errorMessage = e.toString().contains('Session expired') ? e.toString() : 'Error loading data: $e';
        totalCost = '0.00';
        effectiveRate = '0.00';
        hvacData = {
          'avgTemperature': 0.0,
          'avgHumidity': 0.0,
          'activeZones': 0,
          'totalZones': 0,
          'status': 'offline',
        };
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _generateHVACData() {
    double avgTemp = 0.0;
    double avgHumidity = 0.0;
    int activeZones = 0;
    int totalZones = 0;

    if (latestSensorData.isNotEmpty) {
      final filteredSensors = latestSensorData.where((sensor) {
        if (sensor['temperature'] == null || sensor['humidity'] == null) return false;
        if (selectedScope == 'building') return true;
        if (selectedScope == 'all_rooms' && sensor['room_id'] != null) return true;
        if (selectedScope == 'room' && sensor['room_id'] == selectedRoomId) {
          if (selectedComponentId == null || sensor['device_id'] == selectedComponentId) {
            return true;
          }
        }
        return false;
      }).toList();

      double totalTemp = 0.0;
      double totalHumidity = 0.0;
      int validReadings = 0;

      for (var sensor in filteredSensors) {
        totalTemp += (sensor['temperature'] as num).toDouble();
        totalHumidity += (sensor['humidity'] as num).toDouble();
        validReadings++;
        if (sensor['status'] == 'online') activeZones++;
      }

      totalZones = filteredSensors.length;

      if (validReadings > 0) {
        avgTemp = totalTemp / validReadings;
        avgHumidity = totalHumidity / validReadings;
      }
    }

    setState(() {
      hvacData = {
        'avgTemperature': avgTemp.isNaN ? 0.0 : avgTemp,
        'avgHumidity': avgHumidity.isNaN ? 0.0 : avgHumidity,
        'activeZones': activeZones,
        'totalZones': totalZones,
        'status': activeZones > 0 ? 'operational' : 'offline',
      };
    });
  }

  Future<void> _loadSummaryData(DateTime startTimeCalc) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      String summaryUrl = ApiConfig.energySummary(periodType: timeFrame, roomId: selectedScope == 'room' ? selectedRoomId : null);
      summaryUrl += '&start_time=${startTimeCalc.toIso8601String()}Z';
      final response = await http.get(
        Uri.parse(summaryUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _loadSummaryData(startTimeCalc);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (response.statusCode != 200) {
        throw Exception('Failed to load summary data: ${response.statusCode} - ${response.reasonPhrase}');
      }
      final summary = json.decode(response.body);
      print('Summary Response: $summary');
      if (summary is List && summary.isNotEmpty) {
        setState(() {
          summaryData = Map<String, dynamic>.from(summary[0]);
        });
      } else {
        setState(() {
          summaryData = {
            'total_energy': 0.0,
            'avg_power': 0.0,
            'peak_power': 0.0,
            'reading_count': 0,
            'anomaly_count': 0,
          };
          errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().contains('Session expired') ? e.toString() : 'Error loading summary data: $e';
      });
    }
  }

  List<FlSpot> _generatePowerSpots() {
    final now = DateTime.now();
    final periodDuration = _periodDurations[timeFrame]!;
    final startTime = _getStartTime(now);
    final binSize = _binSizes[timeFrame]!;
    final binSizeMs = binSize.inMilliseconds;
    final startMs = startTime.millisecondsSinceEpoch;
    final endMs = now.millisecondsSinceEpoch;

    final filteredLogs = sensorLogs.where((log) {
      if (log['recorded_at'] == null) return false;
      try {
        final recordedAt = DateTime.parse(log['recorded_at']);
        return !recordedAt.isBefore(startTime) && !recordedAt.isAfter(now);
      } catch (e) {
        return false;
      }
    }).toList();

    final totalBins = ((endMs - startMs) / binSizeMs).ceil();
    final Map<int, List<double>> bins = {};
    for (int i = 0; i < totalBins; i++) {
      final binKey = startMs + (i * binSizeMs);
      bins[binKey] = [];
    }

    for (var log in filteredLogs) {
      try {
        final recordedAt = DateTime.parse(log['recorded_at']);
        final timestampMs = recordedAt.millisecondsSinceEpoch;
        final relativeMs = timestampMs - startMs;
        final binIndex = (relativeMs / binSizeMs).floor();
        final binKey = startMs + (binIndex * binSizeMs);
        if (bins.containsKey(binKey)) {
          final power = (log['power'] as num?)?.toDouble() ?? 0.0;
          bins[binKey]!.add(power);
        }
      } catch (e) {
        // Skip invalid entries
      }
    }

    final List<FlSpot> spots = [];
    bins.forEach((binKey, values) {
      final avgPower = values.isNotEmpty ? values.reduce((a, b) => a + b) / values.length : 0.0;
      final binMidMs = binKey + (binSizeMs / 2);
      final xValue = (binMidMs - startMs) / (1000 * 60 * 60).toDouble();
      spots.add(FlSpot(xValue, avgPower));
    });

    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  List<FlSpot> _generateEnergySpots() {
    final now = DateTime.now();
    final periodDuration = _periodDurations[timeFrame]!;
    final startTime = _getStartTime(now);
    final binSize = _binSizes[timeFrame]!;
    final binSizeMs = binSize.inMilliseconds;
    final startMs = startTime.millisecondsSinceEpoch;
    final endMs = now.millisecondsSinceEpoch;

    final filteredLogs = sensorLogs.where((log) {
      if (log['recorded_at'] == null) return false;
      try {
        final recordedAt = DateTime.parse(log['recorded_at']);
        return !recordedAt.isBefore(startTime) && !recordedAt.isAfter(now);
      } catch (e) {
        return false;
      }
    }).toList();

    final totalBins = ((endMs - startMs) / binSizeMs).ceil();
    final Map<int, List<double>> bins = {};
    for (int i = 0; i < totalBins; i++) {
      final binKey = startMs + (i * binSizeMs);
      bins[binKey] = [];
    }

    for (var log in filteredLogs) {
      try {
        final recordedAt = DateTime.parse(log['recorded_at']);
        final timestampMs = recordedAt.millisecondsSinceEpoch;
        final relativeMs = timestampMs - startMs;
        final binIndex = (relativeMs / binSizeMs).floor();
        final binKey = startMs + (binIndex * binSizeMs);
        if (bins.containsKey(binKey)) {
          final energy = (log['energy'] as num?)?.toDouble() ?? 0.0;
          bins[binKey]!.add(energy);
        }
      } catch (e) {
        // Skip invalid entries
      }
    }

    final List<FlSpot> spots = [];
    bins.forEach((binKey, values) {
      final lastEnergy = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 0.0;
      final binMidMs = binKey + (binSizeMs / 2);
      final xValue = (binMidMs - startMs) / (1000 * 60 * 60).toDouble();
      spots.add(FlSpot(xValue, lastEnergy));
    });

    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  void _changeTimeFrame(String newTimeFrame) {
    if (timeFrame != newTimeFrame) {
      setState(() {
        timeFrame = newTimeFrame;
      });
      loadEnergyData();
    }
  }

  void _changeScope(String newScope, {String? newRoomId, String? newComponentId}) {
    setState(() {
      selectedScope = newScope;
      selectedRoomId = newScope == 'room' ? (newRoomId ?? selectedRoomId) : null;
      selectedComponentId = newScope == 'room' ? (newComponentId ?? selectedComponentId) : null;
    });
    loadEnergyData();
  }

  String _formatTimeAxis(double value, String timeFrame, DateTime startTime) {
    final minutesSinceStart = (value * 60).round();
    final time = startTime.add(Duration(minutes: minutesSinceStart));
    if (timeFrame == 'daily') {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  double _getMaxY(List<FlSpot> spots, {bool isEnergy = false}) {
    if (spots.isEmpty) return isEnergy ? 0.01 : 100.0;
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    return isEnergy ? (maxY < 0.01 ? 0.01 : (maxY * 1.2)) : (maxY * 1.2).ceilToDouble();
  }

  double? _getInterval(String timeFrame) {
    switch (timeFrame) {
      case 'daily':
        return 4.0;
      case 'weekly':
        return 24.0;
      case 'monthly':
        return 24.0 * 7;
      default:
        return null;
    }
  }

  bool _shouldShowLabel(double value, String timeFrame) {
    switch (timeFrame) {
      case 'daily':
        return value % 4 == 0;
      case 'weekly':
        return value % 24 == 0;
      case 'monthly':
        return value % (24 * 7) == 0;
      default:
        return true;
    }
  }

  String _getScopeTitle() {
    if (selectedScope == 'building') {
      return 'Building-Wide';
    } else if (selectedScope == 'all_rooms') {
      return 'All Rooms';
    } else {
      final selectedRoom = rooms.firstWhere(
            (room) => room['id'] == selectedRoomId,
        orElse: () => {'name': 'Selected Room'},
      );
      if (selectedComponentId == null) {
        return selectedRoom['name'];
      }
      final selectedEquipment = equipment.firstWhere(
            (eq) => eq['component_id'] == selectedComponentId,
        orElse: () => {'name': 'Selected Equipment'},
      );
      return '${selectedRoom['name']} - ${selectedEquipment['name']}';
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  Future<void> _navigateToMaintenanceManagement() async {
    String userRole = 'Client';
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.get(Uri.parse(ApiConfig.userInfo), headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        userRole = userData['role']?.toString() ?? 'Client';
        if (!['Client', 'Employee', 'Admin', 'Superadmin'].contains(userRole)) {
          userRole = 'Client';
        }
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _navigateToMaintenanceManagement(); // Retry with new token
        }
      }
    } catch (e) {
      print('Error fetching user role: $e');
      setState(() {
        errorMessage = 'Error fetching user role: $e';
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceManagementScreen(
          accessToken: AuthService().accessToken ?? widget.accessToken,
          refreshToken: AuthService().refreshToken ?? widget.refreshToken,
          userRole: userRole,
        ),
      ),
    ).then((_) {
      loadEnergyData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startTime = _getStartTime(now);
    final powerSpots = _generatePowerSpots();
    final energySpots = _generateEnergySpots();
    String chartSuffix = '';
    if (timeFrame == 'daily') {
      chartSuffix = ' (Last 24 Hours)';
    } else if (timeFrame == 'weekly') {
      chartSuffix = ' (Last 7 Days)';
    } else if (timeFrame == 'monthly') {
      chartSuffix = ' (Last 30 Days)';
    }

    final double maxX = now.difference(startTime).inMinutes / 60.0;
    final interval = _getInterval(timeFrame);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Energy Analytics - ${_getScopeTitle()}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isRefreshingToken ? null : loadEnergyData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: isLoading || isRefreshingToken
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: loadEnergyData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (errorMessage.isNotEmpty)
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
                      Expanded(child: Text(errorMessage, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: Colors.teal[700], size: 28),
                          const SizedBox(width: 12),
                          Text(
                            '${_getScopeTitle()} Energy Overview',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Analyze energy consumption and cost trends over $timeFrame intervals',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Text('Daily'),
                    selected: timeFrame == 'daily',
                    onSelected: (selected) => _changeTimeFrame('daily'),
                    selectedColor: Colors.teal[100],
                    backgroundColor: Colors.grey[200],
                  ),
                  ChoiceChip(
                    label: const Text('Weekly'),
                    selected: timeFrame == 'weekly',
                    onSelected: (selected) => _changeTimeFrame('weekly'),
                    selectedColor: Colors.teal[100],
                    backgroundColor: Colors.grey[200],
                  ),
                  ChoiceChip(
                    label: const Text('Monthly'),
                    selected: timeFrame == 'monthly',
                    onSelected: (selected) => _changeTimeFrame('monthly'),
                    selectedColor: Colors.teal[100],
                    backgroundColor: Colors.grey[200],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Text('Building'),
                    selected: selectedScope == 'building',
                    onSelected: (selected) => _changeScope('building'),
                    selectedColor: Colors.teal[100],
                    backgroundColor: Colors.grey[200],
                  ),
                  ChoiceChip(
                    label: const Text('All Rooms'),
                    selected: selectedScope == 'all_rooms',
                    onSelected: (selected) => _changeScope('all_rooms'),
                    selectedColor: Colors.teal[100],
                    backgroundColor: Colors.grey[200],
                  ),
                  ChoiceChip(
                    label: const Text('Room'),
                    selected: selectedScope == 'room',
                    onSelected: (selected) => _changeScope('room'),
                    selectedColor: Colors.teal[100],
                    backgroundColor: Colors.grey[200],
                  ),
                ],
              ),
              if (selectedScope == 'room') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Room',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedRoomId,
                  items: rooms.map<DropdownMenuItem<String>>((room) {
                    return DropdownMenuItem<String>(
                      value: room['id'],
                      child: Text(room['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedRoomId = value;
                        final matchingEquipment = equipment.firstWhere(
                              (eq) => eq['room'] == value,
                          orElse: () => {},
                        );
                        selectedComponentId = matchingEquipment.isNotEmpty ? matchingEquipment['component_id'] : null;
                      });
                      loadEnergyData();
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Equipment',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedComponentId,
                  items: equipment
                      .where((eq) => eq['room'] == selectedRoomId)
                      .map<DropdownMenuItem<String>>((eq) {
                    return DropdownMenuItem<String>(
                      value: eq['component_id'],
                      child: Text(eq['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _changeScope('room', newComponentId: value);
                    }
                  },
                  hint: const Text('All Equipment in Room'),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getScopeTitle()} Power Consumption Trend$chartSuffix',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toStringAsFixed(1)} W',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: interval,
                                  getTitlesWidget: (value, meta) {
                                    if (!_shouldShowLabel(value, timeFrame)) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _formatTimeAxis(value, timeFrame, startTime),
                                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: powerSpots,
                                isCurved: true,
                                color: Colors.teal,
                                barWidth: 2,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.teal.withOpacity(0.2),
                                ),
                                dotData: FlDotData(show: true),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              enabled: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    return LineTooltipItem(
                                      '${spot.y.toStringAsFixed(2)} W\n${_formatTimeAxis(spot.x, timeFrame, startTime)}',
                                      const TextStyle(color: Colors.white),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            minX: 0,
                            maxX: maxX,
                            minY: 0,
                            maxY: _getMaxY(powerSpots),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getScopeTitle()} Energy Consumption Trend$chartSuffix',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toStringAsFixed(3)} kWh',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: interval,
                                  getTitlesWidget: (value, meta) {
                                    if (!_shouldShowLabel(value, timeFrame)) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _formatTimeAxis(value, timeFrame, startTime),
                                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: energySpots,
                                isCurved: true,
                                color: Colors.green,
                                barWidth: 2,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.green.withOpacity(0.2),
                                ),
                                dotData: FlDotData(show: true),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              enabled: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    return LineTooltipItem(
                                      '${spot.y.toStringAsFixed(3)} kWh\n${_formatTimeAxis(spot.x, timeFrame, startTime)}',
                                      const TextStyle(color: Colors.white),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            minX: 0,
                            maxX: maxX,
                            minY: 0,
                            maxY: _getMaxY(energySpots, isEnergy: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getScopeTitle()} Energy and Cost Statistics',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow('Total Energy', '${summaryData['total_energy']?.toStringAsFixed(3) ?? '0.000'} kWh'),
                      _buildStatRow('Average Power', '${summaryData['avg_power']?.toStringAsFixed(1) ?? '0.0'} W'),
                      _buildStatRow('Peak Power', '${summaryData['peak_power']?.toStringAsFixed(1) ?? '0.0'} W'),
                      _buildStatRow('Reading Count', '${summaryData['reading_count'] ?? '0'}'),
                      _buildStatRow('Anomaly Count', '${summaryData['anomaly_count'] ?? '0'}'),
                      const Divider(),
                      _buildStatRow('Total Cost', '$totalCost ${billingData['currency'] ?? 'PHP'}'),
                      _buildStatRow('Effective Rate', '$effectiveRate ${billingData['currency'] ?? 'PHP'}/kWh'),
                      if (billingData['details']?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Cost Breakdown by Component',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ...billingData['details'].map<Widget>((detail) {
                          return _buildStatRow(
                            detail['component_type'] ?? 'Unknown Component',
                            '${detail['cost']?.toStringAsFixed(2) ?? '0.00'} ${detail['currency'] ?? 'PHP'} (${detail['total_energy']?.toStringAsFixed(3) ?? '0.000'} kWh)',
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getScopeTitle()} HVAC Status',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow('Average Temperature', '${hvacData['avgTemperature']?.toStringAsFixed(1) ?? '0.0'}°C'),
                      _buildStatRow('Average Humidity', '${hvacData['avgHumidity']?.toStringAsFixed(1) ?? '0.0'}%'),
                      _buildStatRow('Active Zones', '${hvacData['activeZones'] ?? 0}/${hvacData['totalZones'] ?? 0}'),
                      _buildStatRow('System Status', hvacData['status']?.toString().toUpperCase() ?? 'OFFLINE'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        onMenuSelection: (value) {
          switch (value) {
            case 'dashboard':
              Navigator.pop(context);
              break;
            case 'maintenance_requests':
              _navigateToMaintenanceManagement();
              break;
            case 'orb_chat':
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'accessToken': AuthService().accessToken ?? widget.accessToken,
                  'refreshToken': AuthService().refreshToken ?? widget.refreshToken,
                },
              );
              break;
            case 'notifications':
            case 'about':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${value.replaceAll('_', ' ').toUpperCase()} feature coming soon!')),
              );
              break;
            default:
              break;
          }
        },
        currentScreen: 'analytics',
      ),
    );
  }
}