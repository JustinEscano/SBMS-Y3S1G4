import 'package:flutter/foundation.dart';
import 'dart:async';
import '../Services/auth_service.dart';
import '../Services/api_service.dart';
import '../repositories/dashboard_repository.dart';
import '../Screens/LoginScreen.dart';
import 'package:flutter/material.dart';
class DashboardProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiService _apiService;
  final DashboardRepository _dashboardRepository;
  List<dynamic> rooms = [];
  List<dynamic> equipment = [];
  List<dynamic> sensorLogs = [];
  List<dynamic> latestSensorData = [];
  List<Map<String, dynamic>> aggregatedSensorData = [];
  List<dynamic> maintenanceRequests = [];
  List<dynamic> notifications = [];
  List<dynamic> alerts = [];
  int unreadNotificationCount = 0;
  Map<String, dynamic> hvacData = {};
  Map<String, dynamic> lightingData = {};
  Map<String, dynamic> securityData = {};
  Map<String, dynamic> energyData = {};
  List<dynamic> maintenanceData = [];
  bool isLoading = true;
  String errorMessage = '';
  Timer? _refreshTimer;
  DashboardProvider(this._authService, this._apiService, this._dashboardRepository);
  ApiService get apiService => _apiService;
  Future<void> setTokens(String accessToken, String refreshToken) async {
    await _authService.setTokens(accessToken, refreshToken);
    notifyListeners();
  }
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => loadData());
  }
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  Future<bool> refreshToken(BuildContext context) async {
    try {
      final success = await _authService.refresh();
      if (success) return true;
      errorMessage = 'Session expired. Please log in again.';
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'Failed to refresh session: $e';
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      notifyListeners();
      return false;
    }
  }
  Future<void> loadData({BuildContext? context, bool showLoading = false}) async {
    errorMessage = '';
    if (showLoading) {
      isLoading = true;
    }
    notifyListeners();
    try {
      if (!(await _authService.ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final responses = await Future.wait([
        _apiService.fetchRooms(),
        _apiService.fetchEquipment(),
        _apiService.fetchSensorLogs(),
        _apiService.fetchLatestSensorData(),
        _apiService.fetchMaintenanceRequests(),
        _apiService.fetchNotifications(),
        _apiService.fetchAlerts(),
      ]);
      rooms = responses[0];
      equipment = responses[1];
      sensorLogs = responses[2];
      latestSensorData = responses[3];
      maintenanceRequests = responses[4];
      notifications = responses[5];
      alerts = responses[6];
      unreadNotificationCount =
          notifications.where((n) => n['read'] == false).length;
      // ONE CARD PER DEVICE_ID (latest log only, aggregated by device_id)
      aggregatedSensorData = _aggregateSensorData(latestSensorData);
      await _loadSystemStatus();
    } catch (e) {
      errorMessage = e.toString().contains('Session expired')
          ? e.toString()
          : 'Error loading data: $e';
      if (context != null &&
          e.toString().contains('Session expired') &&
          context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  /// --------------------------------------------------------------
  /// ONE CARD PER DEVICE_ID – latest log only, merge partial records
  /// --------------------------------------------------------------
  List<Map<String, dynamic>> _aggregateSensorData(List<dynamic> logs) {
    final Map<String, Map<String, dynamic>> map = {}; // key = deviceId
    final now = DateTime.now();
    for (final log in logs) {
      final String eqId = log['equipment']?.toString() ?? '';
      final equip = eqId.isNotEmpty
          ? equipment.firstWhere(
            (e) => e['id']?.toString() == eqId,
        orElse: () => <String, dynamic>{},
      )
          : <String, dynamic>{};
      String deviceId = log['device_id']?.toString() ?? equip['device_id']?.toString() ?? '';
      if (deviceId.isEmpty) continue; // Skip if no device ID available
      final String equipName = log['equipment_name']?.toString() ??
          equip['name']?.toString() ??
          'Unassociated Device ($deviceId)';
      final String recStr = log['recorded_at'] ?? '';
      final DateTime? rec = recStr.isNotEmpty ? DateTime.tryParse(recStr) : null;
      final bool online = rec != null && now.difference(rec).inSeconds <= 30;
      final String status = online ? 'online' : 'offline';
      // ---- Keep only the *newest* log per device -------------------------------
      if (!map.containsKey(deviceId)) {
        map[deviceId] = {
          'device_id': deviceId,
          'equipment_uuid': eqId,
          'equipment_name': equipName,
          'recorded_at': recStr,
          'status': status,
        };
      }
      // Update if this log is newer
      final existing = map[deviceId]!;
      final existingRec = DateTime.tryParse(existing['recorded_at'] ?? '');
      if (rec != null && (existingRec == null || rec.isAfter(existingRec))) {
        existing['recorded_at'] = recStr;
        existing['status'] = status;
        existing['equipment_uuid'] = eqId;
        existing['equipment_name'] = equipName;
      }
      // ---- Copy ALL sensor fields (latest non-null wins) -----------------------
      final fields = [
        'temperature',
        'humidity',
        'light_detected',
        'motion_detected',
        'voltage',
        'current',
        'power',
        'energy',
      ];
      for (final f in fields) {
        if (log[f] != null) {
          existing[f] = log[f];
        }
      }
    }
    return map.values.toList();
  }
  Future<void> _loadSystemStatus() async {
    try {
      hvacData = await _dashboardRepository.generateHVACData(latestSensorData);
      lightingData = await _dashboardRepository
          .generateLightingData(equipment, latestSensorData, rooms);
      securityData = await _dashboardRepository
          .generateSecurityData(equipment, latestSensorData, rooms, alerts);
      energyData = await _dashboardRepository.generateEnergyData(latestSensorData);
      maintenanceData = await _dashboardRepository
          .generateMaintenanceData(maintenanceRequests);
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error processing system status: $e';
      notifyListeners();
    }
  }
}