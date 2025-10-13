import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/auth_service.dart';
import '../Screens/ProfileScreen.dart';
import '../Screens/RoomManagementScreen.dart';
import '../Screens/EquipmentManagementScreen.dart';
import '../Screens/MaintenanceManagementScreen.dart';
import '../Screens/NotificationsScreen.dart';
import '../Screens/ChatScreen.dart';
import '../Screens/EnergyAnalyticsScreen.dart';
import '../Widgets/bottom_navbar.dart';
import '../Widgets/DashboardScreenWidgets.dart';
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EnergyAnalyticsScreen(
              accessToken: widget.accessToken,
              refreshToken: authService.refreshToken ?? '',
            ),
          ),
        );
        break;
      case 'maintenance_requests':
        _navigateToMaintenanceManagement();
        break;
      case 'orb_chat':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              accessToken: widget.accessToken,
              refreshToken: authService.refreshToken ?? '',
            ),
          ),
        );
        break;
      case 'dashboard':
      default:
        break;
    }
  }

  void _showSystemDetails(String systemType, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (context) => DashboardScreenWidgets.buildSystemDetailsDialog(
        context: context,
        systemType: systemType,
        hvacData: provider.hvacData,
        securityData: provider.securityData,
        energyData: provider.energyData,
        maintenanceRequests: provider.maintenanceRequests,
        equipment: provider.equipment,
        onManage: () {
          Navigator.of(context).pop();
          final authService = Provider.of<AuthService>(context, listen: false);

          if (systemType == 'Maintenance') {
            _navigateToMaintenanceManagement();
          } else if (systemType == 'Energy' || systemType == 'HVAC' || systemType == 'Security') {
            _navigateToScreen(EnergyAnalyticsScreen(
              accessToken: widget.accessToken,
              refreshToken: authService.refreshToken ?? '',
            ));
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
        automaticallyImplyLeading: false,
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
                builder: (context) => DashboardScreenWidgets.buildManagementCenterBottomSheet(
                  onRoomManagement: () {
                    Navigator.pop(context);
                    _navigateToRoomManagement();
                  },
                  onEquipmentManagement: () {
                    Navigator.pop(context);
                    _navigateToEquipmentManagement();
                  },
                  onMaintenanceManagement: () {
                    Navigator.pop(context);
                    _navigateToMaintenanceManagement();
                  },
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
              DashboardScreenWidgets.buildNotificationBadge(provider.unreadNotificationCount),
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
                DashboardScreenWidgets.buildErrorBanner(provider.errorMessage),
              DashboardScreenWidgets.buildWelcomeCard(),
              const SizedBox(height: 20),
              const Text(
                'Building Systems',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DashboardScreenWidgets.buildSystemCard(
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
                    child: DashboardScreenWidgets.buildSystemCard(
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
                    child: DashboardScreenWidgets.buildSystemCard(
                      title: 'Security',
                      value: '${provider.securityData['activeDevices'] ?? 0}',
                      subtitle: 'Active Devices',
                      icon: Icons.security,
                      color: Colors.red,
                      status: provider.securityData['status'] ?? 'secure',
                      onTap: () => _showSystemDetails('Security', provider),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardScreenWidgets.buildSystemCard(
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
                    child: DashboardScreenWidgets.buildOverviewCard(
                      title: 'Rooms',
                      value: provider.rooms.length.toString(),
                      icon: Icons.room,
                      color: Colors.blue,
                      onTap: _navigateToRoomManagement,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardScreenWidgets.buildOverviewCard(
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
                    child: DashboardScreenWidgets.buildOverviewCard(
                      title: 'ESP32 Devices',
                      value: esp32Count.toString(),
                      icon: Icons.memory,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardScreenWidgets.buildOverviewCard(
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
                    child: DashboardScreenWidgets.buildActionCard(
                      title: 'ORB Chat',
                      icon: Icons.chat,
                      color: Colors.blue,
                      onTap: _navigateToChatScreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardScreenWidgets.buildActionCard(
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
                DashboardScreenWidgets.buildLiveSensorDataHeader(),
                const SizedBox(height: 12),
                ...provider.latestSensorData.map((sensorData) => DashboardScreenWidgets.buildSensorCard(sensorData)).toList(),
                const SizedBox(height: 24),
              ],
              if (provider.rooms.isEmpty && provider.equipment.isEmpty && provider.sensorLogs.isEmpty && provider.latestSensorData.isEmpty)
                DashboardScreenWidgets.buildEmptyState(
                  onAddRooms: _navigateToRoomManagement,
                  onAddEquipment: _navigateToEquipmentManagement,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        onMenuSelection: _handleMenuSelection,
        currentScreen: 'dashboard',
      ),
    );
  }
}