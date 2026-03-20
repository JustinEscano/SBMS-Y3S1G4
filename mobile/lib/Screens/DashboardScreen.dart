import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../Config/api.dart';
import '../utils/safe_navigation.dart';
import 'dart:developer' as developer;
class DashboardScreen extends StatefulWidget {
  final String accessToken;
  const DashboardScreen({super.key, required this.accessToken});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _profileData;
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    provider.loadData(context: context, showLoading: true);
    provider.startAutoRefresh();
    _fetchProfile();
  }
  @override
  void dispose() {
    Provider.of<DashboardProvider>(context, listen: false).dispose();
    super.dispose();
  }
  Future<void> _fetchProfile() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profileData = await authService.apiService.fetchProfile();
      if (mounted) {
        setState(() => _profileData = profileData);
      }
    } catch (e) {
      developer.log('Error fetching profile: $e', name: 'DashboardScreen.Profile');
    }
  }
  String _getProfilePictureUrl(String? picturePath) {
    if (picturePath == null || picturePath.isEmpty) return '';
    if (picturePath.startsWith('http://') || picturePath.startsWith('https://')) {
      return picturePath;
    }
    return ApiConfig.getMediaUrl(picturePath);
  }
  void _navigateToScreen(Widget screen) {
    SafeNavigation.push(context, screen, routeName: screen.runtimeType.toString())
        .then((_) => Provider.of<DashboardProvider>(context, listen: false)
        .loadData(context: context, showLoading: false));
  }
  Future<void> _navigateToMaintenanceManagement() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userRole = await authService.apiService.fetchUserRole();
      _navigateToScreen(MaintenanceManagementScreen(
        userRole: userRole,
        accessToken: widget.accessToken,
        refreshToken: authService.refreshToken ?? '',
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error fetching user role: $e',
            style: GoogleFonts.urbanist(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
        SnackBar(
          content: Text(
            'Error fetching user role: $e',
            style: GoogleFonts.urbanist(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
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
        SafeNavigation.push(
          context,
          EnergyAnalyticsScreen(
            accessToken: widget.accessToken,
            refreshToken: authService.refreshToken ?? '',
          ),
          routeName: 'analytics',
        );
        break;
      case 'maintenance_requests':
        _navigateToMaintenanceManagement();
        break;
      case 'orb_chat':
        SafeNavigation.push(
          context,
          ChatScreen(
            accessToken: widget.accessToken,
            refreshToken: authService.refreshToken ?? '',
          ),
          routeName: 'chat',
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
      builder: (_) => DashboardScreenWidgets.buildSystemDetailsDialog(
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
          } else if (systemType == 'Energy' ||
              systemType == 'HVAC' ||
              systemType == 'Security') {
            _navigateToScreen(EnergyAnalyticsScreen(
              accessToken: widget.accessToken,
              refreshToken: authService.refreshToken ?? '',
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$systemType management coming soon!',
                  style: GoogleFonts.urbanist(color: Colors.white),
                ),
                backgroundColor: Colors.red,
              ),
              SnackBar(
                content: Text(
                  '$systemType management coming soon!',
                  style: GoogleFonts.urbanist(color: Colors.white),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    // ---- ESP32 count & online count from the *aggregated* list ----
    final esp32Count = provider.aggregatedSensorData.length;
    final onlineEsp32Count = provider.aggregatedSensorData
        .where((s) => s['status'] == 'online')
        .length;
    // Profile picture
    ImageProvider? profileImage;
    bool hasImage = false;
    final profilePictureUrl =
    _getProfilePictureUrl(_profileData?['profile']['profile_picture']);
    if (profilePictureUrl.isNotEmpty) {
      profileImage = NetworkImage(profilePictureUrl);
      hasImage = true;
    }
    if (_profileData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    final isClient = _profileData?['role'] == 'client';
    return SafePopScope(
      routeName: 'dashboard',
      showExitConfirmation: true,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF121822),
          title: Row(
            children: [
              GestureDetector(
                onTap: _navigateToProfile,
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: profileImage,
                  backgroundColor: Colors.grey[200],
                  child: !hasImage
                      ? Icon(Icons.person,
                      size: 24, color: Colors.grey[600])
                      : null,
                  onBackgroundImageError: hasImage
                      ? (error, stackTrace) {
                    developer.log(
                      'Error loading profile picture: $error',
                      name: 'DashboardScreen.Image',
                      error: error,
                      stackTrace: stackTrace,
                    );
                  }
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _profileData?['username'] ?? 'User',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: ImageIcon(
                AssetImage(provider.unreadNotificationCount > 0
                    ? 'assets/icons/Notif ping.png'
                    : 'assets/icons/Notif default.png'),
                size: 24,
                color: Colors.white70,
              ),
              tooltip: 'Notifications',
              onPressed: _navigateToNotifications,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF000000),
        body: isClient
            ? Center(
          child: Text(
            'Welcome to Orbit, Dashboard for users will be in work-in-progress for now.',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        )
            : provider.isLoading
            ? Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary))
            : RefreshIndicator(
          onRefresh: () => provider.loadData(context: context, showLoading: false),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ----- Dashboard title -----
                Text('Dashboard',
                    style: GoogleFonts.urbanist(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 20),
                // ----- Error banner -----
                if (provider.errorMessage.isNotEmpty)
                  DashboardScreenWidgets.buildErrorBanner(
                      provider.errorMessage),
                const SizedBox(height: 20),
                // ----- Building Systems -----
                Text('Building Systems',
                    style: GoogleFonts.urbanist(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DashboardScreenWidgets.buildSystemCard(
                        title: 'Energy',
                        value:
                        '${provider.energyData['avgPower']?.toStringAsFixed(1) ?? '0'} W',
                        subtitle: 'Avg Power',
                        icon: Icons.electrical_services,
                        color: Colors.teal,
                        status:
                        provider.energyData['status'] ?? 'offline',
                        onTap: () => _showSystemDetails('Energy', provider),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DashboardScreenWidgets.buildSystemCard(
                        title: 'HVAC',
                        value:
                        '${provider.hvacData['activeZones'] ?? 0}/${provider.hvacData['totalZones'] ?? 0}',
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
                        value:
                        '${provider.securityData['activeDevices'] ?? 0}',
                        subtitle: 'Active Devices',
                        icon: Icons.security,
                        color: Colors.red,
                        status:
                        provider.securityData['status'] ?? 'secure',
                        onTap: () =>
                            _showSystemDetails('Security', provider),
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
                        status: provider.maintenanceRequests.any(
                                (t) =>
                            t['priority'] == 'high' ||
                                t['priority'] == 'critical')
                            ? 'attention'
                            : 'normal',
                        onTap: () =>
                            _showSystemDetails('Maintenance', provider),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ----- Infrastructure Overview -----
                Text('Infrastructure Overview',
                    style: GoogleFonts.urbanist(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
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
                // ESP32 count & online count (now from aggregated data)
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
                        value: onlineEsp32Count.toString(),
                        icon: Icons.online_prediction,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ----- Quick Actions -----
                Text('Quick Actions',
                    style: GoogleFonts.urbanist(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
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
                // ----- LIVE ESP32 SENSOR DATA -----
                if (provider.aggregatedSensorData.isNotEmpty) ...[
                  DashboardScreenWidgets.buildLiveSensorDataHeader(),
                  const SizedBox(height: 12),
                  ...provider.aggregatedSensorData
                      .map((s) => DashboardScreenWidgets.buildSensorCard(s))
                      .toList(),
                  const SizedBox(height: 24),
                ],
                // ----- Empty state -----
                if (provider.rooms.isEmpty &&
                    provider.equipment.isEmpty &&
                    provider.sensorLogs.isEmpty &&
                    provider.latestSensorData.isEmpty)
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
      ),
    );
  }
}