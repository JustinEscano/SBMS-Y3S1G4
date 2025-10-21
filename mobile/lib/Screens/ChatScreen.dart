import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../Services/llm_service.dart';
import '../Services/auth_service.dart';
import '../Models/chat_message.dart';
import '../Providers/chat_provider.dart';
import '../Config/api.dart';
import '../Widgets/bottom_navbar.dart';
import 'DashboardScreen.dart';
import 'EnergyAnalyticsScreen.dart';
import 'MaintenanceManagementScreen.dart';
import 'dart:developer' as developer;

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
  bool isRefreshingToken = false;
  bool hasInteracted = false;
  Map<String, dynamic>? _profileData;

  final List<String> suggestions = [
    "daily energy report",
    "weekly energy report",
    "check for maintenance",
    "show anomalies",
    "show billing rates",
    "kpi performance",
    "show me rooms",
  ];

  @override
  void initState() {
    super.initState();
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
    _llmService = LLMService();
    _loadConversationHistory();
    _checkLLMHealth();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profileData = await authService.apiService.fetchProfile();
      if (mounted) {
        setState(() {
          _profileData = profileData;
        });
      }
    } catch (e) {
      developer.log('Error fetching profile: $e', name: 'ChatScreen.Profile');
    }
  }

  String _getProfilePictureUrl(String? picturePath) {
    if (picturePath == null || picturePath.isEmpty) {
      return '';
    }
    if (picturePath.startsWith('http://') || picturePath.startsWith('https://')) {
      return picturePath;
    }
    return ApiConfig.getMediaUrl(picturePath);
  }

  Future<bool> _refreshToken() async {
    setState(() {
      isRefreshingToken = true;
    });
    try {
      final success = await AuthService().refresh();
      if (success) {
        _llmService = LLMService();
        return true;
      }
      Provider.of<ChatProvider>(context, listen: false)
          .setError('Failed to refresh session. Please log in again.');
      return false;
    } catch (e) {
      Provider.of<ChatProvider>(context, listen: false)
          .setError('Error refreshing session: $e');
      return false;
    } finally {
      setState(() {
        isRefreshingToken = false;
      });
    }
  }

  Future<void> _loadConversationHistory() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final conversations = await _llmService.getConversationHistory();
      if (conversations.isNotEmpty) {
        final recentConversation = conversations.first;
        Provider.of<ChatProvider>(context, listen: false)
            .setConversationId(recentConversation['id']);
        setState(() {
          hasInteracted = true;
        });
      }
    } catch (e) {
      Provider.of<ChatProvider>(context, listen: false)
          .setError('Failed to load conversation history: $e');
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      hasInteracted = true;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final userMessage = ChatMessage(
      id: _llmService.generateMessageId(),
      content: message,
      type: 'user',
      timestamp: DateTime.now(),
      conversationId: chatProvider.currentConversationId,
    );

    chatProvider.addMessage(userMessage);
    chatProvider.setLoading(true);
    _messageController.clear();
    _scrollToBottom();

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }

      // Determine query type and route to appropriate endpoint
      final queryType = _llmService.determineQueryType(message);
      String formattedResponse = '';

      // Route to specialized endpoints
      if (queryType == 'maintenance') {
        formattedResponse = await _handleMaintenanceQuery(message);
      } else if (queryType == 'anomalies') {
        formattedResponse = await _handleAnomaliesQuery(message); // ✅ Pass message
      } else if (queryType == 'energy' || queryType == 'summary') {
        formattedResponse = await _handleEnergyQuery(message);
      } else if (queryType == 'billing') {
        formattedResponse = await _handleBillingQuery(message); // ✅ Pass message
      } else if (queryType == 'kpi') {
        formattedResponse = await _handleKpiQuery(message); // ✅ Pass message
      } else if (queryType == 'utilization') {
        formattedResponse = await _handleRoomsQuery(message);
      } else {
        // General query
        final response = await _llmService.queryLLM(message, userId: null);
        formattedResponse = response['answer'] ?? 'No response received';
      }

      final assistantMessage = ChatMessage(
        id: _llmService.generateMessageId(),
        content: formattedResponse,
        type: 'assistant',
        timestamp: DateTime.now(),
        conversationId: chatProvider.currentConversationId,
      );

      chatProvider.addMessage(assistantMessage);
      chatProvider.setLoading(false);
      _scrollToBottom();

      // Save to MongoDB
      await _llmService.saveChatToMongoDB(
        userMessage: message,
        assistantResponse: formattedResponse,
        queryType: queryType,
        userRole: _getUserRole(queryType),
      );
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

  String _getUserRole(String queryType) {
    switch (queryType) {
      case 'maintenance':
      case 'anomalies':
      case 'kpi':
        return 'facility_manager';
      case 'energy':
      case 'billing':
        return 'energy_analyst';
      default:
        return 'viewer';
    }
  }

  Future<String> _handleMaintenanceQuery(String query) async {
    final data = await _llmService.predictMaintenance(query: query);
    final lines = <String>[];
    final suggestions = data['maintenance_suggestions'] as List? ?? [];

    lines.add('🔧 MAINTENANCE REQUESTS\n');

    if (suggestions.isNotEmpty) {
      final pending = suggestions.where((s) => s['status']?.toLowerCase() == 'pending').toList();
      final inProgress = suggestions.where((s) => s['status']?.toLowerCase() == 'in_progress').toList();

      if (pending.isNotEmpty) {
        lines.add('🔴 PENDING REQUESTS (${pending.length}):\n');
        for (var i = 0; i < pending.length && i < 5; i++) {
          final s = pending[i];
          final urgencyEmoji = s['urgency'] == 'Critical' ? '🔴' : s['urgency'] == 'High' ? '🟠' : '🟡';
          lines.add('${i + 1}. $urgencyEmoji ${s['equipment'] ?? 'Equipment'} - ${s['room'] ?? 'Unknown'}');
          lines.add('   📝 ${s['issue'] ?? 'Maintenance needed'}');
          lines.add('   🔧 ${s['action'] ?? 'Inspect and maintain'}');
          lines.add('   📅 ${s['timeline'] ?? 'TBD'}\n');
        }
      }

      if (inProgress.isNotEmpty) {
        lines.add('\n🟡 IN PROGRESS (${inProgress.length})\n');
      }
    } else {
      lines.add('\n✅ No maintenance issues detected.');
    }

    if (data['llm_analysis'] != null) {
      lines.add('\n\n🤖 AI RECOMMENDATIONS\n');
      lines.add(data['llm_analysis']);
    }

    return lines.join('\n');
  }

  Future<String> _handleAnomaliesQuery(String query) async {
    final data = await _llmService.detectAnomalies(query: query); // ✅ Pass full query for personality
    return data['answer'] ?? 'No anomalies detected.';
  }

  Future<String> _handleEnergyQuery(String query) async {
    final period = _llmService.determineReportPeriod(query);
    final data = await _llmService.getEnergyReport(period, query: query); // ✅ Pass full query for personality
    final lines = <String>[];

    lines.add('⚡ ${period.toUpperCase()} ENERGY REPORT\n');

    if (data['energy_data'] != null) {
      final ed = data['energy_data'];
      lines.add('📊 Energy Statistics:');
      lines.add('• Total: ${ed['total_kwh']?.toStringAsFixed(2) ?? '0'} kWh');
      lines.add('• Average: ${ed['average_kwh']?.toStringAsFixed(2) ?? '0'} kWh');
      lines.add('• Peak: ${ed['peak_kwh']?.toStringAsFixed(2) ?? '0'} kWh');
      lines.add('• Data Points: ${ed['data_points'] ?? 0}\n');
    }

    if (data['answer'] != null) {
      lines.add('\n🤖 AI ANALYSIS\n');
      lines.add(data['answer']);
    }

    return lines.join('\n');
  }

  Future<String> _handleBillingQuery(String query) async {
    final data = await _llmService.getBillingRates(query: query); // ✅ Pass full query for personality
    final lines = <String>[];

    lines.add('💱 BILLING RATES ANALYSIS\n');

    if (data['billing_data'] != null) {
      final bd = data['billing_data'];
      lines.add('📊 Rate Summary:');
      lines.add('• Total Configurations: ${bd['total_rates']}');
      lines.add('• Average Rate: ${bd['average_rate']?.toStringAsFixed(4) ?? '0'} ${bd['currency']}/kWh');
      lines.add('• Lowest: ${bd['min_rate']?.toStringAsFixed(4) ?? '0'} ${bd['currency']}/kWh');
      lines.add('• Highest: ${bd['max_rate']?.toStringAsFixed(4) ?? '0'} ${bd['currency']}/kWh\n');
    }

    if (data['answer'] != null) {
      lines.add('\n🤖 AI ANALYSIS\n');
      lines.add(data['answer']);
    }

    return lines.join('\n');
  }

  Future<String> _handleKpiQuery(String query) async {
    final data = await _llmService.getKpiHeartbeat(query: query); // ✅ Pass full query for personality
    final lines = <String>[];

    lines.add('📊 SYSTEM HEALTH KPI ANALYSIS\n');

    if (data['kpi_data'] != null) {
      final kpi = data['kpi_data'];
      lines.add('🔍 Performance Metrics:');
      lines.add('• Success Rate: ${kpi['success_rate']?.toStringAsFixed(2) ?? '0'}%');
      lines.add('• WiFi Signal: ${kpi['wifi_signal']?.toStringAsFixed(1) ?? '0'} dBm');
      lines.add('• Avg Uptime: ${kpi['uptime_hours']?.toStringAsFixed(1) ?? '0'} hours');
      lines.add('• Failed Readings: ${kpi['total_failed_readings']}\n');
    }

    if (data['answer'] != null) {
      lines.add('\n🤖 AI ANALYSIS\n');
      lines.add(data['answer']);
    }

    return lines.join('\n');
  }

  Future<String> _handleRoomsQuery(String userQuery) async {
    final data = await _llmService.getRoomsList(query: userQuery);
    return data['summary_text'] ?? 'No rooms found.';
  }

  Future<void> _checkLLMHealth() async {
    try {
      final health = await _llmService.getHealth();
      print('LLM Health: ${health['status']}');
    } catch (e) {
      Provider.of<ChatProvider>(context, listen: false)
          .setError('LLM Health check failed: $e');
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
    setState(() {
      hasInteracted = false;
    });
  }

  Widget _buildMessageBubble(ChatMessage message) {
    ImageProvider? profileImage;
    bool hasImage = false;
    String profilePictureUrl = _getProfilePictureUrl(_profileData?['profile']['profile_picture']);
    if (profilePictureUrl.isNotEmpty) {
      profileImage = NetworkImage(profilePictureUrl);
      hasImage = true;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
        message.type == 'user' ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (message.type == 'assistant')
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Image.asset(
                  'assets/icons/Orb Hovered.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: message.type == 'user'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121822),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFFFFF),
                          fontSize: 14,
                        ),
                      ),
                      if (message.sources != null && message.sources!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sources:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF676767),
                          ),
                        ),
                        ...message.sources!.take(3).map((source) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            source.pageContent,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF676767),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        if (message.sources!.length > 3)
                          Text(
                            '...and ${message.sources!.length - 3} more sources',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF676767),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF676767),
                  ),
                ),
              ],
            ),
          ),
          if (message.type == 'user')
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF121822),
                backgroundImage: profileImage,
                child: !hasImage
                    ? const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                )
                    : null,
                onBackgroundImageError: hasImage
                    ? (error, stackTrace) {
                  developer.log(
                    'Error loading profile picture: $error',
                    name: 'ChatScreen.Image',
                    error: error,
                    stackTrace: stackTrace,
                  );
                }
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(
            suggestion,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFFFFF),
              fontSize: 12,
            ),
          ),
          backgroundColor: const Color(0xFF121822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onPressed: () {
            _sendMessage(suggestion);
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          hasInteracted ? 'Orb Control by Orbit' : 'ORB Chat',
          style: GoogleFonts.urbanist(
            color: const Color(0xFFFFFFFF),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: isRefreshingToken ? null : _clearConversation,
            tooltip: 'Clear Conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          if (chatProvider.errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF121822),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatProvider.errorMessage,
                      style: GoogleFonts.inter(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      chatProvider.clearError();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: isRefreshingToken
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF184BFB)))
                : chatProvider.messages.isEmpty && !hasInteracted
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hello, I am Orb!',
                    style: GoogleFonts.urbanist(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How can I help you?',
                    style: GoogleFonts.urbanist(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSuggestions(),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < chatProvider.messages.length) {
                  return _buildMessageBubble(chatProvider.messages[index]);
                } else {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            backgroundColor: Colors.transparent,
                            child: Image.asset(
                              'assets/icons/Orb Hovered.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121822),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF184BFB),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Thinking...',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF676767),
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
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
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask Orb...',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF676767),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF232627),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF676767),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF676767),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF676767),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => isRefreshingToken ? null : _sendMessage(_messageController.text.trim()),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: Color(0xFF4D6BFE),
                  ),
                  onPressed: isRefreshingToken ? null : () => _sendMessage(_messageController.text.trim()),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        onMenuSelection: (value) {
          switch (value) {
            case 'dashboard':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    accessToken: AuthService().accessToken ?? widget.accessToken,
                  ),
                ),
              );
              break;
            case 'analytics':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EnergyAnalyticsScreen(
                    accessToken: AuthService().accessToken ?? widget.accessToken,
                    refreshToken: AuthService().refreshToken ?? widget.refreshToken,
                  ),
                ),
              );
              break;
            case 'maintenance_requests':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MaintenanceManagementScreen(
                    accessToken: AuthService().accessToken ?? widget.accessToken,
                    refreshToken: AuthService().refreshToken ?? widget.refreshToken,
                    userRole: 'client',
                  ),
                ),
              );
              break;
            case 'orb_chat':
              break;
            default:
              break;
          }
        },
        currentScreen: 'orb_chat',
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