import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Config/api.dart';
import '../Models/chat_message.dart';
import '../Services/auth_service.dart';

class LLMService {
  // Session management
  late String sessionId;
  String? userId;
  String? username;
  String? userEmail;

  LLMService() {
    _initializeSession();
  }

  // Initialize session with user ID
  Future<void> _initializeSession() async {
    try {
      final userInfo = await _getUserInfo();
      sessionId = 'mobile_${userInfo['user_id']}_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      sessionId = 'mobile_session_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Get user info from AuthService and profile
  Future<Map<String, String>> _getUserInfo() async {
    try {
      // Always get fresh user ID
      final currentUserId = await AuthService().getCurrentUserId();
      userId = currentUserId;

      // Always fetch fresh profile data to ensure we have latest username
      try {
        final authService = AuthService();
        final profileData = await authService.apiService.fetchProfile();
        
        print('📋 Profile Data Structure: ${profileData.keys}');
        
        // Extract username from profile - try multiple paths
        String? extractedUsername;
        String? extractedEmail;
        
        if (profileData['profile'] != null) {
          print('📋 Profile nested data: ${profileData['profile'].keys}');
          extractedUsername = profileData['profile']['full_name'] ?? 
                    profileData['profile']['username'] ?? 
                    profileData['username'];
          extractedEmail = profileData['email'];
        } else {
          // Direct structure (no nested profile)
          print('📋 Direct profile structure');
          extractedUsername = profileData['full_name'] ?? 
                    profileData['username'] ?? 
                    profileData['email'];
          extractedEmail = profileData['email'];
        }
        
        // Update cached values
        username = extractedUsername;
        userEmail = extractedEmail;
        
        print('✅ LLM User Info - ID: $userId, Username: $username, Email: $userEmail');
      } catch (e) {
        print('❌ Failed to fetch profile for LLM: $e');
        // Fallback to user ID
        username = userId;
      }

      // Return with proper fallback chain
      final finalUsername = username ?? userEmail ?? userId ?? 'Mobile User';
      final finalUserId = userId ?? 'mobile_user';
      
      print('🎯 Final LLM credentials - ID: $finalUserId, Username: $finalUsername');

      return {
        'user_id': finalUserId,
        'username': finalUsername,
      };
    } catch (e) {
      print('❌ Error getting user info: $e');
      return {
        'user_id': 'mobile_user',
        'username': 'Mobile User',
      };
    }
  }

  // General LLM query
  Future<Map<String, dynamic>> queryLLM(String query, {String? userId}) async {
    if (!(await AuthService().ensureValidToken())) {
      throw Exception('Invalid token');
    }

    final userInfo = await _getUserInfo();
    final String? role = _determineUserRole(query);
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (role != null) 'X-User-Role': role,
    };

    final body = jsonEncode({
      'query': query,
      'user_id': userInfo['user_id'],
      'username': userInfo['username'],
      'session_id': sessionId,
      'client_ip': '127.0.0.1',
    });

    final response = await http.post(
      Uri.parse(ApiConfig.llmQueryDirect),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to query LLM: ${response.statusCode} - ${response.body}');
    }
  }

  // Maintenance prediction endpoint
  Future<Map<String, dynamic>> predictMaintenance({String? query}) async {
    if (!(await AuthService().ensureValidToken())) {
      throw Exception('Invalid token');
    }

    final userInfo = await _getUserInfo();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-User-Role': 'facility_manager',
    };

    final body = jsonEncode({
      'query': query ?? 'Analyze equipment and suggest maintenance',
      'user_id': userInfo['user_id'],
      'username': userInfo['username'],
    });

    final response = await http.post(
      Uri.parse(ApiConfig.llmMaintenancePredict),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to predict maintenance: ${response.statusCode}');
    }
  }

  // Anomaly detection endpoint
  Future<Map<String, dynamic>> detectAnomalies({double sensitivity = 0.8, String? query}) async {
    if (!(await AuthService().ensureValidToken())) {
      throw Exception('Invalid token');
    }

    final userInfo = await _getUserInfo();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-User-Role': 'facility_manager',
    };

    final body = jsonEncode({
      'query': query ?? '', // Full user query for personality extraction
      'sensitivity': sensitivity,
      'user_id': userInfo['user_id'],
      'username': userInfo['username'],
    });

