  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import '../utils/helpers.dart';

  class DashboardScreenWidgets {
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
        color: const Color(0xFF121822),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        color: Color.alphaBlend(
                          statusColor.withOpacity(0.4),
                          const Color(0xFF2A2A2E),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withOpacity(0.8)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.urbanist(
                          color: Colors.white,
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
                  style: GoogleFonts.urbanist(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    static Widget buildOverviewCard({
      required String title,
      required String value,
      required IconData icon,
      required Color color,
      VoidCallback? onTap,
    }) {
      return Card(
        color: const Color(0xFF121822),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  style: GoogleFonts.urbanist(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    static Widget buildActionCard({
      required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Card(
        color: const Color(0xFF121822),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  style: GoogleFonts.urbanist(
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

    static Widget buildSensorCard(Map<String, dynamic> sensorData) {
      return Card(
        color: const Color(0xFF121822),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Device: ${sensorData['device_id'] ?? 'N/A'}',
                          style: GoogleFonts.urbanist(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        getStatusColor(sensorData['status']).withOpacity(0.4),
                        const Color(0xFF2A2A2E),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: getStatusColor(sensorData['status'])
                              .withOpacity(0.8)),
                    ),
                    child: Text(
                      sensorData['status']?.toUpperCase() ?? 'UNKNOWN',
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- Power & Energy -------------------------------------------------
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

              // ---- Voltage & Current -----------------------------------------------
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

              // ---- Temperature & Humidity -----------------------------------------
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

              // ---- Motion ---------------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: _buildSensorValue(
                      'Motion',
                      sensorData['motion_detected'] == true
                          ? 'Detected'
                          : 'Not Detected',
                      Icons.motion_photos_on,
                      sensorData['motion_detected'] == true
                          ? Colors.orange
                          : Colors.grey,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 8),

              // ---- Last Update ----------------------------------------------------
              Text(
                'Last Update: ${formatDateTime(sensorData['recorded_at'])}',
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    static Widget buildManagementTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Card(
        color: const Color(0xFF121822),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.urbanist(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          onTap: onTap,
        ),
      );
    }

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
        backgroundColor: const Color(0xFF121822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '$systemType System Details',
          style: GoogleFonts.urbanist(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
            child: Text(
              'Close',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onManage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF184BFB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Manage',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    static Widget buildErrorBanner(String errorMessage) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage,
                style: GoogleFonts.urbanist(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    static Widget buildEmptyState({
      required VoidCallback onAddRooms,
      required VoidCallback onAddEquipment,
    }) {
      return Card(
        color: const Color(0xFF121822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                'Welcome to Smart Building!',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Get started by adding rooms and equipment to your building.',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onAddRooms,
                    icon: const Icon(Icons.room, color: Colors.white),
                    label: Text(
                      'Add Rooms',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF184BFB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: onAddEquipment,
                    icon: const Icon(Icons.devices, color: Colors.white),
                    label: Text(
                      'Add Equipment',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF184BFB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    static Widget buildLiveSensorDataHeader() {
      return Row(
        children: [
          Icon(Icons.sensors, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            'Live ESP32 Sensor Data',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Colors.orange.withOpacity(0.4),
                const Color(0xFF2A2A2E),
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.8)),
            ),
            child: Text(
              'LIVE',
              style: GoogleFonts.urbanist(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    static Widget buildManagementCenterBottomSheet({
      required VoidCallback onRoomManagement,
      required VoidCallback onEquipmentManagement,
      required VoidCallback onMaintenanceManagement,
    }) {
      return Container(
        color: const Color(0xFF121822),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.settings, color: const Color(0xFF184BFB)),
                const SizedBox(width: 12),
                Text(
                  'Management Center',
                  style: GoogleFonts.urbanist(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    static Widget _buildSensorValue(String label, String value, IconData icon, Color color) {
      return Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 10,
              color: Colors.white70,
            ),
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
                Text(
                  'Recent Requests:',
                  style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                ...maintenanceRequests.take(3).map((request) => Card(
                  color: const Color(0xFF121822),
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getEquipmentName(request['equipment']?.toString(), equipment),
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          request['issue'] ?? 'No description',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.urbanist(color: Colors.white70),
                        ),
                        Text(
                          'Status: ${getStatusLabel(request['status'])}',
                          style: GoogleFonts.urbanist(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )),
              ] else ...[
                Text(
                  'No maintenance requests found.',
                  style: GoogleFonts.urbanist(color: Colors.white70),
                ),
              ],
            ],
          );
        default:
          return Text(
            'No details available for $systemType',
            style: GoogleFonts.urbanist(color: Colors.white70),
          );
      }
    }

    static Widget _buildDetailRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.urbanist(color: Colors.white70),
            ),
          ],
        ),
      );
    }
  }