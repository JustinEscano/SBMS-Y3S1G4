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
  List<dynamic> maintenanceRequests = [];
  List<dynamic> notifications = [];
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<bool> refreshToken(BuildContext context) async {
    try {
      final success = await _authService.refresh();
      if (success) {
        return true;
      }
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

  Future<void> loadData({BuildContext? context}) async {
    isLoading = true;
    errorMessage = '';
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
      ]);

      rooms = responses[0];
      equipment = responses[1];
      sensorLogs = responses[2];
      latestSensorData = responses[3];
      maintenanceRequests = responses[4];
      notifications = responses[5];
      unreadNotificationCount = notifications.where((n) => n['read'] == false).length;

      await _loadSystemStatus();
    } catch (e) {
      errorMessage = e.toString().contains('Session expired') ? e.toString() : 'Error loading data: $e';
      if (context != null && e.toString().contains('Session expired') && context.mounted) {
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

  Future<void> _loadSystemStatus() async {
    try {
      hvacData = await _dashboardRepository.generateHVACData(latestSensorData);
      lightingData = await _dashboardRepository.generateLightingData(equipment, latestSensorData, rooms);
      securityData = await _dashboardRepository.generateSecurityData(equipment, latestSensorData, rooms);
      energyData = await _dashboardRepository.generateEnergyData(latestSensorData);
      maintenanceData = await _dashboardRepository.generateMaintenanceData(maintenanceRequests);
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error processing system status: $e';
      notifyListeners();
    }
  }
}