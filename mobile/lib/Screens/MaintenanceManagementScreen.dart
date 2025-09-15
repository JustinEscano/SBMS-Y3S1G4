import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import '../Config/api.dart'; // Updated import to point to ../Config/api.dart

class MaintenanceManagementScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const MaintenanceManagementScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<MaintenanceManagementScreen> createState() => _MaintenanceManagementScreenState();
}

class _MaintenanceManagementScreenState extends State<MaintenanceManagementScreen> {
  List<dynamic> maintenanceRequests = [];
  List<dynamic> equipment = [];
  List<dynamic> users = [];
  bool isLoading = true;
  String _errorMessage = '';
  String _filterStatus = 'all';

  // Standardized status values only
  static const List<Map<String, String>> MAINTENANCE_STATUS_OPTIONS = [
    {'value': 'pending', 'label': 'Pending', 'description': 'Request submitted, awaiting assignment'},
    {'value': 'in_progress', 'label': 'In Progress', 'description': 'Work is currently being performed'},
    {'value': 'resolved', 'label': 'Resolved', 'description': 'Issue has been fixed and verified'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    developer.log('=== STARTING MAINTENANCE DATA LOAD ===', name: 'MaintenanceScreen.LoadData');
    setState(() {
      isLoading = true;
      _errorMessage = '';
    });

    try {
      final headers = {
        'Authorization': 'Bearer ${widget.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      developer.log('Request headers: $headers', name: 'MaintenanceScreen.LoadData');
      developer.log('Request URLs:', name: 'MaintenanceScreen.LoadData');
      developer.log('  - Maintenance Requests: ${ApiConfig.maintenanceRequest}', name: 'MaintenanceScreen.LoadData');
      developer.log('  - Equipment: ${ApiConfig.equipment}', name: 'MaintenanceScreen.LoadData');
      developer.log('  - Users: ${ApiConfig.users}', name: 'MaintenanceScreen.LoadData');

      final responses = await Future.wait([
        http.get(Uri.parse(ApiConfig.maintenanceRequest), headers: headers),
        http.get(Uri.parse(ApiConfig.equipment), headers: headers),
        http.get(Uri.parse(ApiConfig.users), headers: headers),
      ]).timeout(const Duration(seconds: 15));

      // Process Maintenance Requests Response
      if (responses[0].statusCode == 200) {
        final maintenanceData = json.decode(responses[0].body);
        developer.log('Maintenance data received: $maintenanceData', name: 'MaintenanceScreen.LoadData');

        // Debug: Log all status values from backend
        if (maintenanceData is List) {
          for (var request in maintenanceData) {
            developer.log('Request status from backend: ${request['status']}', name: 'MaintenanceScreen.LoadData');
          }
        }

        setState(() {
          maintenanceRequests = maintenanceData is List ? maintenanceData : [];
        });
      } else {
        developer.log('Maintenance request failed with status: ${responses[0].statusCode}', name: 'MaintenanceScreen.LoadData');
        setState(() {
          _errorMessage = 'Failed to load maintenance requests. Status: ${responses[0].statusCode}';
        });
      }

      // Process Equipment Response
      if (responses[1].statusCode == 200) {
        final equipmentData = json.decode(responses[1].body);
        setState(() {
          equipment = equipmentData is List ? equipmentData : [];
        });
      }

      // Process Users Response
      if (responses[2].statusCode == 200) {
        final usersData = json.decode(responses[2].body);
        setState(() {
          users = usersData is List ? usersData : [];
        });
      }

      developer.log('=== MAINTENANCE DATA LOAD COMPLETED ===', name: 'MaintenanceScreen.LoadData');
      developer.log('Maintenance requests count: ${maintenanceRequests.length}', name: 'MaintenanceScreen.LoadData');
      developer.log('Equipment count: ${equipment.length}', name: 'MaintenanceScreen.LoadData');
      developer.log('Users count: ${users.length}', name: 'MaintenanceScreen.LoadData');

    } catch (e, stackTrace) {
      developer.log('=== MAINTENANCE DATA LOAD FAILED ===', name: 'MaintenanceScreen.LoadData');
      developer.log('Error: $e', name: 'MaintenanceScreen.LoadData');
      developer.log('Stack trace: $stackTrace', name: 'MaintenanceScreen.LoadData');
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteMaintenanceRequest(String requestId, String issue) async {
    developer.log('=== DELETE MAINTENANCE REQUEST ===', name: 'MaintenanceScreen.Delete');
    developer.log('Request ID: $requestId', name: 'MaintenanceScreen.Delete');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Maintenance Request'),
          content: Text('Are you sure you want to delete this maintenance request?\n\n"${issue.length > 100 ? '${issue.substring(0, 100)}...' : issue}"'),
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
        final url = '${ApiConfig.maintenanceRequest}$requestId/';
        final headers = {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        };

        developer.log('DELETE request URL: $url', name: 'MaintenanceScreen.Delete');

        final response = await http.delete(
          Uri.parse(url),
          headers: headers,
        ).timeout(const Duration(seconds: 10));

        developer.log('DELETE response status: ${response.statusCode}', name: 'MaintenanceScreen.Delete');

        if (response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maintenance request deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete request. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        developer.log('Delete maintenance request error: $e', name: 'MaintenanceScreen.Delete');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddEditMaintenanceDialog({Map<String, dynamic>? request}) {
    developer.log('=== SHOW ADD/EDIT MAINTENANCE DIALOG ===', name: 'MaintenanceScreen.Dialog');
    final isEditing = request != null;

    final issueController = TextEditingController(text: request?['issue'] ?? '');
    String selectedUserId = request?['user']?.toString() ?? (users.isNotEmpty ? users.first['id'].toString() : '');
    String selectedEquipmentId = request?['equipment']?.toString() ?? '';

    // Fix status value validation
    String requestStatus = request?['status'] ?? 'pending';
    developer.log('Original request status: $requestStatus', name: 'MaintenanceScreen.Dialog');

    // Ensure the status value matches one of our valid options
    String selectedStatus = 'pending'; // default
    final validStatuses = MAINTENANCE_STATUS_OPTIONS.map((option) => option['value']).toList();
    if (validStatuses.contains(requestStatus)) {
      selectedStatus = requestStatus;
    } else {
      developer.log('Invalid status received: $requestStatus, using default: pending', name: 'MaintenanceScreen.Dialog');
    }

    DateTime selectedDate = request?['scheduled_date'] != null
        ? DateTime.parse(request!['scheduled_date'])
        : DateTime.now().add(const Duration(days: 1));
    DateTime? resolvedDate = request?['resolved_at'] != null
        ? DateTime.parse(request!['resolved_at'])
        : null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                  maxWidth: 500, // Maximum width for better UX on tablets
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEditing ? Icons.edit : Icons.add,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isEditing ? 'Edit Maintenance Request' : 'New Maintenance Request',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    // Dialog Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // User Selection
                            DropdownButtonFormField<String>(
                              value: selectedUserId.isEmpty ? null : selectedUserId,
                              decoration: const InputDecoration(
                                labelText: 'User *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                                isDense: true,
                              ),
                              hint: const Text('Select user'),
                              isExpanded: true,
                              items: users.map((user) => DropdownMenuItem<String>(
                                value: user['id'].toString(),
                                child: Text(
                                  '${user['username']} (${user['email']})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              )).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedUserId = value ?? '';
                                });
                              },
                              selectedItemBuilder: (BuildContext context) {
                                return users.map<Widget>((user) {
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${user['username']} (${user['email']})',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            const SizedBox(height: 16),

                            // Equipment Selection
                            DropdownButtonFormField<String>(
                              value: selectedEquipmentId.isEmpty ? null : selectedEquipmentId,
                              decoration: const InputDecoration(
                                labelText: 'Equipment *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.devices),
                                isDense: true,
                              ),
                              hint: const Text('Select equipment'),
                              isExpanded: true,
                              items: equipment.map((eq) => DropdownMenuItem<String>(
                                value: eq['id'].toString(),
                                child: Text(
                                  '${eq['name']} (${eq['type']})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              )).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedEquipmentId = value ?? '';
                                });
                              },
                              selectedItemBuilder: (BuildContext context) {
                                return equipment.map<Widget>((eq) {
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${eq['name']} (${eq['type']})',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            const SizedBox(height: 16),

                            // Issue Description
                            TextField(
                              controller: issueController,
                              decoration: const InputDecoration(
                                labelText: 'Issue Description *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                                hintText: 'Describe the maintenance issue...',
                                isDense: true,
                              ),
                              maxLines: 3,
                              textInputAction: TextInputAction.newline,
                            ),
                            const SizedBox(height: 16),

                            // Status Selection - Fixed overflow
                            DropdownButtonFormField<String>(
                              value: selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.assignment),
                                isDense: true,
                              ),
                              isExpanded: true,
                              items: MAINTENANCE_STATUS_OPTIONS.map((option) {
                                return DropdownMenuItem<String>(
                                  value: option['value']!,
                                  child: Container(
                                    width: double.infinity,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(option['value']!),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option['label']!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                              Text(
                                                option['description']!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  height: 1.2,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedStatus = value ?? 'pending';
                                  // Clear resolved date if status is not resolved
                                  if (selectedStatus != 'resolved') {
                                    resolvedDate = null;
                                  }
                                });
                              },
                              selectedItemBuilder: (BuildContext context) {
                                return MAINTENANCE_STATUS_OPTIONS.map<Widget>((option) {
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(option['value']!),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            option['label']!,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            const SizedBox(height: 16),

                            // Scheduled Date
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Scheduled Date *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                  isDense: true,
                                ),
                                child: Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Resolved At Date (only show if status is resolved or if there's already a resolved date)
                            if (selectedStatus == 'resolved' || resolvedDate != null) ...[
                              InkWell(
                                onTap: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: resolvedDate ?? DateTime.now(),
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 1)),
                                  );
                                  if (picked != null) {
                                    final TimeOfDay? timePicked = await showTimePicker(
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
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.check_circle),
                                    isDense: true,
                                    suffixIcon: resolvedDate != null
                                        ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setDialogState(() {
                                          resolvedDate = null;
                                        });
                                      },
                                    )
                                        : null,
                                  ),
                                  child: Text(
                                    resolvedDate != null
                                        ? '${resolvedDate!.day}/${resolvedDate!.month}/${resolvedDate!.year} ${resolvedDate!.hour.toString().padLeft(2, '0')}:${resolvedDate!.minute.toString().padLeft(2, '0')}'
                                        : 'Select resolved date and time',
                                    style: TextStyle(
                                      color: resolvedDate != null ? Colors.black : Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Required fields note
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '* Required fields',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dialog Actions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              _saveMaintenanceRequest(
                                requestId: request?['id'],
                                userId: selectedUserId,
                                equipmentId: selectedEquipmentId,
                                issue: issueController.text,
                                status: selectedStatus,
                                scheduledDate: selectedDate,
                                resolvedAt: resolvedDate,
                                isEditing: isEditing,
                              );
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(isEditing ? 'Update' : 'Create'),
                          ),
                        ],
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
    developer.log('=== SAVE MAINTENANCE REQUEST ===', name: 'MaintenanceScreen.Save');
    developer.log('Is editing: $isEditing', name: 'MaintenanceScreen.Save');
    developer.log('User ID: $userId', name: 'MaintenanceScreen.Save');
    developer.log('Equipment ID: $equipmentId', name: 'MaintenanceScreen.Save');
    developer.log('Issue: $issue', name: 'MaintenanceScreen.Save');
    developer.log('Status: $status', name: 'MaintenanceScreen.Save');
    developer.log('Resolved At: $resolvedAt', name: 'MaintenanceScreen.Save');

    if (issue.isEmpty || equipmentId.isEmpty || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in required fields (User, Equipment, and Issue)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate that resolved date is provided if status is resolved
    if (status == 'resolved' && resolvedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide resolved date and time when status is resolved'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Build request body based on backend model structure
      final requestBody = <String, dynamic>{
        'user': userId,
        'equipment': equipmentId,
        'issue': issue,
        'status': status,
        'scheduled_date': '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
      };

      // Add resolved_at if provided
      if (resolvedAt != null) {
        requestBody['resolved_at'] = resolvedAt.toIso8601String();
      }

      developer.log('Request body: $requestBody', name: 'MaintenanceScreen.Save');

      final url = isEditing
          ? '${ApiConfig.maintenanceRequest}$requestId/'
          : ApiConfig.maintenanceRequest;

      final headers = {
        'Authorization': 'Bearer ${widget.accessToken}',
        'Content-Type': 'application/json',
      };

      developer.log('Request URL: $url', name: 'MaintenanceScreen.Save');
      developer.log('Request method: ${isEditing ? 'PUT' : 'POST'}', name: 'MaintenanceScreen.Save');

      final response = isEditing
          ? await http.put(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10))
          : await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      developer.log('Save response status: ${response.statusCode}', name: 'MaintenanceScreen.Save');
      developer.log('Save response body: ${response.body}', name: 'MaintenanceScreen.Save');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Request updated successfully' : 'Request created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else {
        try {
          final errorData = json.decode(response.body);
          String errorMessage = 'Failed to ${isEditing ? 'update' : 'create'} request.';
          if (errorData is Map) {
            // Handle field-specific errors
            if (errorData.containsKey('user')) {
              errorMessage += ' User: ${errorData['user']}';
            }
            if (errorData.containsKey('equipment')) {
              errorMessage += ' Equipment: ${errorData['equipment']}';
            }
            if (errorData.containsKey('issue')) {
              errorMessage += ' Issue: ${errorData['issue']}';
            }
            if (errorData.containsKey('status')) {
              errorMessage += ' Status: ${errorData['status']}';
            }
            if (errorData.containsKey('scheduled_date')) {
              errorMessage += ' Date: ${errorData['scheduled_date']}';
            }
            if (errorData.containsKey('resolved_at')) {
              errorMessage += ' Resolved At: ${errorData['resolved_at']}';
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to ${isEditing ? 'update' : 'create'} request. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log('Save maintenance request error: $e', name: 'MaintenanceScreen.Save');
      developer.log('Stack trace: $stackTrace', name: 'MaintenanceScreen.Save');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${isEditing ? 'updating' : 'creating'} request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<dynamic> get filteredRequests {
    return maintenanceRequests.where((request) {
      bool statusMatch = _filterStatus == 'all' || request['status'] == _filterStatus;
      return statusMatch;
    }).toList();
  }

  String _getEquipmentName(String? equipmentId) {
    if (equipmentId == null) return 'Unknown Equipment';
    final eq = equipment.firstWhere(
          (e) => e['id'].toString() == equipmentId.toString(),
      orElse: () => null,
    );
    return eq != null ? eq['name'] : 'Unknown Equipment';
  }

  String _getUserName(String? userId) {
    if (userId == null) return 'Unknown User';
    final user = users.firstWhere(
          (u) => u['id'].toString() == userId.toString(),
      orElse: () => null,
    );
    return user != null ? user['username'] : 'Unknown User';
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

  @override
  Widget build(BuildContext context) {
    final filtered = filteredRequests;
    final pendingCount = maintenanceRequests.where((r) => r['status'] == 'pending').length;
    final inProgressCount = maintenanceRequests.where((r) => r['status'] == 'in_progress').length;
    final resolvedCount = maintenanceRequests.where((r) => r['status'] == 'resolved').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards - Made more responsive
          Container(
            margin: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pending, color: Colors.orange[700], size: 24),
                                const SizedBox(height: 4),
                                FittedBox(
                                  child: Text(
                                    '$pendingCount',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const FittedBox(
                                  child: Text('Pending', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.work, color: Colors.blue[700], size: 24),
                                const SizedBox(height: 4),
                                FittedBox(
                                  child: Text(
                                    '$inProgressCount',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const FittedBox(
                                  child: Text('In Progress', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                                const SizedBox(height: 4),
                                FittedBox(
                                  child: Text(
                                    '$resolvedCount',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const FittedBox(
                                  child: Text('Resolved', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Filter Chips - Made scrollable
          if (_filterStatus != 'all')
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Chip(
                      label: Text('Status: ${_getStatusLabel(_filterStatus)}'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _filterStatus = 'all'),
                    ),
                  ],
                ),
              ),
            ),

          // Error Message
          if (_errorMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Maintenance Requests List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.build_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      maintenanceRequests.isEmpty ? 'No Maintenance Requests' : 'No Requests Match Filters',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      maintenanceRequests.isEmpty ? 'Create your first maintenance request' : 'Try adjusting your filters',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditMaintenanceDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Request'),
                    ),
                  ],
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final request = filtered[index];
                  final statusColor = _getStatusColor(request['status'] ?? '');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.2),
                        child: Icon(
                          Icons.build,
                          color: statusColor,
                        ),
                      ),
                      title: Text(
                        _getEquipmentName(request['equipment']?.toString()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['issue'] ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _getStatusLabel(request['status']),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'By: ${_getUserName(request['user']?.toString())}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (request['scheduled_date'] != null)
                            Text(
                              'Scheduled: ${DateTime.parse(request['scheduled_date']).day}/${DateTime.parse(request['scheduled_date']).month}/${DateTime.parse(request['scheduled_date']).year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (request['resolved_at'] != null)
                            Text(
                              'Resolved: ${DateTime.parse(request['resolved_at']).day}/${DateTime.parse(request['resolved_at']).month}/${DateTime.parse(request['resolved_at']).year} ${DateTime.parse(request['resolved_at']).hour.toString().padLeft(2, '0')}:${DateTime.parse(request['resolved_at']).minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAddEditMaintenanceDialog(request: request);
                          } else if (value == 'delete') {
                            _deleteMaintenanceRequest(request['id'], request['issue'] ?? '');
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditMaintenanceDialog(),
        tooltip: 'Create Maintenance Request',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempFilterStatus = _filterStatus;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                  maxWidth: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Filter Maintenance Requests',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    // Dialog Content
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<String>(
                              value: tempFilterStatus,
                              decoration: const InputDecoration(
                                labelText: 'Filter by Status',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'all',
                                  child: Text('All Statuses'),
                                ),
                                ...MAINTENANCE_STATUS_OPTIONS.map((option) => DropdownMenuItem<String>(
                                  value: option['value'],
                                  child: Text(
                                    option['label']!,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )).toList(),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  tempFilterStatus = value ?? 'all';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Dialog Actions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _filterStatus = 'all';
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Clear'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _filterStatus = tempFilterStatus;
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ],
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
}