import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/chat_message.dart';
import '../Config/api.dart';
import '../Services/auth_service.dart'; // Add AuthService import

class LLMService {
  LLMService(); // Remove accessToken parameter, use AuthService

  Future<bool> _refreshToken() async {
    try {
      return await AuthService().refresh();
    } catch (e) {
      throw Exception('Error refreshing token: $e');
    }
  }

  Future<Map<String, dynamic>> queryLLM(String query, {String? userId}) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      final body = {
        'query': query,
        if (userId != null) 'user_id': userId,
      };

      final url = Uri.parse(ApiConfig.llmQuery);
      print('Sending POST to: $url with body: ${json.encode(body)}');
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      print('queryLLM response: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'query': data['query'] ?? query,
          'answer': data['answer'] ?? '',
          'sources': data['sources'],
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
          'conversation_id': data['conversation_id'], // Include conversation_id
        };
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return queryLLM(query, userId: userId); // Retry with new token
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        throw Exception('Failed to query LLM: ${response.statusCode}');
      }
    } catch (e) {
      print('queryLLM error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> checkHealth() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      final url = Uri.parse(ApiConfig.llmHealth);
      print('Sending GET to: $url');
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('checkHealth response: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return checkHealth(); // Retry with new token
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        throw Exception('Failed to check LLM health: ${response.statusCode}');
      }
    } catch (e) {
      print('checkHealth error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getConversationHistory() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      final url = Uri.parse(ApiConfig.llmQuery);
      print('Sending GET to: $url');
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('getConversationHistory response: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return getConversationHistory(); // Retry with new token
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        throw Exception('Failed to fetch conversation history: ${response.statusCode}');
      }
    } catch (e) {
      print('getConversationHistory error: $e');
      throw Exception('Network error: $e');
    }
  }

  List<String> getSuggestedQueries() {
    return [
      "What is the average temperature?",
      "Show me the highest energy consumption",
      "How many sensor records do we have?",
      "What was the temperature at 2024-01-15 10:30:00?",
      "Which rooms have motion detected?",
      "Compare energy usage between different rooms",
      "Show me temperature trends over time",
      "What is the lowest humidity recorded?",
      "List all equipment that is offline",
      "What are the power consumption patterns?"
    ];
  }

  String formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return dateTime.toLocal().toString();
    } catch (e) {
      return timestamp;
    }
  }

  String generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
  }
}