    final response = await http.post(
      Uri.parse(ApiConfig.llmAnomaliesDetect),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to detect anomalies: ${response.statusCode}');
    }
  }

  // Energy report endpoint
  Future<Map<String, dynamic>> getEnergyReport(String period, {String? query}) async {
    if (!(await AuthService().ensureValidToken())) {
      throw Exception('Invalid token');
    }

    final userInfo = await _getUserInfo();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-User-Role': 'energy_analyst',
    };

    final body = jsonEncode({
      'period': period, // 'daily', 'weekly', 'monthly', 'yearly'
      'query': query ?? '', // Full user query for personality extraction
      'user_id': userInfo['user_id'],
      'username': userInfo['username'],
    });

    final response = await http.post(
      Uri.parse(ApiConfig.llmEnergyReport),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get energy report: ${response.statusCode}');
    }
  }

  // Billing rates endpoint
  Future<Map<String, dynamic>> getBillingRates({String? query}) async {
    if (!(await AuthService().ensureValidToken())) {
      throw Exception('Invalid token');
    }

    final userInfo = await _getUserInfo();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-User-Role': 'energy_analyst',
    };

    final body = jsonEncode({
      'query': query ?? '', // Full user query for personality extraction
      'user_id': userInfo['user_id'],
      'username': userInfo['username'],
    });

    final response = await http.post(
      Uri.parse(ApiConfig.llmBillingRates),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get billing rates: ${response.statusCode}');
    }
  }

  // KPI heartbeat endpoint
  Future<Map<String, dynamic>> getKpiHeartbeat({String? query}) async {
    if (!(await AuthService().ensureValidToken())) {
      throw Exception('Invalid token');
    }

    final userInfo = await _getUserInfo();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-User-Role': 'facility_manager',
    };

    final body = jsonEncode({
      'query': query ?? '', // Full user query for personality extraction
      'user_id': userInfo['user_id'],
      'username': userInfo['username'],
    });

    final response = await http.post(
      Uri.parse(ApiConfig.llmKpiHeartbeat),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get KPI heartbeat: ${response.statusCode}');
    }
  }

  // Rooms list endpoint
  Future<Map<String, dynamic>> getRoomsList({String? query}) async {
    if (!(await AuthService().ensureValidToken())) {
      throw Exception('Invalid token');
    }

    final userInfo = await _getUserInfo();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      'user_id': userInfo['user_id'],
      'username': userInfo['username'],
      'query': query ?? '',
    });

    final response = await http.post(
      Uri.parse(ApiConfig.llmRoomsList),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get rooms list: ${response.statusCode}');
    }
  }

  // Save chat to MongoDB
  Future<void> saveChatToMongoDB({
    required String userMessage,
    required String assistantResponse,
    required String queryType,
    required String userRole,
    int? responseTimeMs,
    bool hasError = false,
  }) async {
    try {
      final userInfo = await _getUserInfo();
      final body = jsonEncode({
        'user_id': userInfo['user_id'],
        'username': userInfo['username'],
        'session_id': sessionId,
        'user_message': userMessage,
        'assistant_response': assistantResponse,
        'query_type': queryType,
        'user_role': userRole,
        'response_time_ms': responseTimeMs,
        'has_error': hasError,
      });

      await http.post(
        Uri.parse(ApiConfig.llmChatHistorySave),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      // Don't throw - we don't want to break the UI if MongoDB save fails
      print('Failed to save chat to MongoDB: $e');
    }
  }

  // Get chat history from MongoDB
  Future<List<dynamic>> getChatHistory({int limit = 50}) async {
    try {
      final userInfo = await _getUserInfo();
      final body = jsonEncode({
        'user_id': userInfo['user_id'],
        'session_id': sessionId,
        'limit': limit,
      });

      final response = await http.post(
        Uri.parse(ApiConfig.llmChatHistoryGet),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['chats'] ?? [];
      }
      return [];
    } catch (e) {
      print('Failed to get chat history: $e');
      return [];
    }
  }

  // Health check
  Future<Map<String, dynamic>> getHealth() async {
    final response = await http.get(Uri.parse(ApiConfig.llmHealthDirect));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Health check failed: ${response.statusCode}');
    }
  }

  // Conversation history (legacy)
  Future<List<dynamic>> getConversationHistory() async {
    return [];
  }

  String generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Determine query type from message
  String determineQueryType(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('maintenance') ||
        lowerQuery.contains('repair') ||
        lowerQuery.contains('fix') ||
        lowerQuery.contains('broken') ||
        lowerQuery.contains('check for maintenance')) {
      return 'maintenance';
    } else if (lowerQuery.contains('anomal') ||
        lowerQuery.contains('unusual') ||
        lowerQuery.contains('strange') ||
        lowerQuery.contains('weird') ||
        lowerQuery.contains('alert') ||
        lowerQuery.contains('warning')) {
      return 'anomalies';
    } else if (lowerQuery.contains('energy') ||
        lowerQuery.contains('power') ||
        lowerQuery.contains('kwh') ||
        lowerQuery.contains('consumption') ||
        lowerQuery.contains('watt')) {
      return 'energy';
    } else if (RegExp(r'\b(billing|bill|rate|rates|pricing)\b')
        .hasMatch(lowerQuery)) {
      return 'billing';
    } else if (lowerQuery.contains('room') ||
        lowerQuery.contains('utilization') ||
        lowerQuery.contains('usage') ||
        lowerQuery.contains('occupied') ||
        lowerQuery.contains('most used')) {
      return 'utilization';
    } else if (lowerQuery.contains('report') ||
        lowerQuery.contains('summary') ||
        lowerQuery.contains('weekly') ||
        lowerQuery.contains('daily') ||
        lowerQuery.contains('monthly') ||
        lowerQuery.contains('yearly') ||
        lowerQuery.contains('week') ||
        lowerQuery.contains('overview')) {
      return 'summary';
    } else if (lowerQuery.contains('kpi') ||
        lowerQuery.contains('heartbeat') ||
        lowerQuery.contains('sensor health') ||
        lowerQuery.contains('system health') ||
        lowerQuery.contains('device health') ||
        lowerQuery.contains('iot health')) {
      return 'kpi';
    }

    return 'general';
  }

  // Determine report period
  String determineReportPeriod(String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.contains('daily') || lowerQuery.contains('day')) {
      return 'daily';
    }
    if (lowerQuery.contains('monthly') || lowerQuery.contains('month')) {
      return 'monthly';
    }
    if (lowerQuery.contains('yearly') ||
        lowerQuery.contains('year') ||
        lowerQuery.contains('annual')) {
      return 'yearly';
    }
    return 'weekly';
  }

  // Determine user role from query type
  String _determineUserRole(String query) {
    final queryType = determineQueryType(query);
    switch (queryType) {
      case 'maintenance':
      case 'anomalies':
      case 'kpi':
        return 'facility_manager';
      case 'energy':
      case 'billing':
        return 'energy_analyst';
      case 'summary':
      case 'utilization':
      case 'context':
      case 'general':
      default:
        return 'viewer';
    }
  }
}