import 'package:flutter/material.dart';
import '../utils/helpers.dart';

class SensorCard extends StatelessWidget {
  final Map<String, dynamic> sensorData;

  const SensorCard({super.key, required this.sensorData});

  @override
  Widget build(BuildContext context) {
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
                    'Light Detection',
                    sensorData['light_detection'] == true ? 'Detected' : 'Not Detected',
                    Icons.light_mode,
                    sensorData['light_detection'] == true ? Colors.amber : Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildSensorValue(
                    'Motion',
                    sensorData['motion_detected'] == true ? 'Detected' : 'Not Detected',
                    Icons.motion_photos_on,
                    sensorData['motion_detected'] == true ? Colors.orange : Colors.grey,
                  ),
                ),
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

  Widget _buildSensorValue(String label, String value, IconData icon, Color color) {
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
}