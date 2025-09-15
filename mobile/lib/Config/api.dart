import 'dart:io';

class ApiConfig {
  static final String baseUrl = Platform.isAndroid
      ? "http://10.0.2.2:8000/api"
      : "http://localhost:8000/api";

  // Endpoints for LoginScreen
  static String get register => "$baseUrl/register/";
  static String get login => "$baseUrl/token/";
  static String get refreshToken => "$baseUrl/token/refresh/";
  static String get verifyToken => "$baseUrl/verify-token/";

  // Endpoints for DashboardScreen and EquipmentManagementScreen
  static String get rooms => "$baseUrl/rooms/";
  static String get equipment => "$baseUrl/equipment/";
  static String get sensorLog => "$baseUrl/sensorlog/";
  static String get latestSensorData => "$baseUrl/esp32/latest/";
  static String get maintenanceRequest => "$baseUrl/maintenancerequest/";

  // Endpoint for MaintenanceManagementScreen
  static String get users => "$baseUrl/users/";

  // Endpoints for ChatScreen and LLMService
  static String get llmQuery => "$baseUrl/llm/query/";
  static String get llmHealth => "$baseUrl/llm/health/";
}