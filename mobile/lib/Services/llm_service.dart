import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Config/api.dart';
import '../Models/chat_message.dart';
import '../Services/auth_service.dart';

class LLMService {
  Future<Map<String, dynamic>> queryLLM(String query, {String? userId}) async {
    if (!(await AuthService().ensureValidToken())) {
      throw Exception('Invalid token');
    }

    final String? role = _determineUserRole(query);  // Add role logic like web
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (role != null) 'X-User-Role': role,
      'Authorization': 'Bearer ${AuthService().accessToken}',
    };

    final body = jsonEncode({
      'query': query,
      'user_id': userId ?? 'mobile_user',
      'username': 'Mobile User',
      'session_id': 'mobile_session',
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

  Future<Map<String, dynamic>> getHealth() async {
    final response = await http.get(Uri.parse(ApiConfig.llmHealthDirect));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Health check failed: ${response.statusCode}');
    }
  }

  // Placeholder for conversation history (if still needed; could bypass if not using backend)
  Future<List<dynamic>> getConversationHistory() async {
    // If history is on backend, keep using ApiConfig.llmQuery; else, implement direct if LLM server supports it
    // For now, assuming it's not needed or stubbed
    return [];
  }

  String generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Add similar to web
  String? _determineUserRole(String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.contains('maintenance') || lowerQuery.contains('repair') ||
        lowerQuery.contains('fix') || lowerQuery.contains('broken')) {
      return 'facility_manager';
    } else if (lowerQuery.contains('energy') || lowerQuery.contains('power') ||
        lowerQuery.contains('kwh') || lowerQuery.contains('consumption') ||
        lowerQuery.contains('watt')) {
      return 'energy_analyst';
    } else if (lowerQuery.contains('summary') || lowerQuery.contains('report') ||
        lowerQuery.contains('week') || lowerQuery.contains('overview')) {
      return 'viewer';
    }
    // Add more as needed from web
    return 'viewer';
  }
}