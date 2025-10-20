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
        developer.log('Token refreshed successfully', name: 'MaintenanceManagementScreen.Auth');
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
      developer.log('Token refresh error: $e\nStack trace: $stackTrace', name: 'MaintenanceManagementScreen.Auth');
      return false;
    } finally {
      setState(() {
        isRefreshingToken = false;
      });
    }
  }

  Future<void> _loadData({bool isRetry = false}) async {
    developer.log('=== STARTING MAINTENANCE DATA LOAD === Retry: $isRetry', name: 'MaintenanceManagementScreen.LoadData');
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
          developer.log('Loaded ${maintenanceRequests.length} maintenance requests', name: 'MaintenanceManagementScreen.LoadData');
        });
      } else if (!isRetry && responses[0].statusCode >= 400) {
        developer.log('Retrying maintenance requests load due to status: ${responses[0].statusCode}', name: 'MaintenanceManagementScreen.LoadData');
        return _loadData(isRetry: true);
      } else {
        setState(() {
          _errorMessage = 'Failed to load maintenance requests: ${responses[0].statusCode}';
        });
      }

      if (responses[1].statusCode == 200) {
        final equipmentData = json.decode(responses[1].body);
        setState(() {
          equipment = equipmentData is List ? equipmentData : [];
          developer.log('Loaded ${equipment.length} equipment items', name: 'MaintenanceManagementScreen.LoadData');
        });
      } else if (!isRetry && responses[1].statusCode >= 400) {
        developer.log('Retrying equipment load due to status: ${responses[1].statusCode}', name: 'MaintenanceManagementScreen.LoadData');
        return _loadData(isRetry: true);
      } else {
        setState(() {
          _errorMessage += '\nFailed to load equipment: ${responses[1].statusCode}';
        });
      }

      if (responses[2].statusCode == 200) {
        final usersData = json.decode(responses[2].body);
        setState(() {
          users = usersData is List ? usersData : [];
          developer.log('Loaded ${users.length} users', name: 'MaintenanceManagementScreen.LoadData');
        });
      } else if (!isRetry && responses[2].statusCode >= 400) {
        developer.log('Retrying users load due to status: ${responses[2].statusCode}', name: 'MaintenanceManagementScreen.LoadData');
        return _loadData(isRetry: true);
      } else {
        setState(() {
          _errorMessage += '\nFailed to load users: ${responses[2].statusCode}';
        });
      }
    } catch (e, stackTrace) {
      developer.log('Error: $e\nStack trace: $stackTrace', name: 'MaintenanceManagementScreen.LoadData');
      setState(() {
        _errorMessage = e.toString().contains('Session expired') ? e.toString() : 'Error loading data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
        developer.log('isLoading set to false, isRefreshingToken: $isRefreshingToken', name: 'MaintenanceManagementScreen.LoadData');
      });
    }
  }

  Future<http.Response> _makeHttpRequest(String url, Map<String, String> headers, String requestName) async {
    developer.log('--- $requestName REQUEST START --- URL: $url, Headers: $headers', name: 'MaintenanceManagementScreen.HTTP');
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      developer.log('--- $requestName RESPONSE --- Status: ${response.statusCode}, Body Length: ${response.body.length}', name: 'MaintenanceManagementScreen.HTTP');
      if (response.statusCode >= 400) {
        developer.log('ERROR RESPONSE BODY: ${response.body}', name: 'MaintenanceManagementScreen.HTTP');
        if (response.statusCode == 401) {
          if (await _refreshToken()) {
            final newHeaders = AuthService().getAuthHeaders();
            developer.log('Retrying $requestName with new token', name: 'MaintenanceManagementScreen.HTTP');
            return await _makeHttpRequest(url, newHeaders, requestName);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        }
      }
      return response;
    } catch (e, stackTrace) {
      developer.log('--- $requestName REQUEST FAILED --- Error: $e\nStack Trace: $stackTrace', name: 'MaintenanceManagementScreen.HTTP');
      rethrow;
    }
  }

  List<dynamic> get filteredRequests {
    final filtered = maintenanceRequests.where((request) => _filterStatus == 'all' || (request['status'] as String?) == _filterStatus).toList();
    developer.log('Filtered requests: ${filtered.length}', name: 'MaintenanceManagementScreen.Filter');
    return filtered;
  }

  List<dynamic> get paginatedRequests {
    final filtered = filteredRequests;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginated = filtered.sublist(startIndex, endIndex.clamp(0, filtered.length));
    developer.log('Paginated requests: ${paginated.length}, page: $_currentPage', name: 'MaintenanceManagementScreen.Pagination');
    return paginated;
  }

  int get totalPages {
    final pages = (filteredRequests.length / _itemsPerPage).ceil();
    developer.log('Total pages: $pages', name: 'MaintenanceManagementScreen.Pagination');
    return pages;
  }

  String _getEquipmentName(String? equipmentId) {
    final eq = equipment.firstWhere((e) => e['id']?.toString() == equipmentId, orElse: () => {});
    return eq['name'] as String? ?? 'Unknown Equipment';
  }

  String _getUserName(String? userId) {
    final user = users.firstWhere((u) => u['id']?.toString() == userId, orElse: () => {});
    return user['username'] as String? ?? 'Unknown User';
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
    if (users.isEmpty || equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot create request: Users or equipment data not loaded',
            style: GoogleFonts.urbanist(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      isLoading = true; // Show loading briefly during navigation
    });
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MaintenanceDetailsScreen(
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((result) {
      setState(() {
        isLoading = false; // Reset loading state after navigation
      });
      if (result == true) {
        // Only refresh data if the request was saved
        _loadData();
      }
    });
  }

  Widget _buildFilterSelector() {
    final allCount = maintenanceRequests.length;
    final pendingCount = maintenanceRequests.where((r) => r['status'] == 'pending').length;
    final inProgressCount = maintenanceRequests.where((r) => r['status'] == 'in_progress').length;
    final resolvedCount = maintenanceRequests.where((r) => r['status'] == 'resolved').length;
    developer.log('Filter counts - All: $allCount, Pending: $pendingCount, In Progress: $inProgressCount, Resolved: $resolvedCount', name: 'MaintenanceManagementScreen.Filter');

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
    developer.log('Building screen - isLoading: $isLoading, isRefreshingToken: $isRefreshingToken, filtered: ${filtered.length}', name: 'MaintenanceManagementScreen.Build');

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: isRefreshingToken ? null : _loadData,
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: isLoading || isRefreshingToken
                      ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
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
                          onCreateRequest: _showAddEditMaintenanceDialog,
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
          ],
        ),
        floatingActionButton: (widget.userRole == 'admin' ||
            widget.userRole == 'superadmin' ||
            widget.userRole == 'client' ||
            widget.userRole == 'employee')
            ? MaintenanceScreenWidgets.buildCustomFAB(
          onPressed: users.isEmpty || equipment.isEmpty ? null : _showAddEditMaintenanceDialog,
          tooltip: users.isEmpty || equipment.isEmpty
              ? 'Cannot create request: Missing data'
              : 'Create New Request',
          isEnabled: users.isNotEmpty && equipment.isNotEmpty,
        )
            : null,
        bottomNavigationBar: BottomNavBar(
          onMenuSelection: (value) {
            switch (value) {
              case 'dashboard':
                Navigator.pop(context);
                break;
              case 'analytics':
                Navigator.push(
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
                Navigator.push(
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
      ),
    );
  }
}