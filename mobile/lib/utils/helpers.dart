import 'package:flutter/material.dart';

String getEquipmentName(String? equipmentId, List<dynamic> equipment) {
  if (equipmentId == null) return 'Unknown Equipment';
  final eq = equipment.firstWhere(
        (e) => e['id'].toString() == equipmentId.toString(),
    orElse: () => null,
  );
  return eq != null ? eq['name'] : 'Unknown Equipment';
}

String getStatusLabel(String? status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'in_progress':
      return 'In Progress';
    case 'resolved':
      return 'Resolved';
    default:
      return status ?? 'Unknown';
  }
}

String getPriorityLabel(String? priority) {
  switch (priority) {
    case 'low':
      return 'Low';
    case 'medium':
      return 'Medium';
    case 'high':
      return 'High';
    case 'critical':
      return 'Critical';
    default:
      return priority ?? 'Unknown';
  }
}

String getRoomName(String? roomId, List<dynamic> rooms) {
  if (roomId == null) return 'Unassigned';
  final room = rooms.firstWhere(
        (r) => r['id'].toString() == roomId.toString(),
    orElse: () => null,
  );
  return room != null ? room['name'] : 'Unknown Room';
}

String formatDateTime(String? dateTimeString) {
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

Color getStatusColor(String? status) {
  switch (status?.toLowerCase()) {
    case 'online':
      return Colors.green;
    case 'offline':
      return Colors.red;
    case 'maintenance':
      return Colors.orange;
    case 'error':
      return Colors.redAccent;
    case 'detected':
      return Colors.amber;
    case 'not_detected':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

Color getSystemStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'operational':
    case 'optimal':
    case 'secure':
    case 'normal':
      return Colors.green;
    case 'alert':
    case 'attention':
      return Colors.red;
    case 'offline':
      return Colors.grey;
    default:
      return Colors.orange;
  }
}