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

  Future<Map<String, dynamic>> generateSecurityData(List<dynamic> equipment, List<dynamic> latestSensorData, List<dynamic> rooms) async {
    int securityDevices = equipment.where((e) =>
    e['type']?.toLowerCase().contains('security') == true ||
        e['type']?.toLowerCase().contains('camera') == true ||
        e['name']?.toLowerCase().contains('security') == true).length;

    int motionDetections = latestSensorData.where((s) => s['motion_detected'] == true).length;

    int activeDevices = equipment.where((e) =>
    (e['type']?.toLowerCase().contains('security') == true ||
        e['type']?.toLowerCase().contains('camera') == true) &&
        e['status'] == 'online').length;

    return {
      'totalDevices': securityDevices > 0 ? securityDevices : (rooms.length * 0.5).round(),
      'activeDevices': activeDevices > 0 ? activeDevices : (rooms.length * 0.4).round(),
      'motionDetections': motionDetections,
      'alertsToday': motionDetections > 2 ? motionDetections - 2 : 0,
      'status': motionDetections > 5 ? 'alert' : 'secure',
      'lastIncident': motionDetections > 0 ? '2 hours ago' : 'None today',
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