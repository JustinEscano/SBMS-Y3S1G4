import 'package:flutter/foundation.dart';
import '../Models/chat_message.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _currentConversationId;
  String _errorMessage = '';

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get currentConversationId => _currentConversationId;
  String get errorMessage => _errorMessage;

  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void addMessages(List<ChatMessage> newMessages) {
    _messages.addAll(newMessages);
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setConversationId(String? conversationId) {
    _currentConversationId = conversationId;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void clearConversation() {
    _messages.clear();
    _currentConversationId = null;
    _errorMessage = '';
    notifyListeners();
  }

  void updateMessage(String messageId, String newContent) {
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      _messages[index] = ChatMessage(
        id: messageId,
        content: newContent,
        type: _messages[index].type, // Updated to use type instead of isUser
        timestamp: _messages[index].timestamp,
        conversationId: _messages[index].conversationId,
        sources: _messages[index].sources,
        isLoading: _messages[index].isLoading,
      );
      notifyListeners();
    }
  }
}