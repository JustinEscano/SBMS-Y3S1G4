import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsWidgets {
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
          Expanded(child: Text(errorMessage, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // Overview Card Widget
  static Widget buildOverviewCard(String scopeTitle, String timeFrame) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.teal[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  '$scopeTitle Energy Overview',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Analyze energy consumption and cost trends over $timeFrame intervals',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Time Frame Selection Widget
  static Widget buildTimeFrameSelector(String currentTimeFrame, Function(String) onTimeFrameChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ChoiceChip(
          label: const Text('Daily'),
          selected: currentTimeFrame == 'daily',
          onSelected: (selected) => onTimeFrameChanged('daily'),
          selectedColor: Colors.teal[100],
          backgroundColor: Colors.grey[200],
        ),
        ChoiceChip(
          label: const Text('Weekly'),
          selected: currentTimeFrame == 'weekly',
          onSelected: (selected) => onTimeFrameChanged('weekly'),
          selectedColor: Colors.teal[100],
          backgroundColor: Colors.grey[200],
        ),
        ChoiceChip(
          label: const Text('Monthly'),
          selected: currentTimeFrame == 'monthly',
          onSelected: (selected) => onTimeFrameChanged('monthly'),
          selectedColor: Colors.teal[100],
          backgroundColor: Colors.grey[200],
        ),
      ],
    );
  }

  // Scope Selection Widget
  static Widget buildScopeSelector(String currentScope, Function(String) onScopeChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ChoiceChip(
          label: const Text('Building'),
          selected: currentScope == 'building',
          onSelected: (selected) => onScopeChanged('building'),
          selectedColor: Colors.teal[100],
          backgroundColor: Colors.grey[200],
        ),
        ChoiceChip(
          label: const Text('All Rooms'),
          selected: currentScope == 'all_rooms',
          onSelected: (selected) => onScopeChanged('all_rooms'),
          selectedColor: Colors.teal[100],
          backgroundColor: Colors.grey[200],
        ),
        ChoiceChip(
          label: const Text('Room'),
          selected: currentScope == 'room',
          onSelected: (selected) => onScopeChanged('room'),
          selectedColor: Colors.teal[100],
          backgroundColor: Colors.grey[200],
        ),
      ],
    );
  }

  // Room Selection Dropdown Widget
  static Widget buildRoomSelector({
    required String? selectedRoomId,
    required List<dynamic> rooms,
    required Function(String?) onRoomChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Select Room',
        border: OutlineInputBorder(),
      ),
      value: selectedRoomId,
      items: rooms.map<DropdownMenuItem<String>>((room) {
        return DropdownMenuItem<String>(
          value: room['id'],
          child: Text(room['name']),
        );
      }).toList(),
      onChanged: onRoomChanged,
    );
  }

  // Equipment Selection Dropdown Widget
  static Widget buildEquipmentSelector({
    required String? selectedComponentId,
    required List<dynamic> equipment,
    required String? selectedRoomId,
    required Function(String?) onEquipmentChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Select Equipment',
        border: OutlineInputBorder(),
      ),
      value: selectedComponentId,
      items: equipment
          .where((eq) => eq['room'] == selectedRoomId)
          .map<DropdownMenuItem<String>>((eq) {
        return DropdownMenuItem<String>(
          value: eq['component_id'],
          child: Text(eq['name']),
        );
      }).toList(),
      onChanged: onEquipmentChanged,
      hint: const Text('All Equipment in Room'),
    );
  }

  // Power Consumption Chart Widget
  static Widget buildPowerChart({
    required String scopeTitle,
    required String chartSuffix,
    required List<FlSpot> powerSpots,
    required String timeFrame,
    required DateTime startTime,
    required double maxX,
    required double? interval,
    required Function(double, String, DateTime) formatTimeAxis,
    required Function(double, String) shouldShowLabel,
    required double maxY,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle Power Consumption Trend$chartSuffix',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)} W',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (!shouldShowLabel(value, timeFrame)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              formatTimeAxis(value, timeFrame, startTime),
                              style: TextStyle(color: Colors.grey[600], fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: powerSpots,
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 2,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.teal.withOpacity(0.2),
                      ),
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(2)} W\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Energy Consumption Chart Widget
  static Widget buildEnergyChart({
    required String scopeTitle,
    required String chartSuffix,
    required List<FlSpot> energySpots,
    required String timeFrame,
    required DateTime startTime,
    required double maxX,
    required double? interval,
    required Function(double, String, DateTime) formatTimeAxis,
    required Function(double, String) shouldShowLabel,
    required double maxY,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle Energy Consumption Trend$chartSuffix',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(3)} kWh',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (!shouldShowLabel(value, timeFrame)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              formatTimeAxis(value, timeFrame, startTime),
                              style: TextStyle(color: Colors.grey[600], fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: energySpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.2),
                      ),
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(3)} kWh\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Temperature Trend Chart Widget
  static Widget buildTemperatureChart({
    required String scopeTitle,
    required String chartSuffix,
    required List<FlSpot> temperatureSpots,
    required String timeFrame,
    required DateTime startTime,
    required double maxX,
    required double? interval,
    required Function(double, String, DateTime) formatTimeAxis,
    required Function(double, String) shouldShowLabel,
    required double maxY,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle Temperature Trend$chartSuffix',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}°C',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (!shouldShowLabel(value, timeFrame)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              formatTimeAxis(value, timeFrame, startTime),
                              style: TextStyle(color: Colors.grey[600], fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: temperatureSpots,
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 2,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.withOpacity(0.2),
                      ),
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}°C\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Humidity Trend Chart Widget
  static Widget buildHumidityChart({
    required String scopeTitle,
    required String chartSuffix,
    required List<FlSpot> humiditySpots,
    required String timeFrame,
    required DateTime startTime,
    required double maxX,
    required double? interval,
    required Function(double, String, DateTime) formatTimeAxis,
    required Function(double, String) shouldShowLabel,
    required double maxY,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle Humidity Trend$chartSuffix',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}%',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (!shouldShowLabel(value, timeFrame)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              formatTimeAxis(value, timeFrame, startTime),
                              style: TextStyle(color: Colors.grey[600], fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: humiditySpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}%\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Statistics Card Widget
  static Widget buildStatisticsCard({
    required String scopeTitle,
    required Map<String, dynamic> summaryData,
    required String totalCost,
    required String effectiveRate,
    required Map<String, dynamic> billingData,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle Energy and Cost Statistics',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Total Energy', '${summaryData['total_energy']?.toStringAsFixed(3) ?? '0.000'} kWh'),
            _buildStatRow('Average Power', '${summaryData['avg_power']?.toStringAsFixed(1) ?? '0.0'} W'),
            _buildStatRow('Peak Power', '${summaryData['peak_power']?.toStringAsFixed(1) ?? '0.0'} W'),
            _buildStatRow('Reading Count', '${summaryData['reading_count'] ?? '0'}'),
            _buildStatRow('Anomaly Count', '${summaryData['anomaly_count'] ?? '0'}'),
            const Divider(),
            _buildStatRow('Total Cost', '$totalCost ${billingData['currency'] ?? 'PHP'}'),
            _buildStatRow('Effective Rate', '$effectiveRate ${billingData['currency'] ?? 'PHP'}/kWh'),
            if (billingData['details']?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              const Text(
                'Cost Breakdown by Component',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...billingData['details'].map<Widget>((detail) {
                return _buildStatRow(
                  detail['component_type'] ?? 'Unknown Component',
                  '${detail['cost']?.toStringAsFixed(2) ?? '0.00'} ${detail['currency'] ?? 'PHP'} (${detail['total_energy']?.toStringAsFixed(3) ?? '0.000'} kWh)',
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  // HVAC Status Card Widget
  static Widget buildHvacStatusCard({
    required String scopeTitle,
    required Map<String, dynamic> hvacData,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle HVAC Status',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Average Temperature', '${hvacData['avgTemperature']?.toStringAsFixed(1) ?? '0.0'}°C'),
            _buildStatRow('Average Humidity', '${hvacData['avgHumidity']?.toStringAsFixed(1) ?? '0.0'}%'),
            _buildStatRow('Active Zones', '${hvacData['activeZones'] ?? 0}/${hvacData['totalZones'] ?? 0}'),
            _buildStatRow('System Status', hvacData['status']?.toString().toUpperCase() ?? 'OFFLINE'),
            if (hvacData['dataPoints'] != null) ...[
              _buildStatRow('Data Points', '${hvacData['dataPoints']} readings'),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method for building stat rows
  static Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}