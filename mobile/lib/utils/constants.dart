import 'dart:io';

class ApiConfig {
  static const String _environment = 'dev';
  static const String _prodBaseUrl = 'https://your-api-domain.com/api/';
  static String get _devBaseUrl => Platform.isAndroid
      ? 'http://192.168.0.33:8000/api'
      : 'http://192.168.0.33:8000/api';
  static String get baseUrl => _environment == 'prod' ? _prodBaseUrl : _devBaseUrl;

  // Construct media URLs correctly
  static String getMediaUrl(String relativePath) {
    return '${baseUrl.replaceAll('/api', '')}/media/$relativePath';
  }

  // Authentication Endpoints
  static String get register => '$baseUrl/register/';
  static String get login => '$baseUrl/token/';
  static String get refreshToken => '$baseUrl/token/refresh/';
  static String get verifyToken => '$baseUrl/token/verify/';
  static String get userInfo => '$baseUrl/users/me/';

  // Dashboard and Summary Endpoints
  static String get dashboardSummary => '$baseUrl/dashboard/summary/';
  static String get checkAnomalies => '$baseUrl/check-anomalies/';
  static String get predictMaintenance => '$baseUrl/predict-maintenance/';

  // Room and Equipment Endpoints
  static String get rooms => '$baseUrl/rooms/';
  static String roomRealtime(String pk) => '$baseUrl/rooms/$pk/realtime/';
  static String get equipment => '$baseUrl/equipment/';
  static String get components => '$baseUrl/components/';

  // Sensor and Log Endpoints
  static String get sensorLog => '$baseUrl/sensorlog/';
  static String get latestSensorData => '$baseUrl/esp32/latest/';
  static String get heartbeatLog => '$baseUrl/heartbeatlog/';

  // Energy and Billing Endpoints
  static String energySummary({String? periodType, String? roomId}) {
    String url = '$baseUrl/energysummary/';
    List<String> params = [];
    if (periodType != null) params.add('period_type=$periodType');
    if (roomId != null) params.add('room_id=$roomId');
    return params.isNotEmpty ? '$url?${params.join('&')}' : url;
  }
  static String get billingRate => '$baseUrl/billingrate/';
  static String get calculateEnergyCost => '$baseUrl/billingrate/calculate_energy_cost/';

  // Alert Endpoints
  static String get alert => '$baseUrl/alert/';
  static String get predictiveAlert => '$baseUrl/predictivealert/';

  // Maintenance Endpoints
  static String get maintenanceRequest => '$baseUrl/maintenancerequest/';
  static String maintenanceRequestDetail(String id) => '$maintenanceRequest$id/';
  static String maintenanceRequestRespond(String id) => '$maintenanceRequest$id/respond/';
  static String maintenanceRequestUploadAttachment(String id) => '$maintenanceRequest$id/upload_attachment/';

  // Notification Endpoints
  static String notification({int? page, int? pageSize}) {
    String url = '$baseUrl/notification/';
    List<String> params = [];
    if (page != null) params.add('page=$page');
    if (pageSize != null) params.add('page_size=$pageSize');
    return params.isNotEmpty ? '$url?${params.join('&')}' : url;
  }
  static String get notificationMarkAllRead => '$baseUrl/notification/mark_all_read/';
  static String notificationMarkRead(String id) => '$baseUrl/notification/$id/mark_read/';
  static String notificationDelete(String id) => '$baseUrl/notification/$id/';

  // User Management
  static String get users => '$baseUrl/users/';
  static String get profile => '$baseUrl/users/profile/';

  // Chat and LLM Endpoints
  static String get llmQuery => '$baseUrl/llm/query/';
  static String get llmHealth => '$baseUrl/llm/health/';
}