import 'package:flutter/material.dart';

class NotificationWidgets {
  // Empty State Widget
  static Widget buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No notifications found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Notification List Widget
  static Widget buildNotificationList({
    required List<dynamic> notifications,
    required bool hasMore,
    required bool isLoadingMore,
    required Future<void> Function({bool loadMore}) onLoadMore,
    required Function(String) onMarkRead,
    required Function(String) onDelete,
    required Function(Map<String, dynamic>) onTapNotification,
    required String Function(String?) formatDateTime,
    required bool Function(Map<String, dynamic>) hasMaintenanceRequest,
    required IconData Function(String?) getNotificationIcon,
    required Color Function(String?) getNotificationColor,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasMore && index == notifications.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton(
              onPressed: isLoadingMore ? null : () => onLoadMore(loadMore: true),
              child: isLoadingMore
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Load More'),
            ),
          );
        }
        final notification = notifications[index];
        final hasMaintenance = hasMaintenanceRequest(notification);

        return Card(
          color: notification['read'] ? Color(0xFF1F1E23) : Colors.grey[300],
          elevation: notification['read'] ? 1 : 3,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              getNotificationIcon(notification['type']),
              color: getNotificationColor(notification['type']),
            ),
            title: Text(
              notification['title'] ?? 'No Title',
              style: TextStyle(
                fontWeight: notification['read'] ? FontWeight.normal : FontWeight.bold,
                color: notification['read'] ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['message'] ?? 'No Message',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: notification['read'] ? Colors.white70 : Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  'Received: ${formatDateTime(notification['created_at'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (hasMaintenance) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'View Maintenance Request',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!notification['read'])
                  IconButton(
                    icon: const Icon(Icons.mark_email_read, color: Colors.blue),
                    onPressed: () => onMarkRead(notification['id']),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => onDelete(notification['id']),
                ),
              ],
            ),
            onTap: () => onTapNotification(notification),
          ),
        );
      },
    );
  }

  // Notification Details Widget
  static Widget buildNotificationDetails({
    required Map<String, dynamic> notification,
    required Function(BuildContext) onMarkRead,
    required Function(BuildContext) onDelete,
    required Function(String?) onNavigateToMaintenance,
    required String? maintenanceRequestId,
    required bool hasMaintenance,
    required String Function(String?) formatDateTime,
    required IconData Function(String?) getNotificationIcon,
    required Color Function(String?) getNotificationColor,
    required String Function(String?) getNotificationTypeLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                getNotificationIcon(notification['type']),
                color: getNotificationColor(notification['type']),
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notification['title'] ?? 'No Title',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white
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
              color: getNotificationColor(notification['type']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              getNotificationTypeLabel(notification['type']),
              style: TextStyle(
                color: getNotificationColor(notification['type']),
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
              color: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notification['message'] ?? 'No Message',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Text(
            'Received: ${formatDateTime(notification['created_at'])}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (hasMaintenance) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.build,
                        color: Colors.blue[700],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Related Maintenance Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    maintenanceRequestId != null
                        ? 'This notification is related to a maintenance request. You can view the full details and respond to it.'
                        : 'This notification is related to a maintenance request, but the specific request ID could not be extracted. You can view recent maintenance requests.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => onNavigateToMaintenance(maintenanceRequestId),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(maintenanceRequestId != null
                          ? 'View Maintenance Request'
                          : 'View Maintenance Requests'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (maintenanceRequestId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Request ID: $maintenanceRequestId',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Note: Could not extract specific request ID from notification message',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}