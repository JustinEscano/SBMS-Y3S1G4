import 'package:flutter/material.dart';
import '../utils/helpers.dart';

class SystemDetailsDialog extends StatelessWidget {
  final String systemType;
  final Map<String, dynamic> hvacData;
  final Map<String, dynamic> lightingData;
  final Map<String, dynamic> securityData;
  final Map<String, dynamic> energyData;
  final List<dynamic> maintenanceRequests;
  final List<dynamic> equipment;
  final VoidCallback onManage;

  const SystemDetailsDialog({
    super.key,
    required this.systemType,
    required this.hvacData,
    required this.lightingData,
    required this.securityData,
    required this.energyData,
    required this.maintenanceRequests,
    required this.equipment,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('$systemType System Details'),
      content: SingleChildScrollView(
        child: _buildSystemDetailsContent(context),
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

  Widget _buildSystemDetailsContent(BuildContext context) {
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
      case 'Lighting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Total Devices', '${lightingData['totalDevices']}'),
            _buildDetailRow('Lights Detected', '${lightingData['detectedLights']}/${lightingData['totalDevices']}'),
            _buildDetailRow('Energy Saving', '${lightingData['energySaving']}%'),
            _buildDetailRow('System Status', lightingData['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
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

  Widget _buildDetailRow(String label, String value) {
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