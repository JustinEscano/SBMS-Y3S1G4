import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Config/api.dart';
import '../Services/auth_service.dart';

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
    _loadNotifications();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Notifications'),
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
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none,
                  size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No notifications found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (hasMore && index == notifications.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton(
                  onPressed: isLoadingMore
                      ? null
                      : () => _loadNotifications(loadMore: true),
                  child: isLoadingMore
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                      : const Text('Load More'),
                ),
              );
            }
            final notification = notifications[index];
            return Card(
              color: notification['read']
                  ? Colors.grey[100]
                  : Colors.white,
              elevation: notification['read'] ? 1 : 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  _getNotificationIcon(notification['type']),
                  color: _getNotificationColor(notification['type']),
                ),
                title: Text(
                  notification['title'] ?? 'No Title',
                  style: TextStyle(
                    fontWeight: notification['read']
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['message'] ?? 'No Message',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Received: ${_formatDateTime(notification['created_at'])}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!notification['read'])
                      IconButton(
                        icon: const Icon(Icons.mark_email_read,
                            color: Colors.blue),
                        onPressed: () =>
                            _markNotificationRead(notification['id']),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.red),
                      onPressed: () =>
                          _deleteNotification(notification['id']),
                    ),
                  ],
                ),
                onTap: () async {
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
                      ),
                    ),
                  );
                  if (result == true) {
                    await _loadNotifications();
                  }
                },
              ),
            );
          },
        ),
      ),
    );
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
}

class NotificationDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String accessToken;
  final String refreshToken;

  const NotificationDetailsScreen({
    super.key,
    required this.notification,
    required this.accessToken,
    required this.refreshToken,
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
      Navigator.pop(context, true); // Return true to indicate deletion
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
      return '${dateTime.toLocal()}'.split('.')[0]; // Format as desired
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

  @override
  Widget build(BuildContext context) {
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getNotificationIcon(notification['type']),
                  color: _getNotificationColor(notification['type']),
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notification['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!notification['read'])
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Unread',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getNotificationColor(notification['type']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getNotificationTypeLabel(notification['type']),
                style: TextStyle(
                  color: _getNotificationColor(notification['type']),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Message:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notification['message'] ?? 'No Message',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Received: ${_formatDateTime(notification['created_at'])}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}