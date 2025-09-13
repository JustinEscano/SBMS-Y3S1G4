import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/llm_service.dart';
import '../Models/chat_message.dart';
import '../Providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const ChatScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late LLMService _llmService;

  @override
  void initState() {
    super.initState();
    _llmService = LLMService(
      baseUrl: 'http://10.0.2.2:8000', // Adjust if needed to match backend
      accessToken: widget.accessToken,
    );
    _loadConversationHistory();
  }

  Future<void> _loadConversationHistory() async {
    try {
      final conversations = await _llmService.getConversationHistory();
      if (conversations.isNotEmpty) {
        final recentConversation = conversations.first;
        Provider.of<ChatProvider>(context, listen: false)
            .setConversationId(recentConversation['id']);
        // Optionally load messages from the conversation if your API supports it
      }
    } catch (e) {
      print('Error loading conversation history: $e');
      Provider.of<ChatProvider>(context, listen: false)
          .setError('Failed to load conversation history: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // Create user message
    final userMessage = ChatMessage(
      id: _llmService.generateMessageId(),
      content: message,
      type: 'user',
      timestamp: DateTime.now(),
      conversationId: chatProvider.currentConversationId,
    );

    // Add user message to provider
    chatProvider.addMessage(userMessage);
    chatProvider.setLoading(true);
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _llmService.queryLLM(
        message,
        userId: null, // Add userId if your backend requires it
      );

      // Create assistant message from response
      final assistantMessage = ChatMessage(
        id: _llmService.generateMessageId(),
        content: response['answer'] ?? 'No response received',
        type: 'assistant',
        timestamp: DateTime.parse(response['timestamp'] ?? DateTime.now().toIso8601String()),
        conversationId: chatProvider.currentConversationId,
        sources: response['sources'] != null
            ? List<Source>.from(response['sources'].map((x) => Source.fromJson(x)))
            : null,
      );

      // Update provider with response
      chatProvider.addMessage(assistantMessage);
      chatProvider.setConversationId(response['conversation_id'] ?? chatProvider.currentConversationId);
      chatProvider.setLoading(false);
      _scrollToBottom();
    } catch (e) {
      chatProvider.setLoading(false);
      chatProvider.setError(e.toString());
      chatProvider.addMessage(ChatMessage(
        id: _llmService.generateMessageId(),
        content: 'Sorry, I encountered an error: $e',
        type: 'assistant',
        timestamp: DateTime.now(),
        conversationId: chatProvider.currentConversationId,
      ));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearConversation() {
    Provider.of<ChatProvider>(context, listen: false).clearConversation();
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.type == 'assistant')
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: message.type == 'user' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.type == 'user'
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color: message.type == 'user' ? Theme.of(context).primaryColor : Colors.black87,
                        ),
                      ),
                      if (message.sources != null && message.sources!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sources:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        ...message.sources!.take(3).map((source) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            source.pageContent,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        if (message.sources!.length > 3)
                          Text(
                            '...and ${message.sources!.length - 3} more sources',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (message.type == 'user')
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ORB Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearConversation,
            tooltip: 'Clear Conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          if (chatProvider.errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[100],
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatProvider.errorMessage,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      chatProvider.clearError();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < chatProvider.messages.length) {
                  return _buildMessageBubble(chatProvider.messages[index]);
                } else {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              'AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Thinking...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}