import 'package:flutter/material.dart';
import '../utils/helpers.dart';

class DashboardScreenWidgets {
  // Welcome Card Widget
  static Widget buildWelcomeCard() {
    return Card(
      color: const Color(0xFF1F1E23),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Welcome to Smart Building',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor and manage your building\'s systems, equipment, and sensors',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // System Card Widget
  static Widget buildSystemCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String status,
    required VoidCallback onTap,
  }) {
    Color statusColor = getSystemStatusColor(status);

    return Card(
      color: const Color(0xFF1F1E23),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 28, color: color),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Overview Card Widget
  static Widget buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      color: const Color(0xFF1F1E23),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Action Card Widget
  static Widget buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1F1E23),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sensor Card Widget (removed light_detection display)
  static Widget buildSensorCard(Map<String, dynamic> sensorData) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getStatusColor(sensorData['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.memory,
                    color: getStatusColor(sensorData['status']),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sensorData['equipment_name'] ?? 'Unknown Device',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Device: ${sensorData['device_id'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getStatusColor(sensorData['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    sensorData['status']?.toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      color: getStatusColor(sensorData['status']),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSensorValue(
                    'Power',
                    '${sensorData['power']?.toStringAsFixed(1) ?? 'N/A'} W',
                    Icons.power,
                    Colors.teal,
                  ),
                ),
                Expanded(
                  child: _buildSensorValue(
                    'Energy',
                    '${sensorData['energy']?.toStringAsFixed(3) ?? 'N/A'} kWh',
                    Icons.energy_savings_leaf,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSensorValue(
                    'Voltage',
                    '${sensorData['voltage']?.toStringAsFixed(1) ?? 'N/A'} V',
                    Icons.electrical_services,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSensorValue(
                    'Current',
                    '${sensorData['current']?.toStringAsFixed(2) ?? 'N/A'} A',
                    Icons.bolt,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSensorValue(
                    'Temperature',
                    '${sensorData['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C',
                    Icons.thermostat,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildSensorValue(
                    'Humidity',
                    '${sensorData['humidity']?.toStringAsFixed(1) ?? 'N/A'}%',
                    Icons.water_drop,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSensorValue(
                    'Motion',
                    sensorData['motion_detected'] == true ? 'Detected' : 'Not Detected',
                    Icons.motion_photos_on,
                    sensorData['motion_detected'] == true ? Colors.orange : Colors.grey,
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last Update: ${formatDateTime(sensorData['created_at'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Management Tile Widget
  static Widget buildManagementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
        onTap: onTap,
      ),
    );
  }

  // System Details Dialog Widget
  static Widget buildSystemDetailsDialog({
    required BuildContext context,
    required String systemType,
    required Map<String, dynamic> hvacData,
    required Map<String, dynamic> securityData,
    required Map<String, dynamic> energyData,
    required List<dynamic> maintenanceRequests,
    required List<dynamic> equipment,
    required VoidCallback onManage,
  }) {
    return AlertDialog(
      title: Text('$systemType System Details'),
      content: SingleChildScrollView(
        child: _buildSystemDetailsContent(
          systemType: systemType,
          hvacData: hvacData,
          securityData: securityData,
          energyData: energyData,
          maintenanceRequests: maintenanceRequests,
          equipment: equipment,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: onManage,
          child: const Text('Manage'),
        ),
      ],
    );
  }

  // Error Banner Widget
  static Widget buildErrorBanner(String errorMessage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Empty State Widget
  static Widget buildEmptyState({
    required VoidCallback onAddRooms,
    required VoidCallback onAddEquipment,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Welcome to Smart Building!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get started by adding rooms and equipment to your building.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onAddRooms,
                  icon: const Icon(Icons.room),
                  label: const Text('Add Rooms'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: onAddEquipment,
                  icon: const Icon(Icons.devices),
                  label: const Text('Add Equipment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Live Sensor Data Header Widget
  static Widget buildLiveSensorDataHeader() {
    return Row(
      children: [
        const Icon(Icons.sensors, color: Colors.orange),
        const SizedBox(width: 8),
        const Text(
          'Live ESP32 Sensor Data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'LIVE',
            style: TextStyle(
              color: Colors.orange[700],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Management Center Bottom Sheet Widget
  static Widget buildManagementCenterBottomSheet({
    required VoidCallback onRoomManagement,
    required VoidCallback onEquipmentManagement,
    required VoidCallback onMaintenanceManagement,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.settings, color: Colors.blue[700]),
              const SizedBox(width: 12),
              const Text(
                'Management Center',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          buildManagementTile(
            icon: Icons.room,
            title: 'Room Management',
            subtitle: 'Add, edit, and manage building rooms',
            color: Colors.blue,
            onTap: onRoomManagement,
          ),
          buildManagementTile(
            icon: Icons.devices,
            title: 'Equipment Management',
            subtitle: 'Add, edit, and manage equipment',
            color: Colors.green,
            onTap: onEquipmentManagement,
          ),
          buildManagementTile(
            icon: Icons.build,
            title: 'Maintenance Management',
            subtitle: 'Create and manage maintenance requests',
            color: Colors.indigo,
            onTap: onMaintenanceManagement,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Notification Badge Widget
  static Widget buildNotificationBadge(int unreadCount) {
    if (unreadCount <= 0) return const SizedBox.shrink();

    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        constraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
        child: Text(
          '$unreadCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Private helper methods
  static Widget _buildSensorValue(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static Widget _buildSystemDetailsContent({
    required String systemType,
    required Map<String, dynamic> hvacData,
    required Map<String, dynamic> securityData,
    required Map<String, dynamic> energyData,
    required List<dynamic> maintenanceRequests,
    required List<dynamic> equipment,
  }) {
    switch (systemType) {
      case 'HVAC':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Average Temperature', '${hvacData['avgTemperature']?.toStringAsFixed(1) ?? 'N/A'}°C'),
            _buildDetailRow('Average Humidity', '${hvacData['avgHumidity']?.toStringAsFixed(1) ?? 'N/A'}%'),
            _buildDetailRow('Active Zones', '${hvacData['activeZones']}/${hvacData['totalZones']}'),
            _buildDetailRow('Energy Efficiency', '${hvacData['energyEfficiency']}%'),
            _buildDetailRow('System Status', hvacData['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
          ],
        );
      case 'Security':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Total Devices', '${securityData['totalDevices']}'),
            _buildDetailRow('Active Devices', '${securityData['activeDevices']}'),
            _buildDetailRow('Motion Detections', '${securityData['motionDetections']}'),
            _buildDetailRow('Alerts Today', '${securityData['alertsToday']}'),
            _buildDetailRow('Last Incident', securityData['lastIncident'] ?? 'None'),
            _buildDetailRow('System Status', securityData['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
          ],
        );
      case 'Energy':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Average Power', '${energyData['avgPower']?.toStringAsFixed(1) ?? 'N/A'} W'),
            _buildDetailRow('Total Energy', '${energyData['totalEnergy']?.toStringAsFixed(3) ?? 'N/A'} kWh'),
            _buildDetailRow('Average Voltage', '${energyData['avgVoltage']?.toStringAsFixed(1) ?? 'N/A'} V'),
            _buildDetailRow('Average Current', '${energyData['avgCurrent']?.toStringAsFixed(2) ?? 'N/A'} A'),
            _buildDetailRow('Active Devices', '${energyData['activeDevices']}/${energyData['totalDevices']}'),
            _buildDetailRow('System Status', energyData['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
          ],
        );
      case 'Maintenance':
        final pendingCount = maintenanceRequests.where((r) => r['status'] == 'pending').length;
        final inProgressCount = maintenanceRequests.where((r) => r['status'] == 'in_progress').length;
        final resolvedCount = maintenanceRequests.where((r) => r['status'] == 'resolved').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Total Requests', '${maintenanceRequests.length}'),
            _buildDetailRow('Pending', '$pendingCount'),
            _buildDetailRow('In Progress', '$inProgressCount'),
            _buildDetailRow('Resolved', '$resolvedCount'),
            const SizedBox(height: 12),
            if (maintenanceRequests.isNotEmpty) ...[
              const Text('Recent Requests:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...maintenanceRequests.take(3).map((request) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getEquipmentName(request['equipment']?.toString(), equipment),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        request['issue'] ?? 'No description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Status: ${getStatusLabel(request['status'])} • Priority: ${getPriorityLabel(request['priority'])}',
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ] else ...[
              const Text('No maintenance requests found.'),
            ],
          ],
        );
      default:
        return Text('No details available for $systemType');
    }
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}