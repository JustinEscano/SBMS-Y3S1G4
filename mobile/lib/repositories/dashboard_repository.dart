import '../Services/api_service.dart';

class DashboardRepository {
  final ApiService _apiService;
  DashboardRepository(this._apiService);
  Future<Map<String, dynamic>> generateHVACData(List<dynamic> latestSensorData) async {
    double avgTemp = 0;
    double avgHumidity = 0;
    int activeZones = 0;
    if (latestSensorData.isNotEmpty) {
      double totalTemp = 0;
      double totalHumidity = 0;
      int validReadings = 0;
      for (var sensor in latestSensorData) {
        if (sensor['temperature'] != null && sensor['humidity'] != null) {
          totalTemp += (sensor['temperature'] as num).toDouble();
          totalHumidity += (sensor['humidity'] as num).toDouble();
          validReadings++;
          if (sensor['status'] == 'online') activeZones++;
        }
      }
      if (validReadings > 0) {
        avgTemp = totalTemp / validReadings;
        avgHumidity = totalHumidity / validReadings;
      }
    }
    return {
      'avgTemperature': avgTemp.isNaN ? 0 : avgTemp,
      'avgHumidity': avgHumidity.isNaN ? 0 : avgHumidity,
      'activeZones': activeZones,
      'totalZones': latestSensorData.length,
      'status': activeZones > 0 ? 'operational' : 'offline',
      'energyEfficiency': activeZones > 0 ? 85 + (activeZones * 2) : 0,
    };
  }
  Future<Map<String, dynamic>> generateLightingData(List<dynamic> equipment, List<dynamic> latestSensorData, List<dynamic> rooms) async {
    int lightingDevices = equipment.where((e) =>
    e['type']?.toLowerCase().contains('light') == true ||
        e['name']?.toLowerCase().contains('light') == true).length;
    int detectedLights = 0;
    if (latestSensorData.isNotEmpty) {
      detectedLights = latestSensorData.where((s) => s['light_detection'] == true).length;
    }
    return {
      'totalDevices': lightingDevices > 0 ? lightingDevices : rooms.length,
      'detectedLights': detectedLights,
      'energySaving': detectedLights > 0 ? 15 : 25,
      'status': detectedLights > 0 ? 'optimal' : 'normal',
    };
  }
  Future<Map<String, dynamic>> generateSecurityData(List<dynamic> equipment, List<dynamic> latestSensorData, List<dynamic> rooms, List<dynamic> alerts) async {
    int securityDevices = equipment.where((e) {
      String? type = e['type'] as String?;
      String? name = e['name'] as String?;
      return (type?.toLowerCase().contains('security') ?? false) ||
          (type?.toLowerCase().contains('camera') ?? false) ||
          (name?.toLowerCase().contains('security') ?? false);
    }).length;
    int activeDevices = equipment.where((e) {
      String? type = e['type'] as String?;
      return ((type?.toLowerCase().contains('security') ?? false) ||
          (type?.toLowerCase().contains('camera') ?? false)) &&
          e['status'] == 'online';
    }).length;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int motionDetections = 0;
    int alertsToday = 0;
    String lastIncident = 'None today';
    String status = 'secure';
    if (alerts.isNotEmpty) {
      final motionAlerts = alerts.where((a) => a['type'] == 'motion').toList();
      motionDetections = motionAlerts.length;
      final todayMotionAlerts = motionAlerts.where((a) {
        final triggeredStr = a['triggered_at'] ?? a['created_at'];
        final triggered = DateTime.tryParse(triggeredStr ?? '');
        return triggered != null && triggered.isAfter(today);
      }).toList();
      alertsToday = todayMotionAlerts.length;
      final activeMotionAlerts = motionAlerts.where((a) => !(a['resolved'] as bool? ?? true)).toList();
      if (activeMotionAlerts.isNotEmpty) {
        status = 'alert';
      }
      if (todayMotionAlerts.isNotEmpty) {
        todayMotionAlerts.sort((a, b) => DateTime.parse(b['triggered_at'] ?? b['created_at']).compareTo(DateTime.parse(a['triggered_at'] ?? a['created_at'])));
        final last = todayMotionAlerts.first;
        final lastTime = DateTime.parse(last['triggered_at'] ?? last['created_at']);
        final diff = now.difference(lastTime);
        if (diff.inHours > 0) {
          lastIncident = '${diff.inHours} hours ago';
        } else if (diff.inMinutes > 0) {
          lastIncident = '${diff.inMinutes} minutes ago';
        } else {
          lastIncident = 'Just now';
        }
      }
    }
    return {
      'totalDevices': securityDevices > 0 ? securityDevices : (rooms.length * 0.5).round(),
      'activeDevices': activeDevices > 0 ? activeDevices : (rooms.length * 0.4).round(),
      'motionDetections': motionDetections,
      'alertsToday': alertsToday,
      'status': status,
      'lastIncident': lastIncident,
    };
  }
  Future<Map<String, dynamic>> generateEnergyData(List<dynamic> latestSensorData) async {
    double avgPower = 0;
    double totalEnergy = 0;
    double avgVoltage = 0;
    double avgCurrent = 0;
    int activeDevices = 0;
    if (latestSensorData.isNotEmpty) {
      double totalPower = 0;
      double totalEnergySum = 0;
      double totalVoltage = 0;
      double totalCurrent = 0;
      int validReadings = 0;
      for (var sensor in latestSensorData) {
        if (sensor['power'] != null &&
            sensor['energy'] != null &&
            sensor['voltage'] != null &&
            sensor['current'] != null) {
          totalPower += (sensor['power'] as num).toDouble();
          totalEnergySum += (sensor['energy'] as num).toDouble();
          totalVoltage += (sensor['voltage'] as num).toDouble();
          totalCurrent += (sensor['current'] as num).toDouble();
          validReadings++;
          if (sensor['status'] == 'online') activeDevices++;
        }
      }
      if (validReadings > 0) {
        avgPower = totalPower / validReadings;
        totalEnergy = totalEnergySum;
        avgVoltage = totalVoltage / validReadings;
        avgCurrent = totalCurrent / validReadings;
      }
    }
    return {
      'avgPower': avgPower.isNaN ? 0 : avgPower,
      'totalEnergy': totalEnergy.isNaN ? 0 : totalEnergy,
      'avgVoltage': avgVoltage.isNaN ? 0 : avgVoltage,
      'avgCurrent': avgCurrent.isNaN ? 0 : avgCurrent,
      'activeDevices': activeDevices,
      'totalDevices': latestSensorData.length,
      'status': activeDevices > 0 ? 'operational' : 'offline',
    };
  }
  Future<List<dynamic>> generateMaintenanceData(List<dynamic> maintenanceRequests) async {
    return maintenanceRequests;
  }
}