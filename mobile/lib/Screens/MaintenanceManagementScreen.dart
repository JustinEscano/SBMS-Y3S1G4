import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../Config/api.dart';
import '../Services/auth_service.dart';
import 'package:jwt_decode/jwt_decode.dart';

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
        ),
      ),
    );
  }

  void _showFilterDialog() {
    String tempFilterStatus = _filterStatus;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5, maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogHeader(
                      context,
                      title: 'Filter Maintenance Requests',
                      icon: Icons.filter_list,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        value: tempFilterStatus,
                        decoration: InputDecoration(
                          labelText: 'Filter by Status',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.filter_alt),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(value: 'all', child: Text('All Statuses')),
                          ...MAINTENANCE_STATUS_OPTIONS.map((option) => DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(option['label']!),
                          )),
                        ],
                        onChanged: (value) => setDialogState(() => tempFilterStatus = value ?? 'all'),
                      ),
                    ),
                    _buildDialogFooter(
                      context,
                      onAction: () {
                        setState(() {
                          _filterStatus = tempFilterStatus;
                          _currentPage = 1;
                        });
                        Navigator.of(context).pop();
                      },
                      actionText: 'Apply',
                      extraAction: TextButton(
                        onPressed: () {
                          setState(() {
                            _filterStatus = 'all';
                            _currentPage = 1;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogHeader(BuildContext context, {String title = '', IconData icon = Icons.edit}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(
      BuildContext context, {required VoidCallback onAction, String actionText = 'Create', Widget? extraAction}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          if (extraAction != null) ...[
            const SizedBox(width: 8),
            extraAction,
          ],
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionText),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: const Text('Maintenance Requests'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isRefreshingToken ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(context, pendingCount, inProgressCount, resolvedCount),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ),
          if (_filterStatus != 'all')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Chip(
                label: Text('Status: ${_getStatusLabel(_filterStatus)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                backgroundColor: _getStatusColor(_filterStatus).withOpacity(0.1),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() {
                  _filterStatus = 'all';
                  _currentPage = 1;
                }),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          Expanded(
            child: isLoading || isRefreshingToken
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    maintenanceRequests.isEmpty ? 'No Maintenance Requests' : 'No Requests Match Filters',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    maintenanceRequests.isEmpty ? 'Create your first maintenance request' : 'Try adjusting your filters',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: users.isEmpty || equipment.isEmpty ? null : () => _showAddEditMaintenanceDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Request'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
                : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: paginated.length,
                      itemBuilder: (context, index) {
                        final request = paginated[index];
                        final statusColor = _getStatusColor(request['status'] ?? '');

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.2),
                              child: Icon(Icons.build, color: statusColor),
                            ),
                            title: Text(
                              _getEquipmentName(request['equipment']?.toString()),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  request['issue'] ?? 'No description',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusLabel(request['status']),
                                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'By: ${_getUserName(request['user']?.toString())}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (request['scheduled_date'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Scheduled: ${DateTime.parse(request['scheduled_date']).day}/${DateTime.parse(request['scheduled_date']).month}/${DateTime.parse(request['scheduled_date']).year}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => Navigator.push(
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
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                        ),
                        Text(
                          'Page $_currentPage of $totalPages',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: users.isEmpty || equipment.isEmpty ? null : () => _showAddEditMaintenanceDialog(),
        tooltip: 'Create Maintenance Request',
        child: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, int pendingCount, int inProgressCount, int resolvedCount) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryCard(context, 'Pending', pendingCount, Icons.pending, Colors.orange[700]!),
          const SizedBox(width: 12),
          _buildSummaryCard(context, 'In Progress', inProgressCount, Icons.work, Colors.blue[700]!),
          const SizedBox(width: 12),
          _buildSummaryCard(context, 'Resolved', resolvedCount, Icons.check_circle, Colors.green[700]!),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text('$count', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class MaintenanceDetailsScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;
  final String userRole;
  final List<dynamic> users;
  final List<dynamic> equipment;
  final List<Map<String, String>> statusOptions;
  final Map<String, dynamic>? request;
  final VoidCallback onSave;

  const MaintenanceDetailsScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
    required this.userRole,
    required this.users,
    required this.equipment,
    required this.statusOptions,
    this.request,
    required this.onSave,
  });

  @override
  State<MaintenanceDetailsScreen> createState() => _MaintenanceDetailsScreenState();
}

class _MaintenanceDetailsScreenState extends State<MaintenanceDetailsScreen> {
  final TextEditingController _responseController = TextEditingController();
  String? _selectedAssignedToId;
  int _currentCommentPage = 1;
  final int _commentsPerPage = 5;
  bool isRefreshingToken = false;

  @override
  void initState() {
    super.initState();
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
    developer.log('User Role in MaintenanceDetailsScreen: ${widget.userRole}', name: 'MaintenanceDetailsScreen');
  }

  Future<bool> _refreshToken() async {
    setState(() {
      isRefreshingToken = true;
    });
    try {
      final success = await AuthService().refresh();
      if (success) {
        developer.log('Token refreshed successfully', name: 'MaintenanceDetailsScreen.Auth');
        return true;
      }
      developer.log('Token refresh failed', name: 'MaintenanceDetailsScreen.Auth');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to refresh session. Please log in again.'), backgroundColor: Colors.red),
      );
      return false;
    } catch (e, stackTrace) {
      developer.log('Token refresh error: $e', name: 'MaintenanceDetailsScreen.Auth');
      developer.log('Stack trace: $stackTrace', name: 'MaintenanceDetailsScreen.Auth');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing session: $e'), backgroundColor: Colors.red),
      );
      return false;
    } finally {
      setState(() {
        isRefreshingToken = false;
      });
    }
  }

  String _getAttachmentUrl(String? filePath) {
    if (filePath == null || filePath.isEmpty) {
      return '';
    }
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    return ApiConfig.getMediaUrl(filePath);
  }

  Future<Uint8List?> _fetchImageData(String url) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final mediaUrl = _getAttachmentUrl(url);
      final uri = Uri.parse(mediaUrl);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return await _fetchImageData(url);
        }
      }
      return null;
    } catch (e) {
      developer.log('Error fetching image data: $e', name: 'MaintenanceDetailsScreen.Image');
      return null;
    }
  }

  Future<void> _openAttachment(String url, String fileName) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final mediaUrl = _getAttachmentUrl(url);
      final uri = Uri.parse(mediaUrl);
      developer.log('Opening attachment: $mediaUrl', name: 'MaintenanceDetailsScreen.Attachment');

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open $fileName: ${result.message}'), backgroundColor: Colors.red),
          );
        }
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _openAttachment(url, fileName);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download $fileName: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      developer.log('Error opening attachment: $e', name: 'MaintenanceDetailsScreen.Attachment');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening $fileName: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteMaintenanceRequest(String requestId, String issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Maintenance Request'),
          content: Text('Are you sure you want to delete this request?\n\n"${issue.length > 100 ? '${issue.substring(0, 100)}...' : issue}"'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        if (!(await AuthService().ensureValidToken())) {
          throw Exception('Session expired. Please log in again.');
        }
        final url = ApiConfig.maintenanceRequestDetail(requestId);
        final headers = AuthService().getAuthHeaders();

        final response = await http.delete(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

        if (response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request deleted successfully'), backgroundColor: Colors.green),
          );
          widget.onSave();
          Navigator.of(context).pop();
        } else if (response.statusCode == 401) {
          if (await _refreshToken()) {
            return _deleteMaintenanceRequest(requestId, issue);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadAttachment(String requestId) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.maintenanceRequestUploadAttachment(requestId)));
        request.headers.addAll(headers);
        request.files.add(await http.MultipartFile.fromPath('file', file.path!));
        request.fields['file_name'] = file.name;

        final response = await request.send().timeout(const Duration(seconds: 10));
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attachment uploaded successfully'), backgroundColor: Colors.green),
          );
          widget.onSave();
        } else if (response.statusCode == 401) {
          if (await _refreshToken()) {
            return _uploadAttachment(requestId);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading attachment: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _respondToMaintenanceRequest(String requestId, String responseText, String? assignedToId) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final body = <String, dynamic>{'response': responseText};
      if (assignedToId != null && assignedToId.isNotEmpty) {
        body['assigned_to'] = assignedToId;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.maintenanceRequestRespond(requestId)),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully'), backgroundColor: Colors.green),
        );
        _responseController.clear();
        setState(() {
          _selectedAssignedToId = null;
          _currentCommentPage = 1;
        });
        widget.onSave();
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _respondToMaintenanceRequest(requestId, responseText, assignedToId);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: ${errorData['error'] ?? 'Status ${response.statusCode}'}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveMaintenanceRequest({
    String? requestId,
    required String userId,
    required String equipmentId,
    required String issue,
    required String status,
    required DateTime scheduledDate,
    DateTime? resolvedAt,
    required bool isEditing,
  }) async {
    if (issue.isEmpty || equipmentId.isEmpty || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in required fields (User, Equipment, Issue)'), backgroundColor: Colors.red),
      );
      return;
    }

    if (status == 'resolved' && resolvedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resolved requests require a resolved date'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final requestBody = <String, dynamic>{
        'user': userId,
        'equipment': equipmentId,
        'issue': issue,
        'status': status,
        'scheduled_date': '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
      };

      if (resolvedAt != null) {
        requestBody['resolved_at'] = resolvedAt.toIso8601String();
      }

      final url = isEditing ? ApiConfig.maintenanceRequestDetail(requestId!) : ApiConfig.maintenanceRequest;

      final response = isEditing
          ? await http.put(Uri.parse(url), headers: headers, body: json.encode(requestBody))
          : await http.post(Uri.parse(url), headers: headers, body: json.encode(requestBody));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Request updated successfully' : 'Request created successfully'), backgroundColor: Colors.green),
        );
        widget.onSave();
        Navigator.of(context).pop();
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _saveMaintenanceRequest(
            requestId: requestId,
            userId: userId,
            equipmentId: equipmentId,
            issue: issue,
            status: status,
            scheduledDate: scheduledDate,
            resolvedAt: resolvedAt,
            isEditing: isEditing,
          );
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${isEditing ? 'update' : 'create'} request: ${errorData['error'] ?? response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ${isEditing ? 'updating' : 'creating'} request: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, String>> _parseComments(String? comments) {
    if (comments == null || comments.trim().isEmpty) return [];
    final commentList = comments.split('\n').where((line) => line.trim().isNotEmpty).toList();
    return commentList.map((comment) {
      final match = RegExp(r'\[(.*?)\]\s*(.*?)\s*\((.*?)\):\s*(.*)').firstMatch(comment);
      return {
        'timestamp': match?.group(1) ?? '',
        'user': match?.group(2) ?? '',
        'role': match?.group(3) ?? '',
        'text': match?.group(4) ?? comment,
      };
    }).toList();
  }

  String _getEquipmentName(String? equipmentId) {
    final eq = widget.equipment.firstWhere((e) => e['id'].toString() == equipmentId?.toString(), orElse: () => null);
    return eq?['name'] ?? 'Unknown Equipment';
  }

  String _getUserName(String? userId) {
    final user = widget.users.firstWhere((u) => u['id'].toString() == userId?.toString(), orElse: () => null);
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
    final option = widget.statusOptions.firstWhere(
          (option) => option['value'] == status,
      orElse: () => {'value': status ?? '', 'label': status ?? 'Unknown'},
    );
    return option['label']!;
  }

  List<Map<String, String>> get paginatedComments {
    final comments = _parseComments(widget.request?['comments']);
    final startIndex = (_currentCommentPage - 1) * _commentsPerPage;
    final endIndex = startIndex + _commentsPerPage;
    return comments.sublist(startIndex, endIndex.clamp(0, comments.length));
  }

  int get totalCommentPages {
    final comments = _parseComments(widget.request?['comments']);
    return (comments.length / _commentsPerPage).ceil();
  }

  void _showAddEditMaintenanceDialog() {
    final isEditing = widget.request != null;
    final issueController = TextEditingController(text: widget.request?['issue'] ?? '');
    String selectedUserId = widget.request?['user']?.toString() ?? (widget.users.isNotEmpty ? widget.users.first['id'].toString() : '');
    String selectedEquipmentId = widget.request?['equipment']?.toString() ?? (widget.equipment.isNotEmpty ? widget.equipment.first['id'].toString() : '');
    String selectedStatus = widget.request?['status'] ?? 'pending';
    DateTime selectedDate = widget.request?['scheduled_date'] != null
        ? DateTime.parse(widget.request!['scheduled_date'])
        : DateTime.now().add(const Duration(days: 1));
    DateTime? resolvedDate = widget.request?['resolved_at'] != null
        ? DateTime.parse(widget.request!['resolved_at'])
        : null;

    if (widget.users.isEmpty || widget.equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot create/edit request: Users or equipment data not loaded'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85, maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogHeader(
                      context,
                      title: isEditing ? 'Edit Maintenance Request' : 'New Maintenance Request',
                      icon: isEditing ? Icons.edit : Icons.add,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedUserId.isEmpty ? null : selectedUserId,
                              decoration: InputDecoration(
                                labelText: 'User *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.person),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              isExpanded: true,
                              items: widget.users.map((user) => DropdownMenuItem<String>(
                                value: user['id'].toString(),
                                child: Text('${user['username']} (${user['email']})', overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (value) => setDialogState(() => selectedUserId = value ?? ''),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedEquipmentId.isEmpty ? null : selectedEquipmentId,
                              decoration: InputDecoration(
                                labelText: 'Equipment *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.devices),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              isExpanded: true,
                              items: widget.equipment.map((eq) => DropdownMenuItem<String>(
                                value: eq['id'].toString(),
                                child: Text('${eq['name']} (${eq['type']})', overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (value) => setDialogState(() => selectedEquipmentId = value ?? ''),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: issueController,
                              decoration: InputDecoration(
                                labelText: 'Issue Description *',
                                hintText: 'Describe the maintenance issue...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.description),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              maxLines: 3,
                              textInputAction: TextInputAction.newline,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedStatus,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.assignment),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              isExpanded: true,
                              items: widget.statusOptions.map((option) => DropdownMenuItem<String>(
                                value: option['value'],
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: _getStatusColor(option['value']!), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(option['label']!),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedStatus = value ?? 'pending';
                                  if (selectedStatus != 'resolved') resolvedDate = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) setDialogState(() => selectedDate = picked);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Scheduled Date *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                child: Text(selectedDate != null
                                    ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                                    : 'Select date'),
                              ),
                            ),
                            if (selectedStatus == 'resolved' || resolvedDate != null) ...[
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: resolvedDate ?? DateTime.now(),
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 1)),
                                  );
                                  if (picked != null) {
                                    final timePicked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(resolvedDate ?? DateTime.now()),
                                    );
                                    if (timePicked != null) {
                                      setDialogState(() {
                                        resolvedDate = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          timePicked.hour,
                                          timePicked.minute,
                                        );
                                      });
                                    }
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Resolved At ${selectedStatus == 'resolved' ? '*' : ''}',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.calendar_today),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    suffixIcon: resolvedDate != null
                                        ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setDialogState(() => resolvedDate = null),
                                    )
                                        : null,
                                  ),
                                  child: Text(resolvedDate != null
                                      ? '${resolvedDate!.day}/${resolvedDate!.month}/${resolvedDate!.year} ${resolvedDate!.hour.toString().padLeft(2, '0')}:${resolvedDate!.minute.toString().padLeft(2, '0')}'
                                      : 'Select date and time'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text('* Required fields', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                    _buildDialogFooter(
                      context,
                      onAction: () {
                        _saveMaintenanceRequest(
                          requestId: widget.request?['id'],
                          userId: selectedUserId,
                          equipmentId: selectedEquipmentId,
                          issue: issueController.text,
                          status: selectedStatus,
                          scheduledDate: selectedDate,
                          resolvedAt: resolvedDate,
                          isEditing: isEditing,
                        );
                      },
                      actionText: isEditing ? 'Update' : 'Create',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogHeader(BuildContext context, {required String title, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(
      BuildContext context, {required VoidCallback onAction, String actionText = 'Create', Widget? extraAction}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          if (extraAction != null) ...[
            const SizedBox(width: 8),
            extraAction,
          ],
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.request == null) {
      developer.log('Request is null in MaintenanceDetailsScreen', name: 'MaintenanceDetailsScreen');
      return const Scaffold(
        body: Center(child: Text('No request selected')),
      );
    }

    final request = widget.request!;
    final statusColor = _getStatusColor(request['status'] ?? '');
    final attachments = request['attachments'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getEquipmentName(request['equipment']?.toString())),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showAddEditMaintenanceDialog(),
            tooltip: 'Edit Request',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteMaintenanceRequest(request['id'], request['issue'] ?? ''),
            tooltip: 'Delete Request',
          ),
        ],
      ),
      body: isRefreshingToken
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request Details', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _buildDetailRow('Issue', request['issue'] ?? 'No description', Icons.description),
                    const SizedBox(height: 12),
                    _buildDetailRow('Status', _getStatusLabel(request['status']), Icons.assignment, statusColor),
                    const SizedBox(height: 12),
                    _buildDetailRow('Requested By', _getUserName(request['user']?.toString()), Icons.person),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Scheduled Date',
                      request['scheduled_date'] != null
                          ? '${DateTime.parse(request['scheduled_date']).day}/${DateTime.parse(request['scheduled_date']).month}/${DateTime.parse(request['scheduled_date']).year}'
                          : 'Not scheduled',
                      Icons.calendar_today,
                    ),
                    if (request['resolved_at'] != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Resolved At',
                        '${DateTime.parse(request['resolved_at']).day}/${DateTime.parse(request['resolved_at']).month}/${DateTime.parse(request['resolved_at']).year} ${DateTime.parse(request['resolved_at']).hour.toString().padLeft(2, '0')}:${DateTime.parse(request['resolved_at']).minute.toString().padLeft(2, '0')}',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comments', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    if (paginatedComments.isEmpty)
                      Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    if (paginatedComments.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paginatedComments.length,
                        itemBuilder: (context, index) {
                          final comment = paginatedComments[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${comment['user'] ?? 'Unknown'} (${comment['role'] ?? 'Unknown'})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      comment['timestamp'] ?? 'No timestamp',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment['text'] ?? 'No comment text',
                                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    if (totalCommentPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentCommentPage > 1 ? () => setState(() => _currentCommentPage--) : null,
                            ),
                            Text(
                              'Page $_currentCommentPage of $totalCommentPages',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _currentCommentPage < totalCommentPages
                                  ? () => setState(() => _currentCommentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: Theme.of(context).colorScheme.primary,
                thickness: 3,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Post a New Comment',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.userRole == 'admin' || widget.userRole == 'superadmin') ...[
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                surfaceTintColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Comment', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _responseController,
                        decoration: InputDecoration(
                          labelText: 'Comment',
                          hintText: 'Enter your comment...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.comment),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Tooltip(
                          message: 'Post your comment',
                          child: ElevatedButton.icon(
                            onPressed: _responseController.text.isEmpty || isRefreshingToken
                                ? null
                                : () => _respondToMaintenanceRequest(
                              request['id'],
                              _responseController.text,
                              _selectedAssignedToId,
                            ),
                            icon: const Icon(Icons.send, size: 20),
                            label: const Text('Add Comment'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedAssignedToId,
                        decoration: InputDecoration(
                          labelText: 'Assign To (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_add),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('None', overflow: TextOverflow.ellipsis),
                          ),
                          ...widget.users
                              .where((user) => user['role'] == 'employee' || user['role'] == 'admin')
                              .map((user) => DropdownMenuItem<String>(
                            value: user['id'].toString(),
                            child: Text('${user['username']} (${user['email']})', overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (value) => setState(() => _selectedAssignedToId = value),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow[700]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: Colors.yellow[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Commenting is restricted to Admin or Superadmin roles. Your role: ${widget.userRole}',
                          style: TextStyle(color: Colors.yellow[900], fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (attachments.isNotEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attachments', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      ...attachments.map((attachment) {
                        final mediaUrl = _getAttachmentUrl(attachment['file']);
                        final isImage = attachment['file_type'].startsWith('image');
                        developer.log(
                          'Attachment URL: $mediaUrl',
                          name: 'MaintenanceDetailsScreen.Attachment',
                        );
                        return isImage
                            ? FutureBuilder<Uint8List?>(
                          future: _fetchImageData(attachment['file']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (snapshot.hasError || snapshot.data == null) {
                              return ListTile(
                                leading: const Icon(Icons.error, color: Colors.red),
                                title: Text(
                                  attachment['file_name'],
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                onTap: () => _openAttachment(attachment['file'], attachment['file_name']),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _openAttachment(attachment['file'], attachment['file_name']),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      snapshot.data!,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return ListTile(
                                          leading: const Icon(Icons.error, color: Colors.red),
                                          title: Text(
                                            attachment['file_name'],
                                            style: const TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            'Failed to load image',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                                  child: Text(
                                    'Uploaded by ${_getUserName(attachment['uploaded_by']?.toString())} at ${DateTime.parse(attachment['uploaded_at']).toLocal()}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                            : ListTile(
                          leading: Icon(
                            attachment['file_type'].startsWith('image') ? Icons.image : Icons.picture_as_pdf,
                            color: Colors.blue,
                          ),
                          title: Text(
                            attachment['file_name'],
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Uploaded by ${_getUserName(attachment['uploaded_by']?.toString())} at ${DateTime.parse(attachment['uploaded_at']).toLocal()}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          onTap: () => _openAttachment(attachment['file'], attachment['file_name']),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: isRefreshingToken ? null : () => _uploadAttachment(request['id']),
                icon: const Icon(Icons.attach_file),
                label: const Text('Add Attachment'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, [Color? color]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color ?? Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}