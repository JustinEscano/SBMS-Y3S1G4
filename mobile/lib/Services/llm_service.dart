import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/chat_message.dart';
import '../config.dart'; // Import the config file

class LLMService {
  final String baseUrl;
  String accessToken;

  LLMService({required this.baseUrl, required this.accessToken});

  // Send a query to the LLM
  Future<Map<String, dynamic>> queryLLM(String query, {String? userId}) async {
    try {
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final body = {
        'query': query,
        if (userId != null) 'user_id': userId,
      };

      final url = Uri.parse('$baseUrl/api/llm/query/');
      print('Sending POST to: $url with body: ${json.encode(body)}'); // Debug log
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      print('queryLLM response: status=${response.statusCode}, body=${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'query': data['query'] ?? query,
          'answer': data['answer'] ?? '',
          'sources': data['sources'],
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        };
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to query LLM: ${response.statusCode}');
      }
    } catch (e) {
      print('queryLLM error: $e'); // Debug log
      throw Exception('Network error: $e');
    }
  }

  // Check LLM health status
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      };

      final url = Uri.parse('$baseUrl/api/llm/health/');
      print('Sending GET to: $url'); // Debug log
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('checkHealth response: status=${response.statusCode}, body=${response.body}'); // Debug log

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check LLM health: ${response.statusCode}');
      }
    } catch (e) {
      print('checkHealth error: $e'); // Debug log
      throw Exception('Network error: $e');
    }
  }

  // Get suggested queries
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

  // Format timestamp
  String formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return dateTime.toLocal().toString();
    } catch (e) {
      return timestamp;
    }
  }

  // Generate unique message ID
  String generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
  }

  // Get conversation history
  Future<List<Map<String, dynamic>>> getConversationHistory() async {
    try {
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      };

      final url = Uri.parse('$baseUrl/api/llm/query/');
      print('Sending GET to: $url'); // Debug log
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('getConversationHistory response: status=${response.statusCode}, body=${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to fetch conversation history: ${response.statusCode}');
      }
    } catch (e) {
      print('getConversationHistory error: $e'); // Debug log
      throw Exception('Network error: $e');
    }
  }
}