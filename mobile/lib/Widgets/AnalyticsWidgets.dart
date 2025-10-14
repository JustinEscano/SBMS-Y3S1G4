import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsWidgets {
  // Error Banner Widget
  static Widget buildErrorBanner(String errorMessage) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCDD2), // Red[100] for error
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: GoogleFonts.urbanist(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Combined Filter Selector (Scope, Room, Equipment)
  static Widget buildFilterSelector({
    required String currentTimeFrame,
    required Function(String) onTimeFrameChanged,
    required String currentScope,
    required Function(String) onScopeChanged,
    required String? selectedRoomId,
    required List<dynamic> rooms,
    required Function(String?) onRoomChanged,
    required String? selectedComponentId,
    required List<dynamic> equipment,
    required Function(String?) onEquipmentChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: const Color(0xFF1F1E23), // Darker gray for filter section
          elevation: 3,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 14), // Slightly wider card
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Energy Usage',
                  style: GoogleFonts.urbanist(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'Building',
                      isSelected: currentScope == 'building',
                      onSelected: () => onScopeChanged('building'),
                    ),
                    _buildFilterChip(
                      label: 'All Rooms',
                      isSelected: currentScope == 'all_rooms',
                      onSelected: () => onScopeChanged('all_rooms'),
                    ),
                    _buildFilterChip(
                      label: 'Room',
                      isSelected: currentScope == 'room',
                      onSelected: () => onScopeChanged('room'),
                    ),
                  ],
                ),
                if (currentScope == 'room') ...[
                  const SizedBox(height: 16),
                  // Room Selector
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Room',
                      labelStyle: GoogleFonts.urbanist(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    value: selectedRoomId,
                    items: rooms.map<DropdownMenuItem<String>>((room) {
                      return DropdownMenuItem<String>(
                        value: room['id'],
                        child: Text(
                          room['name'],
                          style: GoogleFonts.urbanist(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: onRoomChanged,
                    dropdownColor: const Color(0xFF1E1E1E),
                  ),
                  if (selectedRoomId != null) ...[
                    const SizedBox(height: 12),
                    // Equipment Selector
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Equipment',
                        labelStyle: GoogleFonts.urbanist(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      value: selectedComponentId,
                      items: equipment
                          .where((eq) => eq['room'] == selectedRoomId)
                          .map<DropdownMenuItem<String>>((eq) {
                        return DropdownMenuItem<String>(
                          value: eq['component_id'],
                          child: Text(
                            eq['name'],
                            style: GoogleFonts.urbanist(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: onEquipmentChanged,
                      hint: Text(
                        'All Equipment in Room',
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        // Time Frame Selector (outside and below the card)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Wrap(
            spacing: 10,
            children: [
              _buildFilterChip(
                label: 'Daily',
                isSelected: currentTimeFrame == 'daily',
                onSelected: () => onTimeFrameChanged('daily'),
              ),
              _buildFilterChip(
                label: 'Weekly',
                isSelected: currentTimeFrame == 'weekly',
                onSelected: () => onTimeFrameChanged('weekly'),
              ),
              _buildFilterChip(
                label: 'Monthly',
                isSelected: currentTimeFrame == 'monthly',
                onSelected: () => onTimeFrameChanged('monthly'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method for filter chips
  static Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => onSelected(),
      selectedColor: const Color(0xFF184BFB), // Vibrant blue for selected
      backgroundColor: const Color(0xFF1E1E1E), // Dark gray for unselected
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  // Power Chart Widget
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
    return AnimatedOpacity(
      opacity: powerSpots.isNotEmpty ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Card(
        color: const Color(0xFF1E1E1E), // Dark gray card background
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$scopeTitle Power Consumption Trend$chartSuffix',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 5 : 20.0, // Safeguard against zero
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toStringAsFixed(1)} W',
                              style: GoogleFonts.urbanist(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            if (!shouldShowLabel(value, timeFrame)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                formatTimeAxis(value, timeFrame, startTime),
                                style: GoogleFonts.urbanist(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: powerSpots,
                        isCurved: true,
                        color: const Color(0xFF184BFB), // Vibrant blue for line
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF184BFB).withOpacity(0.3),
                        ),
                        dotData: FlDotData(show: true),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1F1E23),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(2)} W\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                              GoogleFonts.urbanist(
                                color: Colors.white,
                                fontSize: 12,
                              ),
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
      ),
    );
  }

  // Energy Chart Widget
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
    return AnimatedOpacity(
      opacity: energySpots.isNotEmpty ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Card(
        color: const Color(0xFF1E1E1E), // Dark gray card background
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$scopeTitle Energy Consumption Trend$chartSuffix',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 5 : 0.02, // Safeguard for energy (kWh)
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toStringAsFixed(3)} kWh',
                              style: GoogleFonts.urbanist(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            if (!shouldShowLabel(value, timeFrame)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                formatTimeAxis(value, timeFrame, startTime),
                                style: GoogleFonts.urbanist(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: energySpots,
                        isCurved: true,
                        color: Colors.greenAccent, // Green for energy
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.greenAccent.withOpacity(0.3),
                        ),
                        dotData: FlDotData(show: true),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1F1E23),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(3)} kWh\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                              GoogleFonts.urbanist(
                                color: Colors.white,
                                fontSize: 12,
                              ),
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
      ),
    );
  }

  // Temperature Chart Widget
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
    return AnimatedOpacity(
      opacity: temperatureSpots.isNotEmpty ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Card(
        color: const Color(0xFF1E1E1E), // Dark gray card background
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$scopeTitle Temperature Trend$chartSuffix',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 5 : 10.0, // Safeguard for temperature (°C)
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toStringAsFixed(1)}°C',
                              style: GoogleFonts.urbanist(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            if (!shouldShowLabel(value, timeFrame)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                formatTimeAxis(value, timeFrame, startTime),
                                style: GoogleFonts.urbanist(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: temperatureSpots,
                        isCurved: true,
                        color: Colors.redAccent, // Red for temperature
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.redAccent.withOpacity(0.3),
                        ),
                        dotData: FlDotData(show: true),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1F1E23),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)}°C\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                              GoogleFonts.urbanist(
                                color: Colors.white,
                                fontSize: 12,
                              ),
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
      ),
    );
  }

  // Humidity Chart Widget
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
    return AnimatedOpacity(
      opacity: humiditySpots.isNotEmpty ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Card(
        color: const Color(0xFF1E1E1E), // Dark gray card background
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$scopeTitle Humidity Trend$chartSuffix',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 5 : 20.0, // Safeguard for humidity (%)
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toStringAsFixed(1)}%',
                              style: GoogleFonts.urbanist(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            if (!shouldShowLabel(value, timeFrame)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                formatTimeAxis(value, timeFrame, startTime),
                                style: GoogleFonts.urbanist(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: humiditySpots,
                        isCurved: true,
                        color: Colors.blueAccent, // Blue for humidity
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blueAccent.withOpacity(0.3),
                        ),
                        dotData: FlDotData(show: true),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1F1E23),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)}%\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                              GoogleFonts.urbanist(
                                color: Colors.white,
                                fontSize: 12,
                              ),
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
      ),
    );
  }

  // Security Chart Widget
  static Widget buildSecurityChart({
    required String scopeTitle,
    required String chartSuffix,
    required List<FlSpot> securityAlertSpots,
    required String timeFrame,
    required DateTime startTime,
    required double maxX,
    required double? interval,
    required Function(double, String, DateTime) formatTimeAxis,
    required Function(double, String) shouldShowLabel,
    required double maxY,
  }) {
    return AnimatedOpacity(
      opacity: securityAlertSpots.isNotEmpty ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Card(
        color: const Color(0xFF1E1E1E), // Dark gray card background
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$scopeTitle Security Alerts Trend$chartSuffix',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 5 : 2.0, // Safeguard for security alerts
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: GoogleFonts.urbanist(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            if (!shouldShowLabel(value, timeFrame)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                formatTimeAxis(value, timeFrame, startTime),
                                style: GoogleFonts.urbanist(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: securityAlertSpots,
                        isCurved: true,
                        color: Colors.redAccent, // Red for security alerts
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.redAccent.withOpacity(0.3),
                        ),
                        dotData: FlDotData(show: true),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1F1E23),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toInt()} Alerts\n${formatTimeAxis(spot.x, timeFrame, startTime)}',
                              GoogleFonts.urbanist(
                                color: Colors.white,
                                fontSize: 12,
                              ),
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
      color: const Color(0xFF1E1E1E), // Dark gray card background
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle Energy Statistics',
              style: GoogleFonts.urbanist(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Total Energy', '${summaryData['total_energy']?.toStringAsFixed(3) ?? '0.000'} kWh'),
            _buildStatRow('Average Power', '${summaryData['avg_power']?.toStringAsFixed(1) ?? '0.0'} W'),
            _buildStatRow('Peak Power', '${summaryData['peak_power']?.toStringAsFixed(1) ?? '0.0'} W'),
            _buildStatRow('Reading Count', '${summaryData['reading_count'] ?? '0'}'),
            _buildStatRow('Anomaly Count', '${summaryData['anomaly_count'] ?? '0'}'),
            const Divider(color: Colors.white24),
            _buildStatRow('Total Cost', '$totalCost ${billingData['currency'] ?? 'PHP'}'),
            _buildStatRow('Effective Rate', '$effectiveRate ${billingData['currency'] ?? 'PHP'}/kWh'),
            if (billingData['details']?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Cost Breakdown by Component',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
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
      color: const Color(0xFF1E1E1E), // Dark gray card background
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle HVAC Status',
              style: GoogleFonts.urbanist(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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

  // Security Status Card Widget
  static Widget buildSecurityStatusCard({
    required String scopeTitle,
    required Map<String, dynamic> securityData,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E), // Dark gray card background
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$scopeTitle Security Status',
              style: GoogleFonts.urbanist(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Active Devices', '${securityData['activeDevices'] ?? 0}/${securityData['totalDevices'] ?? 0}'),
            _buildStatRow('Alert Count', '${securityData['alertCount'] ?? 0}'),
            _buildStatRow('System Status', securityData['status']?.toString().toUpperCase() ?? 'OFFLINE'),
            if (securityData['dataPoints'] != null) ...[
              _buildStatRow('Data Points', '${securityData['dataPoints']} readings'),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method for stat rows
  static Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}