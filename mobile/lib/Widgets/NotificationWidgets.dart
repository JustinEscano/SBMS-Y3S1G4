import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationWidgets {
  // Empty State Widget
  static Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.white70,
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: GoogleFonts.urbanist(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You’re all caught up! Check back later.',
            style: GoogleFonts.urbanist(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
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
    required String Function(String?) getNotificationTypeLabel,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF184BFB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoadingMore
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                'Load More',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        final notification = notifications[index];
        final hasMaintenance = hasMaintenanceRequest(notification);

        return Card(
          color: notification['read']
              ? const Color(0xFF121822)
              : const Color(0xFF1F1E23),
          elevation: notification['read'] ? 2 : 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: notification['read']
                  ? Colors.white.withOpacity(0.2)
                  : const Color(0xFF184BFB).withOpacity(0.3),
            ),
          ),
          child: InkWell(
            onTap: () => onTapNotification(notification),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor:
                    getNotificationColor(notification['type']).withOpacity(0.2),
                    child: Icon(
                      getNotificationIcon(notification['type']),
                      color: getNotificationColor(notification['type']),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['title'] ?? 'No Title',
                          style: GoogleFonts.urbanist(
                            fontSize: 16,
                            fontWeight: notification['read']
                                ? FontWeight.w500
                                : FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification['message'] ?? 'No Message',
                          style: GoogleFonts.urbanist(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              formatDateTime(notification['created_at']),
                              style: GoogleFonts.urbanist(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                            if (hasMaintenance) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF184BFB).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Maintenance',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 10,
                                    color: const Color(0xFF184BFB),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      if (!notification['read'])
                        IconButton(
                          icon: const Icon(
                            Icons.mark_email_read,
                            color: Color(0xFF184BFB),
                            size: 20,
                          ),
                          tooltip: 'Mark as Read',
                          onPressed: () => onMarkRead(notification['id']),
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        tooltip: 'Delete Notification',
                        onPressed: () => onDelete(notification['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Notification Details Widget
  static Widget buildNotificationDetails({
    required BuildContext context,
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
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor:
                    getNotificationColor(notification['type']).withOpacity(0.2),
                    radius: 24,
                    child: Icon(
                      getNotificationIcon(notification['type']),
                      color: getNotificationColor(notification['type']),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['title'] ?? 'No Title',
                          style: GoogleFonts.urbanist(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: getNotificationColor(notification['type'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            getNotificationTypeLabel(notification['type']),
                            style: GoogleFonts.urbanist(
                              fontSize: 12,
                              color: getNotificationColor(notification['type']),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification['read'])
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Unread',
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Message',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121822),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  notification['message'] ?? 'No Message',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Received: ${formatDateTime(notification['created_at'])}',
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              if (hasMaintenance) ...[
                const SizedBox(height: 24),
                Card(
                  color: const Color(0xFF121822),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: const Color(0xFF184BFB).withOpacity(0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.build,
                              color: const Color(0xFF184BFB),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Related Maintenance Request',
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          maintenanceRequestId != null
                              ? 'This notification is linked to a maintenance request. View details to take action.'
                              : 'This notification is related to a maintenance request, but the specific request ID could not be identified.',
                          style: GoogleFonts.urbanist(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => onNavigateToMaintenance(maintenanceRequestId),
                            icon: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                            label: Text(
                              maintenanceRequestId != null
                                  ? 'View Maintenance Request'
                                  : 'View Maintenance Requests',
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF184BFB),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        if (maintenanceRequestId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Request ID: $maintenanceRequestId',
                            style: GoogleFonts.urbanist(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!notification['read'])
                    OutlinedButton.icon(
                      onPressed: () => onMarkRead(context),
                      icon: const Icon(
                        Icons.mark_email_read,
                        color: Color(0xFF184BFB),
                      ),
                      label: Text(
                        'Mark as Read',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          color: const Color(0xFF184BFB),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFF184BFB).withOpacity(0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => onDelete(context),
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    label: Text(
                      'Delete',
                      style: GoogleFonts.urbanist(
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.red.withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}