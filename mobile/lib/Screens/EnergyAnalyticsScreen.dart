import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../Config/api.dart';
import '../Screens/MaintenanceManagementScreen.dart';
import '../Screens/NotificationsScreen.dart';
import '../Widgets/bottom_navbar.dart';
import '../Widgets/AnalyticsWidgets.dart';
import '../Services/auth_service.dart';
import '../providers/dashboard_provider.dart';
import '../utils/safe_navigation.dart';
import 'DashboardScreen.dart';
import 'ChatScreen.dart';
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
  List<dynamic> hvacSensorData = [];
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
  Map<String, dynamic> securityData = {};
  Map<String, List<dynamic>> _cachedSensorLogs = {};
  Map<String, Map<String, dynamic>> _cachedBillingData = {};
  Map<String, List<dynamic>> _cachedHvacData = {};
  DateTime? _lastCacheTime;
  String totalCost = '0.00';
  String effectiveRate = '0.00';
  bool hasUnreadNotifications = false;
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
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
    _loadRooms();
    _loadEquipment();
    loadEnergyData();
    // Initialize notifications via DashboardProvider
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    provider.loadData(context: context);
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
        return now.copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
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
  Future<void> _loadHvacSensorData(DateTime startTime, DateTime endTime) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      String hvacSensorUrl = ApiConfig.sensorLog;
      List<String> hvacParams = [
        'timeframe=$timeFrame',
        'period_start=${startTime.toIso8601String()}Z',
        'period_end=${endTime.toIso8601String()}Z',
        'limit=10000',
        'component_type=dht22',
        if (selectedRoomId != null) 'room_id=$selectedRoomId',
        if (selectedComponentId != null) 'component_id=$selectedComponentId',
      ];
      hvacSensorUrl += '?' + hvacParams.join('&');
      print('HVAC Sensor Request URL: $hvacSensorUrl');
      final hvacResponse = await http.get(Uri.parse(hvacSensorUrl), headers: headers).timeout(const Duration(seconds: 15));
      print('HVAC Sensor Response Status: ${hvacResponse.statusCode}');
      print('HVAC Sensor Response Body: ${hvacResponse.body}');
      if (hvacResponse.statusCode == 401) {
        if (await _refreshToken()) {
          return _loadHvacSensorData(startTime, endTime);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (hvacResponse.statusCode != 200) {
        throw Exception('Failed to load HVAC sensor data: ${hvacResponse.statusCode} - ${hvacResponse.reasonPhrase}');
      }
      final hvacData = json.decode(hvacResponse.body);
      print('HVAC Sensor Data Response: $hvacData');
      setState(() {
        hvacSensorData = hvacData is List ? hvacData : [];
        _cachedHvacData['$selectedScope-$selectedRoomId-$selectedComponentId-$timeFrame'] = hvacSensorData;
      });
    } catch (e) {
      print('Error loading HVAC sensor data: $e');
      setState(() {
        hvacSensorData = [];
      });
    }
  }
  Future<void> loadEnergyData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      _cachedSensorLogs.clear();
      _cachedBillingData.clear();
      _cachedHvacData.clear();
      totalCost = '0.00';
      effectiveRate = '0.00';
      hvacData = {};
      securityData = {};
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
      print('=== DATE RANGE DEBUG ===');
      print('Current time: $now');
      print('Start time: $startTimeCalc');
      print('End time: $endTimeCalc');
      print('Timeframe: $timeFrame');
      print('========================');
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
      await Future.wait([
        http.get(Uri.parse(sensorLogUrl), headers: headers),
        Future.value(billingResponse),
        http.get(Uri.parse(ApiConfig.latestSensorData), headers: headers),
        _loadHvacSensorData(startTimeCalc, endTimeCalc),
      ]).timeout(const Duration(seconds: 15));
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
      Map<String, dynamic> parsedBillingData = {
        'total_cost': 0.0,
        'effective_rate': 0.0,
        'currency': 'PHP',
        'details': [],
      };
      if (responses[1].statusCode == 401) {
        if (await _refreshToken()) {
          return loadEnergyData();
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (responses[1].statusCode == 404) {
        // Handle 404 (Billing period not found) gracefully
        print('Billing period not found (404). Setting default billing data.');
        setState(() {
          billingData = parsedBillingData;
          _cachedBillingData[cacheKey] = billingData;
          _lastCacheTime = DateTime.now();
          totalCost = '0.00';
          effectiveRate = '0.00';
        });
      } else if (responses[1].statusCode != 200) {
        throw Exception('Failed to load billing data: ${responses[1].statusCode} - ${responses[1].reasonPhrase}');
      } else {
        final billing = json.decode(responses[1].body);
        print('Raw Billing Data: $billing');
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
      }
      _generateHVACData();
      _generateSecurityData();
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
        securityData = {
          'activeDevices': 0,
          'totalDevices': 0,
          'alertCount': 0,
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
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    // Historical averages from hvacSensorData
    double totalTemp = 0.0;
    double totalHumidity = 0.0;
    int validReadings = 0;
    for (var sensor in hvacSensorData) {
      if (sensor['temperature'] != null && sensor['humidity'] != null) {
        totalTemp += (sensor['temperature'] as num).toDouble();
        totalHumidity += (sensor['humidity'] as num).toDouble();
        validReadings++;
      }
    }
    double avgTemp = validReadings > 0 ? totalTemp / validReadings : 0.0;
    double avgHumidity = validReadings > 0 ? totalHumidity / validReadings : 0.0;
    // Active zones from latest data, filtered by room
    Map<String, dynamic> eqToRoom = {};
    for (var eq in provider.equipment) {
      eqToRoom[eq['id'].toString()] = eq['room'];
    }
    final filteredLatest = provider.latestSensorData.where((s) {
      return s['temperature'] != null &&
          s['humidity'] != null &&
          (selectedRoomId == null || eqToRoom[s['equipment'].toString()] == selectedRoomId);
    }).toList();
    Set<String> uniqueEq = filteredLatest.map((s) => s['equipment'].toString()).toSet();
    int totalZones = uniqueEq.length;
    int activeZones = filteredLatest.where((s) {
      final recStr = s['recorded_at'] ?? '';
      final rec = DateTime.tryParse(recStr);
      return rec != null && DateTime.now().difference(rec).inSeconds <= 30;
    }).length;
    String status = activeZones > 0 ? 'operational' : 'offline';
    setState(() {
      hvacData = {
        'avgTemperature': avgTemp.isNaN ? 0.0 : avgTemp,
        'avgHumidity': avgHumidity.isNaN ? 0.0 : avgHumidity,
        'activeZones': activeZones,
        'totalZones': totalZones,
        'status': status,
        'dataPoints': hvacSensorData.length,
      };
    });
  }
  void _generateSecurityData() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final now = DateTime.now();
    final startTime = _getStartTime(now);
    final endTime = _getEndTime(startTime);
    final todayStart = DateTime(now.year, now.month, now.day);
    // Map equipment to room
    Map<String, dynamic> eqToRoom = {};
    for (var eq in provider.equipment) {
      eqToRoom[eq['id'].toString()] = eq['room'];
    }
    // Filter motion alerts by time and room
    final motionAlerts = provider.alerts.where((a) {
      if (a['type'] != 'motion') return false;
      final triggeredStr = a['triggered_at'] ?? a['created_at'];
      final triggered = DateTime.tryParse(triggeredStr ?? '');
      if (triggered == null || triggered.isBefore(startTime) || triggered.isAfter(endTime)) return false;
      if (selectedRoomId == null) return true;
      final eqId = a['equipment'].toString();
      return eqToRoom[eqId] == selectedRoomId;
    }).toList();
    int motionDetections = motionAlerts.length;
    int alertsToday = motionAlerts.where((a) {
      final triggeredStr = a['triggered_at'] ?? a['created_at'];
      final triggered = DateTime.tryParse(triggeredStr ?? '');
      return triggered != null && triggered.isAfter(todayStart);
    }).length;
    bool hasUnresolved = motionAlerts.any((a) => !(a['resolved'] as bool? ?? true));
    String status = hasUnresolved ? 'alert' : 'secure';
    String lastIncident = 'None today';
    if (motionAlerts.isNotEmpty) {
      motionAlerts.sort((a, b) {
        final timeA = DateTime.parse(a['triggered_at'] ?? a['created_at']);
        final timeB = DateTime.parse(b['triggered_at'] ?? b['created_at']);
        return timeB.compareTo(timeA);
      });
      final last = motionAlerts.first;
      final lastTime = DateTime.parse(last['triggered_at'] ?? last['created_at']);
      final diff = now.difference(lastTime);
      if (diff.inHours > 0) {
        lastIncident = '${diff.inHours} hours ago';
      } else if (diff.inMinutes > 0) {
        lastIncident = '${diff.inMinutes} minutes ago';
      } else {
        lastIncident = 'Just now';
      }
    }
    // Security devices from equipment
    int securityDevices = provider.equipment.where((e) {
      String? type = e['type'] as String?;
      String? name = e['name'] as String?;
      bool isSecurity = (type?.toLowerCase().contains('security') ?? false) ||
          (type?.toLowerCase().contains('camera') ?? false) ||
          (name?.toLowerCase().contains('security') ?? false);
      if (selectedRoomId != null) {
        return isSecurity && e['room'] == selectedRoomId;
      }
      return isSecurity;
    }).length;
    int activeDevices = provider.equipment.where((e) {
      String? type = e['type'] as String?;
      String? name = e['name'] as String?;
      bool isSecurity = (type?.toLowerCase().contains('security') ?? false) ||
          (type?.toLowerCase().contains('camera') ?? false) ||
          (name?.toLowerCase().contains('security') ?? false);
      if (selectedRoomId != null) {
        return isSecurity && e['room'] == selectedRoomId && e['status'] == 'online';
      }
      return isSecurity && e['status'] == 'online';
    }).length;
    setState(() {
      securityData = {
        'activeDevices': activeDevices,
        'totalDevices': securityDevices,
        'alertCount': motionDetections,
        'status': status,
        'alertsToday': alertsToday,
        'lastIncident': lastIncident,
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
  List<FlSpot> _generateTemperatureSpots() {
    final now = DateTime.now();
    final startTime = _getStartTime(now);
    final binSize = _binSizes[timeFrame]!;
    final binSizeMs = binSize.inMilliseconds;
    final startMs = startTime.millisecondsSinceEpoch;
    final endMs = now.millisecondsSinceEpoch;
    final filteredLogs = hvacSensorData.where((log) {
      if (log['recorded_at'] == null || log['temperature'] == null) return false;
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
          final temperature = (log['temperature'] as num?)?.toDouble() ?? 0.0;
          bins[binKey]!.add(temperature);
        }
      } catch (e) {
        // Skip invalid entries
      }
    }
    final List<FlSpot> spots = [];
    bins.forEach((binKey, values) {
      final avgTemp = values.isNotEmpty ? values.reduce((a, b) => a + b) / values.length : 0.0;
      final binMidMs = binKey + (binSizeMs / 2);
      final xValue = (binMidMs - startMs) / (1000 * 60 * 60).toDouble();
      spots.add(FlSpot(xValue, avgTemp));
    });
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }
  List<FlSpot> _generateHumiditySpots() {
    final now = DateTime.now();
    final startTime = _getStartTime(now);
    final binSize = _binSizes[timeFrame]!;
    final binSizeMs = binSize.inMilliseconds;
    final startMs = startTime.millisecondsSinceEpoch;
    final endMs = now.millisecondsSinceEpoch;
    final filteredLogs = hvacSensorData.where((log) {
      if (log['recorded_at'] == null || log['humidity'] == null) return false;
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
          final humidity = (log['humidity'] as num?)?.toDouble() ?? 0.0;
          bins[binKey]!.add(humidity);
        }
      } catch (e) {
        // Skip invalid entries
      }
    }
    final List<FlSpot> spots = [];
    bins.forEach((binKey, values) {
      final avgHumidity = values.isNotEmpty ? values.reduce((a, b) => a + b) / values.length : 0.0;
      final binMidMs = binKey + (binSizeMs / 2);
      final xValue = (binMidMs - startMs) / (1000 * 60 * 60).toDouble();
      spots.add(FlSpot(xValue, avgHumidity));
    });
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }
  List<FlSpot> _generateSecurityAlertSpots() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final now = DateTime.now();
    final startTime = _getStartTime(now);
    final binSize = _binSizes[timeFrame]!;
    final binSizeMs = binSize.inMilliseconds;
    final startMs = startTime.millisecondsSinceEpoch;
    final endMs = now.millisecondsSinceEpoch;
    Map<String, dynamic> eqToRoom = {};
    for (var eq in provider.equipment) {
      eqToRoom[eq['id'].toString()] = eq['room'];
    }
    final filteredAlerts = provider.alerts.where((a) {
      if (a['type'] != 'motion') return false;
      final triggeredStr = a['triggered_at'] ?? a['created_at'];
      final triggered = DateTime.tryParse(triggeredStr ?? '');
      if (triggered == null || triggered.isBefore(startTime) || triggered.isAfter(now)) return false;
      if (selectedRoomId == null) return true;
      final eqId = a['equipment'].toString();
      return eqToRoom[eqId] == selectedRoomId;
    }).toList();
    final totalBins = ((endMs - startMs) / binSizeMs).ceil();
    final Map<int, double> bins = {};
    for (int i = 0; i < totalBins; i++) {
      final binKey = startMs + (i * binSizeMs);
      bins[binKey] = 0.0;
    }
    for (var alert in filteredAlerts) {
      try {
        final triggeredStr = alert['triggered_at'] ?? alert['created_at'];
        final triggered = DateTime.parse(triggeredStr);
        final timestampMs = triggered.millisecondsSinceEpoch;
        final relativeMs = timestampMs - startMs;
        final binIndex = (relativeMs / binSizeMs).floor();
        final binKey = startMs + (binIndex * binSizeMs);
        if (bins.containsKey(binKey)) {
          bins[binKey] = bins[binKey]! + 1.0;
        }
      } catch (e) {
        // Skip invalid entries
      }
    }
    final List<FlSpot> spots = [];
    bins.forEach((binKey, value) {
      final binMidMs = binKey + (binSizeMs / 2);
      final xValue = (binMidMs - startMs) / (1000 * 60 * 60).toDouble();
      spots.add(FlSpot(xValue, value));
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
  double _getMaxY(List<FlSpot> spots, {bool isEnergy = false, bool isTemperature = false, bool isHumidity = false, bool isSecurity = false}) {
    if (spots.isEmpty) {
      if (isTemperature) return 50.0;
      if (isHumidity) return 100.0;
      if (isSecurity) return 10.0;
      return isEnergy ? 0.1 : 100.0;
    }
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    if (maxY == 0) {
      if (isTemperature) return 50.0;
      if (isHumidity) return 100.0;
      if (isSecurity) return 10.0;
      return isEnergy ? 0.1 : 100.0;
    }
    if (isTemperature) return (maxY * 1.2).ceilToDouble();
    if (isHumidity) return (maxY * 1.2).ceilToDouble();
    if (isSecurity) return (maxY * 1.2).ceilToDouble();
    return isEnergy ? (maxY < 0.1 ? 0.1 : (maxY * 1.2)) : (maxY * 1.2).ceilToDouble();
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
          return _navigateToMaintenanceManagement();
        }
      }
    } catch (e) {
      print('Error fetching user role: $e');
      setState(() {
        errorMessage = 'Error fetching user role: $e';
      });
    }
    SafeNavigation.push(
      context,
      MaintenanceManagementScreen(
        accessToken: AuthService().accessToken ?? widget.accessToken,
        refreshToken: AuthService().refreshToken ?? widget.refreshToken,
        userRole: userRole,
      ),
      routeName: 'maintenance',
    ).then((_) {
      loadEnergyData();
    });
  }
  Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
  void _navigateToNotifications() {
    SafeNavigation.push(
      context,
      NotificationsScreen(
        accessToken: AuthService().accessToken ?? widget.accessToken,
        refreshToken: AuthService().refreshToken ?? widget.refreshToken,
      ),
      routeName: 'notifications',
    ).then((_) {
      // Refresh notifications after returning from NotificationsScreen
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      provider.loadData(context: context);
    });
  }
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final now = DateTime.now();
    final startTime = _getStartTime(now);
    final powerSpots = _generatePowerSpots();
    final energySpots = _generateEnergySpots();
    final temperatureSpots = _generateTemperatureSpots();
    final humiditySpots = _generateHumiditySpots();
    final securityAlertSpots = _generateSecurityAlertSpots();
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
    return SafePopScope(
      routeName: 'analytics',
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F1E23),
          title: Text(
            '${_getScopeTitle()}',
            style: GoogleFonts.urbanist(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: ImageIcon(
                AssetImage(provider.unreadNotificationCount > 0
                    ? 'assets/icons/Notif ping.png'
                    : 'assets/icons/Notif default.png'),
                size: 24,
                color: Colors.white70,
              ),
              onPressed: isRefreshingToken ? null : _navigateToNotifications,
              tooltip: 'View Notifications',
            ),
          ],
        ),
        body: isLoading || isRefreshingToken
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF184BFB)))
            : RefreshIndicator(
          onRefresh: () {
            final provider = Provider.of<DashboardProvider>(context, listen: false);
            return Future.wait([
              loadEnergyData(),
              provider.loadData(context: context, showLoading: false),
            ]).then((_) => null);
          },
          color: const Color(0xFF184BFB),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMessage.isNotEmpty)
                  AnalyticsWidgets.buildErrorBanner(errorMessage),
                AnalyticsWidgets.buildFilterSelector(
                  currentTimeFrame: timeFrame,
                  onTimeFrameChanged: _changeTimeFrame,
                  currentScope: selectedScope,
                  onScopeChanged: (newScope) => _changeScope(newScope),
                  selectedRoomId: selectedRoomId,
                  rooms: rooms,
                  onRoomChanged: (value) {
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
                  selectedComponentId: selectedComponentId,
                  equipment: equipment,
                  onEquipmentChanged: (value) {
                    if (value != null) {
                      _changeScope('room', newComponentId: value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                AnalyticsWidgets.buildPowerChart(
                  scopeTitle: _getScopeTitle(),
                  chartSuffix: chartSuffix,
                  powerSpots: powerSpots,
                  timeFrame: timeFrame,
                  startTime: startTime,
                  maxX: maxX,
                  interval: interval,
                  formatTimeAxis: _formatTimeAxis,
                  shouldShowLabel: _shouldShowLabel,
                  maxY: _getMaxY(powerSpots),
                ),
                const SizedBox(height: 16),
                AnalyticsWidgets.buildEnergyChart(
                  scopeTitle: _getScopeTitle(),
                  chartSuffix: chartSuffix,
                  energySpots: energySpots,
                  timeFrame: timeFrame,
                  startTime: startTime,
                  maxX: maxX,
                  interval: interval,
                  formatTimeAxis: _formatTimeAxis,
                  shouldShowLabel: _shouldShowLabel,
                  maxY: _getMaxY(energySpots, isEnergy: true),
                ),
                const SizedBox(height: 16),
                AnalyticsWidgets.buildTemperatureChart(
                  scopeTitle: _getScopeTitle(),
                  chartSuffix: chartSuffix,
                  temperatureSpots: temperatureSpots,
                  timeFrame: timeFrame,
                  startTime: startTime,
                  maxX: maxX,
                  interval: interval,
                  formatTimeAxis: _formatTimeAxis,
                  shouldShowLabel: _shouldShowLabel,
                  maxY: _getMaxY(temperatureSpots, isTemperature: true),
                ),
                const SizedBox(height: 16),
                AnalyticsWidgets.buildHumidityChart(
                  scopeTitle: _getScopeTitle(),
                  chartSuffix: chartSuffix,
                  humiditySpots: humiditySpots,
                  timeFrame: timeFrame,
                  startTime: startTime,
                  maxX: maxX,
                  interval: interval,
                  formatTimeAxis: _formatTimeAxis,
                  shouldShowLabel: _shouldShowLabel,
                  maxY: _getMaxY(humiditySpots, isHumidity: true),
                ),
                const SizedBox(height: 16),
                AnalyticsWidgets.buildSecurityChart(
                  scopeTitle: _getScopeTitle(),
                  chartSuffix: chartSuffix,
                  securityAlertSpots: securityAlertSpots,
                  timeFrame: timeFrame,
                  startTime: startTime,
                  maxX: maxX,
                  interval: interval,
                  formatTimeAxis: _formatTimeAxis,
                  shouldShowLabel: _shouldShowLabel,
                  maxY: _getMaxY(securityAlertSpots, isSecurity: true),
                ),
                const SizedBox(height: 16),
                AnalyticsWidgets.buildStatisticsCard(
                  scopeTitle: _getScopeTitle(),
                  summaryData: summaryData,
                  totalCost: totalCost,
                  effectiveRate: effectiveRate,
                  billingData: billingData,
                ),
                const SizedBox(height: 16),
                AnalyticsWidgets.buildHvacStatusCard(
                  scopeTitle: _getScopeTitle(),
                  hvacData: hvacData,
                ),
                const SizedBox(height: 16),
                AnalyticsWidgets.buildSecurityStatusCard(
                  scopeTitle: _getScopeTitle(),
                  securityData: securityData,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          onMenuSelection: (value) {
            switch (value) {
              case 'dashboard':
                SafeNavigation.pop(context);
                break;
              case 'maintenance_requests':
                _navigateToMaintenanceManagement();
                break;
              case 'orb_chat':
                SafeNavigation.push(
                  context,
                  ChatScreen(
                    accessToken: AuthService().accessToken ?? widget.accessToken,
                    refreshToken: AuthService().refreshToken ?? widget.refreshToken,
                  ),
                  routeName: 'chat',
                );
                break;
              case 'analytics':
                break;
              default:
                break;
            }
          },
          currentScreen: 'analytics',
        ),
      ),
    );
  }
}