import 'dart:io';

class ApiConfig {
  static const String _environment = 'dev';
  static const String _prodBaseUrl = 'https://your-api-domain.com/api/';
  static String get _devBaseUrl => Platform.isAndroid
      ? 'http://10.0.2.2:8000/api'
      : 'http://192.168.0.12:8000/api';
  static String get baseUrl => _environment == 'prod' ? _prodBaseUrl : _devBaseUrl;

  // Authentication Endpoints
  static String get register => '$baseUrl/register/';
  static String get login => '$baseUrl/token/';
  static String get refreshToken => '$baseUrl/token/refresh/';
  static String get verifyToken => '$baseUrl/verify-token/';
  static String get userInfo => '$baseUrl/users/me/';

  // Equipment and Dashboard Endpoints
  static String get rooms => '$baseUrl/rooms/';
  static String get equipment => '$baseUrl/equipment/';
  static String get sensorLog => '$baseUrl/sensorlog/';
  static String get latestSensorData => '$baseUrl/esp32/latest/';

  // Maintenance Endpoints
  static String get maintenanceRequest => '$baseUrl/maintenancerequest/';
  static String maintenanceRequestDetail(String id) => '$maintenanceRequest$id/';
  static String maintenanceRequestRespond(String id) => '$maintenanceRequest$id/respond/';
  static String maintenanceRequestUploadAttachment(String id) => '$maintenanceRequest$id/upload_attachment/';
  static String get users => '$baseUrl/users/';

  // Chat and LLM Endpoints
  static String get llmQuery => '$baseUrl/llm/query/';
  static String get llmHealth => '$baseUrl/llm/health/';
}