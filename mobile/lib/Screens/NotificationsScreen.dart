import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Config/api.dart';
import '../Services/auth_service.dart';
import '../Widgets/NotificationWidgets.dart';
import 'MaintenanceDetailsScreen.dart';

class NotificationsScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const NotificationsScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  List<dynamic> users = [];
  List<dynamic> equipment = [];
  List<Map<String, String>> statusOptions = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String errorMessage = '';
  int currentPage = 1;
  int? totalCount;
  bool hasMore = true;
  final int pageSize = 10;

  @override
  void initState() {
    super.initState();
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadNotifications(),
      _loadUsers(),
      _loadEquipment(),
      _loadStatusOptions(),
    ]);
  }

  Future<void> _loadUsers() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        return;
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.users),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          users = data is List ? data : [];
        });
      }
    } catch (e) {
      // Silently fail for users - not critical for notifications
    }
  }

  Future<void> _loadEquipment() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        return;
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.equipment),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          equipment = data is List ? data : [];
        });
      }
    } catch (e) {
      // Silently fail for equipment - not critical for notifications
    }
  }

  Future<void> _loadStatusOptions() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        return;
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/esp32/field-options/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          statusOptions = (data['maintenance_status_options'] as List?)
              ?.map((option) => Map<String, String>.from(option))
              .toList() ?? [];
        });
      }
    } catch (e) {
      setState(() {
        statusOptions = [
          {'value': 'pending', 'label': 'Pending'},
          {'value': 'in_progress', 'label': 'In Progress'},
          {'value': 'resolved', 'label': 'Resolved'},
        ];
      });
    }
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (loadMore && (!hasMore || isLoadingMore)) return;

    setState(() {
      if (!loadMore) {
        isLoading = true;
        notifications = [];
        currentPage = 1;
        totalCount = null;
        hasMore = true;
      } else {
        isLoadingMore = true;
      }
      errorMessage = '';
    });

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.notification(page: currentPage, pageSize: pageSize)),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _loadNotifications(loadMore: loadMore);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (response.statusCode != 200) {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      setState(() {
        totalCount = data['count'] ?? data.length;
        notifications = loadMore ? [...notifications, ...data['results']] : data['results'];
        hasMore = data['next'] != null && notifications.length < totalCount!;
        if (loadMore) {
          currentPage++;
        }
        isLoading = false;
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final success = await AuthService().refresh();
      return success;
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to refresh session: $e';
      });
      return false;
    }
  }

  Future<void> _markAllRead() async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.notificationMarkAllRead),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _markAllRead();
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (response.statusCode != 200) {
        throw Exception('Failed to mark notifications as read: ${response.statusCode}');
      }

      await _loadNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _markNotificationRead(String id) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.notificationMarkRead(id)),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _markNotificationRead(id);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read: ${response.statusCode}');
      }

      await _loadNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.delete(
        Uri.parse(ApiConfig.notificationDelete(id)),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _deleteNotification(id);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (response.statusCode != 200) {
        throw Exception('Failed to delete notification: ${response.statusCode}');
      }

      setState(() {
        notifications = notifications.where((n) => n['id'] != id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _navigateToMaintenanceRequest(String? maintenanceRequestId) async {
    if (maintenanceRequestId == null || maintenanceRequestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No maintenance request associated with this notification')),
      );
      return;
    }

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.maintenanceRequest}$maintenanceRequestId/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _navigateToMaintenanceRequest(maintenanceRequestId);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintenance request not found')),
        );
        return;
      } else if (response.statusCode != 200) {
        throw Exception('Failed to load maintenance request: ${response.statusCode}');
      }

      final maintenanceRequest = json.decode(response.body);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MaintenanceDetailsScreen(
            accessToken: widget.accessToken,
            refreshToken: widget.refreshToken,
            userRole: 'client',
            users: users,
            equipment: equipment,
            statusOptions: statusOptions,
            request: maintenanceRequest,
            onSave: () {
              _loadNotifications();
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error navigating to maintenance request: $e')),
      );
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  bool _hasMaintenanceRequest(Map<String, dynamic> notification) {
    final type = notification['type']?.toString() ?? '';
    final message = notification['message']?.toString() ?? '';
    final hasMaintenance = type.contains('maintenance') ||
        message.contains('request #') ||
        message.contains('Maintenance Request') ||
        message.contains('maintenance request');

    print('Notification Debug:');
    print('  Type: $type');
    print('  Message: $message');
    print('  Has Maintenance: $hasMaintenance');

    return hasMaintenance;
  }

  String? _getMaintenanceRequestId(Map<String, dynamic> notification) {
    final message = notification['message']?.toString() ?? '';

    RegExp regex1 = RegExp(r'request #(\d+)');
    var match1 = regex1.firstMatch(message);
    if (match1 != null) {
      print('Maintenance Request ID Debug (Pattern 1 - number):');
      print('  Message: $message');
      print('  Extracted ID: ${match1.group(1)}');
      return match1.group(1);
    }

    RegExp regex2 = RegExp(r'request #([a-f0-9-]{36})');
    var match2 = regex2.firstMatch(message);
    if (match2 != null) {
      print('Maintenance Request ID Debug (Pattern 2 - UUID):');
      print('  Message: $message');
      print('  Extracted ID: ${match2.group(1)}');
      return match2.group(1);
    }

    RegExp regex3 = RegExp(r'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})');
    var match3 = regex3.firstMatch(message);
    if (match3 != null) {
      print('Maintenance Request ID Debug (Pattern 3 - any UUID):');
      print('  Message: $message');
      print('  Extracted ID: ${match3.group(1)}');
      return match3.group(1);
    }

    print('Maintenance Request ID Debug (No match):');
    print('  Message: $message');
    print('  No ID found');

    return null;
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'maintenance_created':
      case 'maintenance_updated':
      case 'maintenance_assigned':
      case 'maintenance_responded':
      case 'maintenance_attachment':
        return Icons.build;
      case 'predictive_alert':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'maintenance_created':
      case 'maintenance_updated':
      case 'maintenance_assigned':
      case 'maintenance_responded':
      case 'maintenance_attachment':
        return Colors.indigo;
      case 'predictive_alert':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getNotificationTypeLabel(String? type) {
    switch (type) {
      case 'maintenance_created':
        return 'Maintenance Created';
      case 'maintenance_updated':
        return 'Maintenance Updated';
      case 'maintenance_assigned':
        return 'Maintenance Assigned';
      case 'maintenance_responded':
        return 'Maintenance Responded';
      case 'maintenance_attachment':
        return 'Maintenance Attachment';
      case 'predictive_alert':
        return 'System Alert';
      default:
        return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1E23),
        title: Text('Notifications',
          style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (notifications.any((n) => n['read'] == false))
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark All Read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => _loadNotifications(),
        child: notifications.isEmpty
            ? NotificationWidgets.buildEmptyState()
            : NotificationWidgets.buildNotificationList(
          notifications: notifications,
          hasMore: hasMore,
          isLoadingMore: isLoadingMore,
          onLoadMore: _loadNotifications,
          onMarkRead: _markNotificationRead,
          onDelete: _deleteNotification,
          onTapNotification: (notification) async {
            if (!notification['read']) {
              await _markNotificationRead(notification['id']);
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationDetailsScreen(
                  notification: notification,
                  accessToken: widget.accessToken,
                  refreshToken: widget.refreshToken,
                  users: users,
                  equipment: equipment,
                  statusOptions: statusOptions,
                  onNavigateToMaintenance: _navigateToMaintenanceRequest,
                ),
              ),
            );
            if (result == true) {
              await _loadNotifications();
            }
          },
          formatDateTime: _formatDateTime,
          hasMaintenanceRequest: _hasMaintenanceRequest,
          getNotificationIcon: _getNotificationIcon,
          getNotificationColor: _getNotificationColor,
        ),
      ),
    );
  }
}

class NotificationDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String accessToken;
  final String refreshToken;
  final List<dynamic> users;
  final List<dynamic> equipment;
  final List<Map<String, String>> statusOptions;
  final Function(String?) onNavigateToMaintenance;

  const NotificationDetailsScreen({
    super.key,
    required this.notification,
    required this.accessToken,
    required this.refreshToken,
    required this.users,
    required this.equipment,
    required this.statusOptions,
    required this.onNavigateToMaintenance,
  });

  Future<void> _markNotificationRead(BuildContext context) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.notificationMarkRead(notification['id'])),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 401) {
        if (await AuthService().refresh()) {
          return _markNotificationRead(context);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read: ${response.statusCode}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteNotification(BuildContext context) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.delete(
        Uri.parse(ApiConfig.notificationDelete(notification['id'])),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 401) {
        if (await AuthService().refresh()) {
          return _deleteNotification(context);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else if (response.statusCode != 200) {
        throw Exception('Failed to delete notification: ${response.statusCode}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.toLocal()}'.split('.')[0];
    } catch (e) {
      return 'Unknown';
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'maintenance_created':
      case 'maintenance_updated':
      case 'maintenance_assigned':
      case 'maintenance_responded':
      case 'maintenance_attachment':
        return Icons.build;
      case 'predictive_alert':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'maintenance_created':
      case 'maintenance_updated':
      case 'maintenance_assigned':
      case 'maintenance_responded':
      case 'maintenance_attachment':
        return Colors.indigo;
      case 'predictive_alert':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getNotificationTypeLabel(String? type) {
    switch (type) {
      case 'maintenance_created':
        return 'Maintenance Created';
      case 'maintenance_updated':
        return 'Maintenance Updated';
      case 'maintenance_assigned':
        return 'Maintenance Assigned';
      case 'maintenance_responded':
        return 'Maintenance Responded';
      case 'maintenance_attachment':
        return 'Maintenance Attachment';
      case 'predictive_alert':
        return 'System Alert';
      default:
        return 'Notification';
    }
  }

  bool _hasMaintenanceRequest() {
    final type = notification['type']?.toString() ?? '';
    final message = notification['message']?.toString() ?? '';
    final hasMaintenance = type.contains('maintenance') ||
        message.contains('request #') ||
        message.contains('Maintenance Request') ||
        message.contains('maintenance request');

    print('NotificationDetailsScreen Debug:');
    print('  Type: $type');
    print('  Message: $message');
    print('  Has Maintenance: $hasMaintenance');

    return hasMaintenance;
  }

  String? _getMaintenanceRequestId() {
    final message = notification['message']?.toString() ?? '';

    RegExp regex1 = RegExp(r'request #(\d+)');
    var match1 = regex1.firstMatch(message);
    if (match1 != null) {
      print('NotificationDetailsScreen Maintenance Request ID Debug (Pattern 1 - number):');
      print('  Message: $message');
      print('  Extracted ID: ${match1.group(1)}');
      return match1.group(1);
    }

    RegExp regex2 = RegExp(r'request #([a-f0-9-]{36})');
    var match2 = regex2.firstMatch(message);
    if (match2 != null) {
      print('NotificationDetailsScreen Maintenance Request ID Debug (Pattern 2 - UUID):');
      print('  Message: $message');
      print('  Extracted ID: ${match2.group(1)}');
      return match2.group(1);
    }

    RegExp regex3 = RegExp(r'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})');
    var match3 = regex3.firstMatch(message);
    if (match3 != null) {
      print('NotificationDetailsScreen Maintenance Request ID Debug (Pattern 3 - any UUID):');
      print('  Message: $message');
      print('  Extracted ID: ${match3.group(1)}');
      return match3.group(1);
    }

    print('NotificationDetailsScreen Maintenance Request ID Debug (No match):');
    print('  Message: $message');
    print('  No ID found');

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasMaintenance = _hasMaintenanceRequest();
    final maintenanceRequestId = _getMaintenanceRequestId();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(notification['title'] ?? 'Notification Details'),
        actions: [
          if (!notification['read'])
            IconButton(
              icon: const Icon(Icons.mark_email_read, color: Colors.white),
              onPressed: () => _markNotificationRead(context),
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () => _deleteNotification(context),
          ),
        ],
      ),
      body: NotificationWidgets.buildNotificationDetails(
        notification: notification,
        onMarkRead: _markNotificationRead,
        onDelete: _deleteNotification,
        onNavigateToMaintenance: (id) async {
          await onNavigateToMaintenance(id);
          Navigator.pop(context);
        },
        maintenanceRequestId: maintenanceRequestId,
        hasMaintenance: hasMaintenance,
        formatDateTime: _formatDateTime,
        getNotificationIcon: _getNotificationIcon,
        getNotificationColor: _getNotificationColor,
        getNotificationTypeLabel: _getNotificationTypeLabel,
      ),
    );
  }
}