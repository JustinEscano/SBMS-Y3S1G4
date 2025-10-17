import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:jwt_decode/jwt_decode.dart';
import '../Config/api.dart';
import '../Services/auth_service.dart';
import 'MaintenanceDetailsScreen.dart';
import '../Widgets/MaintenanceScreenWidgets.dart';
import '../Widgets/bottom_navbar.dart';
import 'DashboardScreen.dart';
import 'EnergyAnalyticsScreen.dart';
import 'ChatScreen.dart';

class MaintenanceManagementScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;
  final String userRole;

  const MaintenanceManagementScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
    required this.userRole,
  });

  @override
  State<MaintenanceManagementScreen> createState() => _MaintenanceManagementScreenState();
}

class _MaintenanceManagementScreenState extends State<MaintenanceManagementScreen> {
  List<dynamic> maintenanceRequests = [];
  List<dynamic> equipment = [];
  List<dynamic> users = [];
  bool isLoading = true;
  bool isRefreshingToken = false;
  String _errorMessage = '';
  String _filterStatus = 'all';
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  String? _currentUserId;

  static const List<Map<String, String>> MAINTENANCE_STATUS_OPTIONS = [
    {'value': 'pending', 'label': 'Pending', 'description': 'Request submitted, awaiting assignment'},
    {'value': 'in_progress', 'label': 'In Progress', 'description': 'Work is currently being performed'},
    {'value': 'resolved', 'label': 'Resolved', 'description': 'Issue has been fixed and verified'},
  ];

  @override
  void initState() {
    super.initState();
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
    developer.log('User Role: ${widget.userRole}', name: 'MaintenanceManagementScreen');
    try {
      Map<String, dynamic> payload = Jwt.parseJwt(widget.accessToken);
      developer.log('Token Payload: $payload', name: 'MaintenanceManagementScreen');
      _currentUserId = payload['user_id']?.toString();
    } catch (e) {
      developer.log('Error decoding token: $e', name: 'MaintenanceManagementScreen');
    }
    _loadData();
  }

