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
    developer.log('User Role in MaintenanceManagementScreen: ${widget.userRole}', name: 'MaintenanceManagementScreen');
    try {
      Map<String, dynamic> payload = Jwt.parseJwt(widget.accessToken);
      developer.log('Token Payload: $payload', name: 'MaintenanceManagementScreen');
      developer.log('Token Role: ${payload['role']}', name: 'MaintenanceManagementScreen');
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
      developer.log('Token refresh failed', name: 'MaintenanceScreen.Auth');
      return false;
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Error refreshing session: $e';
      });
      developer.log('Token refresh error: $e', name: 'MaintenanceScreen.Auth');
      developer.log('Stack trace: $stackTrace', name: 'MaintenanceScreen.Auth');
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
        });
      } else {
        setState(() {
          _errorMessage += '\nFailed to load users: ${responses[2].statusCode}';
        });
      }
    } catch (e, stackTrace) {
      developer.log('Error: $e', name: 'MaintenanceScreen.LoadData');
      developer.log('Stack trace: $stackTrace', name: 'MaintenanceScreen.LoadData');
      setState(() {
        _errorMessage = e.toString().contains('Session expired') ? e.toString() : 'Error loading data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<http.Response> _makeHttpRequest(String url, Map<String, String> headers, String requestName) async {
    developer.log('--- $requestName REQUEST START ---', name: 'MaintenanceScreen.HTTP');
    developer.log('URL: $url', name: 'MaintenanceScreen.HTTP');
    developer.log('Headers: $headers', name: 'MaintenanceScreen.HTTP');

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      developer.log('--- $requestName RESPONSE ---', name: 'MaintenanceScreen.HTTP');
      developer.log('Status Code: ${response.statusCode}', name: 'MaintenanceScreen.HTTP');
      developer.log('Response Body Length: ${response.body.length}', name: 'MaintenanceScreen.HTTP');

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
      developer.log('--- $requestName REQUEST FAILED ---', name: 'MaintenanceScreen.HTTP');
      developer.log('Error: $e', name: 'MaintenanceScreen.HTTP');
      developer.log('Stack Trace: $stackTrace', name: 'MaintenanceScreen.HTTP');
      rethrow;
    }
  }

  List<dynamic> get filteredRequests {
    return maintenanceRequests.where((request) => _filterStatus == 'all' || request['status'] == _filterStatus).toList();
  }

  List<dynamic> get paginatedRequests {
    final filtered = filteredRequests;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return filtered.sublist(startIndex, endIndex.clamp(0, filtered.length));
  }

  int get totalPages {
    return (filteredRequests.length / _itemsPerPage).ceil();
  }

  String _getEquipmentName(String? equipmentId) {
    final eq = equipment.firstWhere((e) => e['id'].toString() == equipmentId?.toString(), orElse: () => null);
    return eq?['name'] ?? 'Unknown Equipment';
  }

  String _getUserName(String? userId) {
    final user = users.firstWhere((u) => u['id'].toString() == userId?.toString(), orElse: () => null);
    return user?['username'] ?? 'Unknown User';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MaintenanceScreenWidgets.buildFilterDialog(
          context,
          currentFilterStatus: _filterStatus,
          statusOptions: MAINTENANCE_STATUS_OPTIONS,
          onFilterChanged: (value) {
            setState(() {
              _filterStatus = value;
              _currentPage = 1;
            });
            Navigator.of(context).pop();
          },
          onClearFilter: () {
            setState(() {
              _filterStatus = 'all';
              _currentPage = 1;
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredRequests;
    final paginated = paginatedRequests;
    final pendingCount = maintenanceRequests.where((r) => r['status'] == 'pending').length;
    final inProgressCount = maintenanceRequests.where((r) => r['status'] == 'in_progress').length;
    final resolvedCount = maintenanceRequests.where((r) => r['status'] == 'resolved').length;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Maintenance Requests',
        style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),),
        backgroundColor: const Color(0xFF1F1E23),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
            color: Colors.white70,
          ),
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
          MaintenanceScreenWidgets.buildSummaryCards(context, pendingCount, inProgressCount, resolvedCount),
          if (_errorMessage.isNotEmpty)
            MaintenanceScreenWidgets.buildErrorBanner(context, _errorMessage),
          if (_filterStatus != 'all')
            MaintenanceScreenWidgets.buildFilterChip(
              context,
              filterStatus: _filterStatus,
              getStatusLabel: _getStatusLabel,
              getStatusColor: _getStatusColor,
              onRemoveFilter: () => setState(() {
                _filterStatus = 'all';
                _currentPage = 1;
              }),
            ),
          Expanded(
            child: isLoading || isRefreshingToken
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? MaintenanceScreenWidgets.buildEmptyState(
              context,
              hasRequests: maintenanceRequests.isNotEmpty,
              canCreateRequest: users.isNotEmpty && equipment.isNotEmpty,
              onCreateRequest: () => _showAddEditMaintenanceDialog(),
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
            // Already on maintenance requests screen
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
            default:
              break;
          }
        },
        currentScreen: 'maintenance_requests',
      ),
    );
  }
}
