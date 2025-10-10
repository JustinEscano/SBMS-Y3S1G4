import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/auth_service.dart';
import '../Screens/ProfileScreen.dart';
import '../Screens/RoomManagementScreen.dart';
import '../Screens/EquipmentManagementScreen.dart';
import '../Screens/MaintenanceManagementScreen.dart';
import '../Screens/QRScannerScreen.dart';
import '../Screens/NotificationsScreen.dart';
import '../Screens/ChatScreen.dart';
import '../Screens/EnergyAnalyticsScreen.dart';
import '../Widgets/bottom_navbar.dart';
import '../Widgets/welcome_card.dart';
import '../Widgets/system_card.dart';
import '../Widgets/overview_card.dart';
import '../Widgets/action_card.dart';
import '../Widgets/sensor_card.dart';
import '../Widgets/management_tile.dart';
import '../Widgets/system_details_dialog.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends StatefulWidget {
  final String accessToken;
  const DashboardScreen({super.key, required this.accessToken});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    provider.loadData(context: context);
    provider.startAutoRefresh();
  }

  @override
  void dispose() {
    Provider.of<DashboardProvider>(context, listen: false).dispose();
    super.dispose();
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => Provider.of<DashboardProvider>(context, listen: false).loadData(context: context));
  }

  Future<void> _navigateToMaintenanceManagement() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      String userRole = await authService.apiService.fetchUserRole();
      _navigateToScreen(MaintenanceManagementScreen(
        userRole: userRole,
        accessToken: widget.accessToken,
        refreshToken: authService.refreshToken ?? '',
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user role: $e')),
      );
    }
  }

  void _navigateToChatScreen() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _navigateToScreen(ChatScreen(
      accessToken: widget.accessToken,
      refreshToken: authService.refreshToken ?? '',
    ));
  }

  void _navigateToRoomManagement() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _navigateToScreen(RoomManagementScreen(
      accessToken: widget.accessToken,
      refreshToken: authService.refreshToken ?? '',
    ));
  }

  void _navigateToEquipmentManagement() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _navigateToScreen(EquipmentManagementScreen(
      accessToken: widget.accessToken,
      refreshToken: authService.refreshToken ?? '',
    ));
  }

  void _navigateToQRScanner() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _navigateToScreen(QRScannerScreen(
      accessToken: widget.accessToken,
      refreshToken: authService.refreshToken ?? '',
    ));
  }

  void _navigateToNotifications() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _navigateToScreen(NotificationsScreen(
      accessToken: widget.accessToken,
      refreshToken: authService.refreshToken ?? '',
    ));
  }

  void _navigateToProfile() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _navigateToScreen(ProfileScreen(
      accessToken: widget.accessToken,
      refreshToken: authService.refreshToken ?? '',
    ));
  }

  void _handleMenuSelection(String value) {
    final authService = Provider.of<AuthService>(context, listen: false);
    switch (value) {
      case 'analytics':
        _navigateToScreen(EnergyAnalyticsScreen(
          accessToken: widget.accessToken,
          refreshToken: authService.refreshToken ?? '',
        ));
        break;
      case 'maintenance_requests':
        _navigateToMaintenanceManagement();
        break;
      case 'notifications':
        _navigateToNotifications();
        break;
      case 'about':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('About feature coming soon!')),
        );
        break;
      case 'orb_chat':
        _navigateToChatScreen();
        break;
      case 'dashboard':
      default:
        break;
    }
  }

  void _showSystemDetails(String systemType, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (context) => SystemDetailsDialog(
        systemType: systemType,
        hvacData: provider.hvacData,
        lightingData: provider.lightingData,
        securityData: provider.securityData,
        energyData: provider.energyData,
        maintenanceRequests: provider.maintenanceRequests,
        equipment: provider.equipment,
        onManage: () {
          Navigator.of(context).pop();
          if (systemType == 'Maintenance') {
            _navigateToMaintenanceManagement();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$systemType management coming soon!')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final onlineEquipment = provider.equipment.where((e) => e['status'] == 'online').length;
    final esp32Count = provider.equipment.where((e) => e['type']?.toLowerCase() == 'esp32').length;
    final totalCapacity = provider.rooms.fold<int>(0, (sum, room) => sum + (room['capacity'] as int? ?? 0));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Smart Building Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => Container(
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
                      ManagementTile(
                        icon: Icons.room,
                        title: 'Room Management',
                        subtitle: 'Add, edit, and manage building rooms',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToRoomManagement();
                        },
                      ),
                      ManagementTile(
                        icon: Icons.devices,
                        title: 'Equipment Management',
                        subtitle: 'Add, edit, and manage equipment',
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToEquipmentManagement();
                        },
                      ),
                      ManagementTile(
                        icon: Icons.build,
                        title: 'Maintenance Management',
                        subtitle: 'Create and manage maintenance requests',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToMaintenanceManagement();
                        },
                      ),
                      ManagementTile(
                        icon: Icons.qr_code_scanner,
                        title: 'QR Code Scanner',
                        subtitle: 'Scan equipment QR codes for quick access',
                        color: Colors.deepPurple,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToQRScanner();
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
            tooltip: 'Management Center',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'Notifications',
                onPressed: _navigateToNotifications,
              ),
              if (provider.unreadNotificationCount > 0)
                Positioned(
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
                      '${provider.unreadNotificationCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadData(context: context),
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: _navigateToProfile,
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => provider.loadData(context: context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.errorMessage.isNotEmpty)
                Container(
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
                          provider.errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              const WelcomeCard(),
              const SizedBox(height: 20),
              const Text(
                'Building Systems',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SystemCard(
                      title: 'Energy',
                      value: '${provider.energyData['avgPower']?.toStringAsFixed(1) ?? '0'} W',
                      subtitle: 'Avg Power',
                      icon: Icons.electrical_services,
                      color: Colors.teal,
                      status: provider.energyData['status'] ?? 'offline',
                      onTap: () => _showSystemDetails('Energy', provider),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SystemCard(
                      title: 'HVAC',
                      value: '${provider.hvacData['activeZones'] ?? 0}/${provider.hvacData['totalZones'] ?? 0}',
                      subtitle: 'Active Zones',
                      icon: Icons.thermostat,
                      color: Colors.orange,
                      status: provider.hvacData['status'] ?? 'offline',
                      onTap: () => _showSystemDetails('HVAC', provider),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SystemCard(
                      title: 'Lighting',
                      value: '${provider.lightingData['detectedLights'] ?? 0}/${provider.lightingData['totalDevices'] ?? 0}',
                      subtitle: 'Lights Detected',
                      icon: Icons.lightbulb,
                      color: Colors.amber,
                      status: provider.lightingData['status'] ?? 'normal',
                      onTap: () => _showSystemDetails('Lighting', provider),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SystemCard(
                      title: 'Security',
                      value: '${provider.securityData['activeDevices'] ?? 0}',
                      subtitle: 'Active Devices',
                      icon: Icons.security,
                      color: Colors.red,
                      status: provider.securityData['status'] ?? 'secure',
                      onTap: () => _showSystemDetails('Security', provider),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SystemCard(
                      title: 'Maintenance',
                      value: '${provider.maintenanceRequests.length}',
                      subtitle: 'Total Requests',
                      icon: Icons.build,
                      color: Colors.indigo,
                      status: provider.maintenanceRequests.any((task) => task['priority'] == 'high' || task['priority'] == 'critical')
                          ? 'attention'
                          : 'normal',
                      onTap: () => _showSystemDetails('Maintenance', provider),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Infrastructure Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OverviewCard(
                      title: 'Rooms',
                      value: provider.rooms.length.toString(),
                      icon: Icons.room,
                      color: Colors.blue,
                      onTap: _navigateToRoomManagement,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OverviewCard(
                      title: 'Equipment',
                      value: provider.equipment.length.toString(),
                      icon: Icons.devices,
                      color: Colors.green,
                      onTap: _navigateToEquipmentManagement,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OverviewCard(
                      title: 'ESP32 Devices',
                      value: esp32Count.toString(),
                      icon: Icons.memory,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OverviewCard(
                      title: 'Online',
                      value: onlineEquipment.toString(),
                      icon: Icons.online_prediction,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ActionCard(
                      title: 'QR Scanner',
                      icon: Icons.qr_code_scanner,
                      color: Colors.deepPurple,
                      onTap: _navigateToQRScanner,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ActionCard(
                      title: 'ORB Chat',
                      icon: Icons.chat,
                      color: Colors.blue,
                      onTap: _navigateToChatScreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ActionCard(
                      title: 'Maintenance',
                      icon: Icons.build,
                      color: Colors.indigo,
                      onTap: _navigateToMaintenanceManagement,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (provider.latestSensorData.isNotEmpty) ...[
                Row(
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
                ),
                const SizedBox(height: 12),
                ...provider.latestSensorData.map((sensorData) => SensorCard(sensorData: sensorData)).toList(),
                const SizedBox(height: 24),
              ],
              if (provider.rooms.isEmpty && provider.equipment.isEmpty && provider.sensorLogs.isEmpty && provider.latestSensorData.isEmpty)
                Card(
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
                              onPressed: _navigateToRoomManagement,
                              icon: const Icon(Icons.room),
                              label: const Text('Add Rooms'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _navigateToEquipmentManagement,
                              icon: const Icon(Icons.devices),
                              label: const Text('Add Equipment'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToQRScanner,
        tooltip: 'QR Code Scanner',
        child: const Icon(Icons.qr_code_scanner),
      ),
      bottomNavigationBar: BottomNavBar(
        onMenuSelection: _handleMenuSelection,
        currentScreen: 'dashboard',
      ),
    );
  }
}