  Future<bool> _refreshToken() async {
    setState(() {
      isRefreshingToken = true;
      _errorMessage = 'Refreshing session...';
    });
    try {
      final success = await AuthService().refresh();
      if (success) {
        developer.log('Token refreshed successfully', name: 'MaintenanceScreen.Auth');
        return true;
      }
      setState(() {
        _errorMessage = 'Failed to refresh session. Please log in again.';
      });
      return false;
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Error refreshing session: $e';
      });
      developer.log('Token refresh error: $e\nStack trace: $stackTrace', name: 'MaintenanceScreen.Auth');
      return false;
    } finally {
      setState(() {
        isRefreshingToken = false;
      });
    }
  }

  Future<void> _loadData() async {
    developer.log('=== STARTING MAINTENANCE DATA LOAD ===', name: 'MaintenanceScreen.LoadData');
    setState(() {
      isLoading = true;
      _errorMessage = '';
      _currentPage = 1;
    });

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      final responses = await Future.wait([
        _makeHttpRequest(ApiConfig.maintenanceRequest, headers, 'Maintenance Requests'),
        _makeHttpRequest(ApiConfig.equipment, headers, 'Equipment'),
        _makeHttpRequest(ApiConfig.users, headers, 'Users'),
      ]).timeout(const Duration(seconds: 15));

      if (responses[0].statusCode == 200) {
        final maintenanceData = json.decode(responses[0].body);
        setState(() {
          maintenanceRequests = maintenanceData is List ? maintenanceData : [];
          developer.log('Loaded ${maintenanceRequests.length} maintenance requests: $maintenanceData', name: 'MaintenanceScreen.LoadData');
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load maintenance requests: ${responses[0].statusCode}';
        });
      }

      if (responses[1].statusCode == 200) {
        final equipmentData = json.decode(responses[1].body);
        setState(() {
          equipment = equipmentData is List ? equipmentData : [];
          developer.log('Loaded ${equipment.length} equipment items', name: 'MaintenanceScreen.LoadData');
        });
      } else {
        setState(() {
          _errorMessage += '\nFailed to load equipment: ${responses[1].statusCode}';
        });
      }

      if (responses[2].statusCode == 200) {
        final usersData = json.decode(responses[2].body);
        setState(() {
          users = usersData is List ? usersData : [];
          developer.log('Loaded ${users.length} users', name: 'MaintenanceScreen.LoadData');
        });
      } else {
        setState(() {
          _errorMessage += '\nFailed to load users: ${responses[2].statusCode}';
        });
      }
    } catch (e, stackTrace) {
      developer.log('Error: $e\nStack trace: $stackTrace', name: 'MaintenanceScreen.LoadData');
      setState(() {
        _errorMessage = e.toString().contains('Session expired') ? e.toString() : 'Error loading data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
        developer.log('isLoading set to false, isRefreshingToken: $isRefreshingToken', name: 'MaintenanceScreen.LoadData');
      });
    }
  }

  Future<http.Response> _makeHttpRequest(String url, Map<String, String> headers, String requestName) async {
    developer.log('--- $requestName REQUEST START --- URL: $url, Headers: $headers', name: 'MaintenanceScreen.HTTP');
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      developer.log('--- $requestName RESPONSE --- Status: ${response.statusCode}, Body Length: ${response.body.length}', name: 'MaintenanceScreen.HTTP');
      if (response.statusCode >= 400) {
        developer.log('ERROR RESPONSE BODY: ${response.body}', name: 'MaintenanceScreen.HTTP');
        if (response.statusCode == 401) {
          if (await _refreshToken()) {
            final newHeaders = AuthService().getAuthHeaders();
            developer.log('Retrying $requestName with new token', name: 'MaintenanceScreen.HTTP');
            return await _makeHttpRequest(url, newHeaders, requestName);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        }
      }
      return response;
    } catch (e, stackTrace) {
      developer.log('--- $requestName REQUEST FAILED --- Error: $e\nStack Trace: $stackTrace', name: 'MaintenanceScreen.HTTP');
      rethrow;
    }
  }

  List<dynamic> get filteredRequests {
    final filtered = maintenanceRequests.where((request) => _filterStatus == 'all' || (request['status'] as String?) == _filterStatus).toList();
    developer.log('Filtered requests: ${filtered.length}', name: 'MaintenanceScreen.Filter');
    return filtered;
  }

  List<dynamic> get paginatedRequests {
    final filtered = filteredRequests;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginated = filtered.sublist(startIndex, endIndex.clamp(0, filtered.length));
    developer.log('Paginated requests: ${paginated.length}, page: $_currentPage', name: 'MaintenanceScreen.Pagination');
    return paginated;
  }

  int get totalPages {
    final pages = (filteredRequests.length / _itemsPerPage).ceil();
    developer.log('Total pages: $pages', name: 'MaintenanceScreen.Pagination');
    return pages;
  }

  String _getEquipmentName(String? equipmentId) {
    final eq = equipment.firstWhere((e) => e['id']?.toString() == equipmentId, orElse: () => null);
    return eq?['name'] as String? ?? 'Unknown Equipment';
  }

  String _getUserName(String? userId) {
    final user = users.firstWhere((u) => u['id']?.toString() == userId, orElse: () => null);
    return user?['username'] as String? ?? 'Unknown User';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    final option = MAINTENANCE_STATUS_OPTIONS.firstWhere(
          (option) => option['value'] == status,
      orElse: () => {'value': status ?? '', 'label': status ?? 'Unknown'},
    );
    return option['label']!;
  }

  void _showAddEditMaintenanceDialog({Map<String, dynamic>? request}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceDetailsScreen(
          accessToken: AuthService().accessToken ?? widget.accessToken,
          refreshToken: AuthService().refreshToken ?? widget.refreshToken,
          userRole: widget.userRole,
          users: users,
          equipment: equipment,
          statusOptions: MAINTENANCE_STATUS_OPTIONS,
          request: request,
          onSave: _loadData,
          currentUserId: _currentUserId,
        ),
      ),
    ).then((_) => _loadData());
  }

  Widget _buildFilterSelector() {
    final allCount = maintenanceRequests.length;
    final pendingCount = maintenanceRequests.where((r) => r['status'] == 'pending').length;
    final inProgressCount = maintenanceRequests.where((r) => r['status'] == 'in_progress').length;
    final resolvedCount = maintenanceRequests.where((r) => r['status'] == 'resolved').length;
    developer.log('Filter counts - All: $allCount, Pending: $pendingCount, In Progress: $inProgressCount, Resolved: $resolvedCount', name: 'MaintenanceScreen.Filter');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            MaintenanceScreenWidgets.buildFilterChip(
              label: 'All ($allCount)',
              isSelected: _filterStatus == 'all',
              onSelected: () => setState(() {
                _filterStatus = 'all';
                _currentPage = 1;
              }),
            ),
            const SizedBox(width: 8),
            ...MAINTENANCE_STATUS_OPTIONS.map((option) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MaintenanceScreenWidgets.buildFilterChip(
                label: '${option['label']} (${option['value'] == 'pending' ? pendingCount : option['value'] == 'in_progress' ? inProgressCount : resolvedCount})',
                isSelected: _filterStatus == option['value'],
                onSelected: () => setState(() {
                  _filterStatus = option['value']!;
                  _currentPage = 1;
                }),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredRequests;
    final paginated = paginatedRequests;
    developer.log('Building screen - isLoading: $isLoading, isRefreshingToken: $isRefreshingToken, filtered: ${filtered.length}', name: 'MaintenanceScreen.Build');

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Maintenance Requests',
          style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1F1E23),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isRefreshingToken ? null : _loadData,
            tooltip: 'Refresh',
            color: Colors.white70,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading || isRefreshingToken
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildFilterSelector(),
                if (_errorMessage.isNotEmpty)
                  MaintenanceScreenWidgets.buildErrorBanner(context, _errorMessage),
                filtered.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: MaintenanceScreenWidgets.buildEmptyState(
                    context,
                    hasRequests: maintenanceRequests.isNotEmpty,
                    canCreateRequest: users.isNotEmpty && equipment.isNotEmpty,
                    onCreateRequest: () => _showAddEditMaintenanceDialog(),
                  ),
                )
                    : MaintenanceScreenWidgets.buildMaintenanceRequestListWithPagination(
                  context,
                  requests: paginated.cast<Map<String, dynamic>>(),
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  getEquipmentName: _getEquipmentName,
                  getUserName: _getUserName,
                  getStatusLabel: _getStatusLabel,
                  getStatusColor: _getStatusColor,
                  onRequestTap: (request) => _showAddEditMaintenanceDialog(request: request),
                  onPreviousPage: () => setState(() => _currentPage--),
                  onNextPage: () => setState(() => _currentPage++),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (widget.userRole == 'admin' || widget.userRole == 'superadmin' || widget.userRole == 'client' || widget.userRole == 'employee')
          ? FloatingActionButton(
        onPressed: users.isEmpty || equipment.isEmpty ? null : () => _showAddEditMaintenanceDialog(),
        tooltip: 'Create Maintenance Request',
        child: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      )
          : null,
      bottomNavigationBar: BottomNavBar(
        onMenuSelection: (value) {
          switch (value) {
            case 'dashboard':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    accessToken: AuthService().accessToken ?? widget.accessToken,
                  ),
                ),
              );
              break;
            case 'analytics':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EnergyAnalyticsScreen(
                    accessToken: AuthService().accessToken ?? widget.accessToken,
                    refreshToken: AuthService().refreshToken ?? widget.refreshToken,
                  ),
                ),
              );
              break;
            case 'maintenance_requests':
              break;
            case 'orb_chat':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    accessToken: AuthService().accessToken ?? widget.accessToken,
                    refreshToken: AuthService().refreshToken ?? widget.refreshToken,
                  ),
                ),
              );
              break;
          }
        },
        currentScreen: 'maintenance_requests',
      ),
    );
  }
}