import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import '../Config/api.dart';

class EquipmentManagementScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const EquipmentManagementScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<EquipmentManagementScreen> createState() => _EquipmentManagementScreenState();
}

class _EquipmentManagementScreenState extends State<EquipmentManagementScreen> {
  List<dynamic> equipment = [];
  List<dynamic> rooms = [];
  bool isLoading = true;
  String _errorMessage = '';
  String _filterRoom = 'all';
  String _filterType = 'all';

  static const List<Map<String, String>> EQUIPMENT_STATUS_OPTIONS = [
    {'value': 'online', 'label': 'Online', 'description': 'Equipment is working and connected'},
    {'value': 'offline', 'label': 'Offline', 'description': 'Equipment is not working or disconnected'},
    {'value': 'maintenance', 'label': 'Maintenance', 'description': 'Equipment is under maintenance'},
    {'value': 'error', 'label': 'Error', 'description': 'Equipment has errors or issues'},
  ];

  static const List<Map<String, String>> EQUIPMENT_TYPE_OPTIONS = [
    {'value': 'esp32', 'label': 'ESP32', 'description': 'ESP32 microcontroller'},
    {'value': 'sensor', 'label': 'Sensor', 'description': 'General sensors'},
    {'value': 'actuator', 'label': 'Actuator', 'description': 'Motors, relays, etc.'},
    {'value': 'controller', 'label': 'Controller', 'description': 'Control devices'},
    {'value': 'monitor', 'label': 'Monitor', 'description': 'Monitoring devices'},
  ];

  @override
  void initState() {
    super.initState();
    _logAppInfo();
    _loadData();
  }

  void _logAppInfo() {
    developer.log('=== EQUIPMENT MANAGEMENT SCREEN INITIALIZED ===', name: 'EquipmentScreen');
    developer.log('Base URL: ${ApiConfig.baseUrl}', name: 'EquipmentScreen');
    developer.log('Access Token Length: ${widget.accessToken.length}', name: 'EquipmentScreen');
    developer.log('Access Token Preview: ${widget.accessToken.substring(0, 20)}...', name: 'EquipmentScreen');
    developer.log('Refresh Token Length: ${widget.refreshToken.length}', name: 'EquipmentScreen');
  }

  // TEMPORARY BYPASS: Comment out the if (!hasNetwork) block below to skip the check and test API calls directly.
  Future<bool> _checkNetworkConnectivity() async {
    developer.log('=== CHECKING NETWORK CONNECTIVITY ===', name: 'EquipmentScreen.Network');
    try {
      // Direct backend ping first (reliable, no external DNS)
      final backendResponse = await http.get(Uri.parse(ApiConfig.baseUrl)).timeout(const Duration(seconds: 5));
      if (backendResponse.statusCode >= 200 && backendResponse.statusCode < 300) {
        developer.log('Backend reachable: ${ApiConfig.baseUrl} (Status: ${backendResponse.statusCode})', name: 'EquipmentScreen.Network');
        return true;
      }
      developer.log('Backend ping failed (Status: ${backendResponse.statusCode}), falling back to google.com', name: 'EquipmentScreen.Network');
    } catch (e) {
      developer.log('Backend ping failed: $e, falling back to google.com', name: 'EquipmentScreen.Network');
    }

    // Fallback to google.com
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        developer.log('Google.com DNS lookup: OK', name: 'EquipmentScreen.Network');
        return true;
      }
    } catch (e) {
      developer.log('Google.com DNS lookup failed: $e', name: 'EquipmentScreen.Network');
    }

    developer.log('All connectivity checks failed', name: 'EquipmentScreen.Network');
    return false;
  }

  Future<void> _loadData() async {
    developer.log('=== STARTING DATA LOAD ===', name: 'EquipmentScreen.LoadData');

    setState(() {
      isLoading = true;
      _errorMessage = '';
    });

    try {
      developer.log('About to check connectivity...', name: 'EquipmentScreen.LoadData');

      final hasNetwork = await _checkNetworkConnectivity();
      developer.log('Connectivity check result: $hasNetwork', name: 'EquipmentScreen.LoadData');
      if (!hasNetwork) {
        developer.log('Connectivity check failed - skipping API calls', name: 'EquipmentScreen.LoadData');
        setState(() {
          _errorMessage = 'No internet connection detected. Backend ping failed. Check emulator network or backend server.';
          isLoading = false;
        });
        // TEMPORARY BYPASS: Uncomment the line below to skip the check and test API calls
        // return;  // Comment this out to force API calls even if check fails
      }

      developer.log('Connectivity OK - proceeding with API calls', name: 'EquipmentScreen.LoadData');

      final headers = {
        'Authorization': 'Bearer ${widget.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      developer.log('Request headers: $headers', name: 'EquipmentScreen.LoadData');

      developer.log('Making API calls to:', name: 'EquipmentScreen.LoadData');
      developer.log('  - Equipment: ${ApiConfig.equipment}', name: 'EquipmentScreen.LoadData');
      developer.log('  - Rooms: ${ApiConfig.rooms}', name: 'EquipmentScreen.LoadData');

      final stopwatch = Stopwatch()..start();

      final responses = await Future.wait([
        _makeHttpRequest(ApiConfig.equipment, headers, 'Equipment'),
        _makeHttpRequest(ApiConfig.rooms, headers, 'Rooms'),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          developer.log('API calls timed out after 15 seconds', name: 'EquipmentScreen.LoadData');
          throw Exception('Request timed out. Please check your connection.');
        },
      );

      stopwatch.stop();
      developer.log('API calls completed in ${stopwatch.elapsedMilliseconds}ms', name: 'EquipmentScreen.LoadData');

      await _processEquipmentResponse(responses[0]);
      await _processRoomsResponse(responses[1]);

      developer.log('=== DATA LOAD COMPLETED SUCCESSFULLY ===', name: 'EquipmentScreen.LoadData');
      developer.log('Equipment count: ${equipment.length}', name: 'EquipmentScreen.LoadData');
      developer.log('Rooms count: ${rooms.length}', name: 'EquipmentScreen.LoadData');

    } catch (e, stackTrace) {
      developer.log('=== DATA LOAD FAILED ===', name: 'EquipmentScreen.LoadData');
      developer.log('Error: $e', name: 'EquipmentScreen.LoadData');
      developer.log('Stack trace: $stackTrace', name: 'EquipmentScreen.LoadData');

      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<http.Response> _makeHttpRequest(String url, Map<String, String> headers, String requestName) async {
    developer.log('--- $requestName REQUEST START ---', name: 'EquipmentScreen.HTTP');
    developer.log('URL: $url', name: 'EquipmentScreen.HTTP');
    developer.log('Headers: $headers', name: 'EquipmentScreen.HTTP');

    final stopwatch = Stopwatch()..start();

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      stopwatch.stop();

      developer.log('--- $requestName RESPONSE ---', name: 'EquipmentScreen.HTTP');
      developer.log('Status Code: ${response.statusCode}', name: 'EquipmentScreen.HTTP');
      developer.log('Response Time: ${stopwatch.elapsedMilliseconds}ms', name: 'EquipmentScreen.HTTP');
      developer.log('Response Headers: ${response.headers}', name: 'EquipmentScreen.HTTP');
      developer.log('Response Body Length: ${response.body.length}', name: 'EquipmentScreen.HTTP');

      if (response.statusCode >= 400) {
        developer.log('ERROR RESPONSE BODY: ${response.body}', name: 'EquipmentScreen.HTTP');
      } else {
        final bodyPreview = response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body;
        developer.log('Response Body Preview: $bodyPreview', name: 'EquipmentScreen.HTTP');
      }

      return response;
    } catch (e, stackTrace) {
      stopwatch.stop();
      developer.log('--- $requestName REQUEST FAILED ---', name: 'EquipmentScreen.HTTP');
      developer.log('Error: $e', name: 'EquipmentScreen.HTTP');
      developer.log('Stack Trace: $stackTrace', name: 'EquipmentScreen.HTTP');
      rethrow;
    }
  }

  Future<void> _processEquipmentResponse(http.Response response) async {
    developer.log('--- PROCESSING EQUIPMENT RESPONSE ---', name: 'EquipmentScreen.Process');
    developer.log('Raw Response: ${response.body}', name: 'EquipmentScreen.Process');

    if (response.statusCode == 200) {
      try {
        final equipmentData = json.decode(response.body);
        developer.log('JSON parsed, type: ${equipmentData.runtimeType}', name: 'EquipmentScreen.Process');

        if (equipmentData is List) {
          developer.log('Equipment data is a List with ${equipmentData.length} items', name: 'EquipmentScreen.Process');
          for (int i = 0; i < equipmentData.length && i < 3; i++) {
            developer.log('Equipment[$i]: ${equipmentData[i]}', name: 'EquipmentScreen.Process');
          }
          setState(() {
            equipment = equipmentData;
          });
        } else if (equipmentData is Map) {
          developer.log('Equipment data is a Map: $equipmentData', name: 'EquipmentScreen.Process');
          final results = equipmentData['results'] ?? equipmentData['data'] ?? equipmentData['equipment'];
          if (results is List) {
            developer.log('Found results with ${results.length} items', name: 'EquipmentScreen.Process');
            setState(() {
              equipment = results;
            });
          } else {
            developer.log('No valid results in Map', name: 'EquipmentScreen.Process');
            setState(() {
              equipment = [];
            });
          }
        } else {
          developer.log('Unexpected data type: ${equipmentData.runtimeType}', name: 'EquipmentScreen.Process');
          setState(() {
            equipment = [];
          });
        }
      } catch (e, stackTrace) {
        developer.log('JSON parsing failed for equipment: $e', name: 'EquipmentScreen.Process');
        developer.log('Stack trace: $stackTrace', name: 'EquipmentScreen.Process');
        setState(() {
          _errorMessage = 'Failed to parse equipment data: $e';
        });
      }
    } else {
      developer.log('Equipment request failed with status: ${response.statusCode}', name: 'EquipmentScreen.Process');
      developer.log('Error response: ${response.body}', name: 'EquipmentScreen.Process');
      setState(() {
        _errorMessage = 'Failed to load equipment. Status: ${response.statusCode}\nResponse: ${response.body}';
      });
    }
  }

  Future<void> _processRoomsResponse(http.Response response) async {
    developer.log('--- PROCESSING ROOMS RESPONSE ---', name: 'EquipmentScreen.Process');

    if (response.statusCode == 200) {
      try {
        final roomsData = json.decode(response.body);
        developer.log('Rooms JSON parsed successfully', name: 'EquipmentScreen.Process');
        if (roomsData is List) {
          setState(() {
            rooms = roomsData;
          });
        } else if (roomsData is Map && roomsData.containsKey('results')) {
          setState(() {
            rooms = roomsData['results'] is List ? roomsData['results'] : [];
          });
        } else {
          developer.log('Unexpected rooms data format', name: 'EquipmentScreen.Process');
          setState(() {
            rooms = [];
          });
        }
      } catch (e) {
        developer.log('JSON parsing failed for rooms: $e', name: 'EquipmentScreen.Process');
      }
    } else {
      developer.log('Rooms request failed with status: ${response.statusCode}', name: 'EquipmentScreen.Process');
    }
  }

  Future<void> _deleteEquipment(String equipmentId, String equipmentName) async {
    developer.log('=== DELETE EQUIPMENT REQUEST ===', name: 'EquipmentScreen.Delete');
    developer.log('Equipment ID: $equipmentId', name: 'EquipmentScreen.Delete');
    developer.log('Equipment Name: $equipmentName', name: 'EquipmentScreen.Delete');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Equipment'),
          content: Text('Are you sure you want to delete "$equipmentName"?\n\nThis will also delete all sensor data associated with this equipment.'),
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
        final url = '${ApiConfig.equipment}$equipmentId/';
        final headers = {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        };

        developer.log('DELETE request URL: $url', name: 'EquipmentScreen.Delete');
        developer.log('DELETE request headers: $headers', name: 'EquipmentScreen.Delete');

        final response = await http.delete(
          Uri.parse(url),
          headers: headers,
        ).timeout(const Duration(seconds: 10));

        developer.log('DELETE response status: ${response.statusCode}', name: 'EquipmentScreen.Delete');
        developer.log('DELETE response body: ${response.body}', name: 'EquipmentScreen.Delete');

        if (response.statusCode == 204) {
          developer.log('Equipment deleted successfully', name: 'EquipmentScreen.Delete');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Equipment "$equipmentName" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          developer.log('Delete failed with status: ${response.statusCode}', name: 'EquipmentScreen.Delete');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete equipment. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e, stackTrace) {
        developer.log('Delete equipment error: $e', name: 'EquipmentScreen.Delete');
        developer.log('Stack trace: $stackTrace', name: 'EquipmentScreen.Delete');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting equipment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      developer.log('Delete cancelled by user', name: 'EquipmentScreen.Delete');
    }
  }

  void _showAddEditEquipmentDialog({Map<String, dynamic>? equipmentItem}) {
    developer.log('=== SHOW ADD/EDIT DIALOG ===', name: 'EquipmentScreen.Dialog');
    developer.log('Is editing: ${equipmentItem != null}', name: 'EquipmentScreen.Dialog');
    if (equipmentItem != null) {
      developer.log('Equipment item: $equipmentItem', name: 'EquipmentScreen.Dialog');
    }

    final isEditing = equipmentItem != null;
    final nameController = TextEditingController(text: equipmentItem?['name'] ?? '');
    final deviceIdController = TextEditingController(text: equipmentItem?['device_id'] ?? '');
    final qrCodeController = TextEditingController(text: equipmentItem?['qr_code'] ?? '');

    String selectedRoomId = equipmentItem?['room']?.toString() ?? '';
    String selectedStatus = equipmentItem?['status'] ?? 'offline';
    String selectedType = equipmentItem?['type'] ?? 'sensor';

    // Ensure the selected type exists in our options, otherwise default to 'sensor'
    if (!EQUIPMENT_TYPE_OPTIONS.any((option) => option['value'] == selectedType)) {
      developer.log('Invalid type "$selectedType", defaulting to "sensor"', name: 'EquipmentScreen.Dialog');
      selectedType = 'sensor';
    }

    developer.log('Dialog initial values:', name: 'EquipmentScreen.Dialog');
    developer.log('  - Room ID: $selectedRoomId', name: 'EquipmentScreen.Dialog');
    developer.log('  - Status: $selectedStatus', name: 'EquipmentScreen.Dialog');
    developer.log('  - Type: $selectedType', name: 'EquipmentScreen.Dialog');

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
                              isEditing ? 'Edit Equipment' : 'Add New Equipment',
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
                            // Equipment Name Field
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Equipment Name *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.devices),
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),

                            // Equipment Type Dropdown - Fixed overflow
                            DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Equipment Type *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                                isDense: true,
                              ),
                              isExpanded: true,
                              items: EQUIPMENT_TYPE_OPTIONS.map((option) => DropdownMenuItem<String>(
                                value: option['value'],
                                child: Container(
                                  width: double.infinity,
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
                              )).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedType = value ?? 'sensor';
                                });
                              },
                              selectedItemBuilder: (BuildContext context) {
                                return EQUIPMENT_TYPE_OPTIONS.map<Widget>((option) {
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      option['label']!,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            const SizedBox(height: 16),

                            // Device ID Field
                            TextField(
                              controller: deviceIdController,
                              decoration: const InputDecoration(
                                labelText: 'Device ID',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.memory),
                                hintText: 'e.g., ESP32_001',
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),

                            // QR Code Field
                            TextField(
                              controller: qrCodeController,
                              decoration: const InputDecoration(
                                labelText: 'QR Code',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.qr_code),
                                hintText: 'QR code identifier',
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),

                            // Room Assignment Dropdown
                            DropdownButtonFormField<String>(
                              value: selectedRoomId.isEmpty ? null : selectedRoomId,
                              decoration: const InputDecoration(
                                labelText: 'Assign to Room',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.room),
                                isDense: true,
                              ),
                              hint: const Text('Select a room (optional)'),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('No room assigned'),
                                ),
                                ...rooms.map((room) => DropdownMenuItem<String>(
                                  value: room['id'].toString(),
                                  child: Text(
                                    '${room['name']} (Floor ${room['floor']})',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                )).toList(),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedRoomId = value ?? '';
                                });
                              },
                              selectedItemBuilder: (BuildContext context) {
                                return [
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    child: const Text(
                                      'No room assigned',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  ...rooms.map<Widget>((room) {
                                    return Container(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${room['name']} (Floor ${room['floor']})',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }).toList(),
                                ];
                              },
                            ),
                            const SizedBox(height: 16),

                            // Status Dropdown - Fixed overflow
                            DropdownButtonFormField<String>(
                              value: selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.power_settings_new),
                                isDense: true,
                              ),
                              isExpanded: true,
                              items: EQUIPMENT_STATUS_OPTIONS.map((option) => DropdownMenuItem<String>(
                                value: option['value'],
                                child: Container(
                                  width: double.infinity,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(option['value']),
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
                              )).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedStatus = value ?? 'offline';
                                });
                              },
                              selectedItemBuilder: (BuildContext context) {
                                return EQUIPMENT_STATUS_OPTIONS.map<Widget>((option) {
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(option['value']),
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
                            const SizedBox(height: 12),

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
                              _saveEquipment(
                                equipmentId: equipmentItem?['id'],
                                name: nameController.text,
                                type: selectedType,
                                deviceId: deviceIdController.text,
                                qrCode: qrCodeController.text,
                                roomId: selectedRoomId.isEmpty ? null : selectedRoomId,
                                status: selectedStatus,
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
                            child: Text(isEditing ? 'Update' : 'Add'),
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

  Future<void> _saveEquipment({
    String? equipmentId,
    required String name,
    required String type,
    required String deviceId,
    required String qrCode,
    String? roomId,
    required String status,
    required bool isEditing,
  }) async {
    developer.log('=== SAVE EQUIPMENT REQUEST ===', name: 'EquipmentScreen.Save');
    developer.log('Is editing: $isEditing', name: 'EquipmentScreen.Save');
    developer.log('Equipment ID: $equipmentId', name: 'EquipmentScreen.Save');
    developer.log('Name: $name', name: 'EquipmentScreen.Save');
    developer.log('Type: $type', name: 'EquipmentScreen.Save');
    developer.log('Device ID: $deviceId', name: 'EquipmentScreen.Save');
    developer.log('QR Code: $qrCode', name: 'EquipmentScreen.Save');
    developer.log('Room ID: $roomId', name: 'EquipmentScreen.Save');
    developer.log('Status: $status', name: 'EquipmentScreen.Save');

    if (name.isEmpty || type.isEmpty) {
      developer.log('Validation failed: missing required fields', name: 'EquipmentScreen.Save');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in required fields (Name and Type)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final requestBody = <String, dynamic>{
        'name': name,
        'type': type,
        'device_id': deviceId.isEmpty ? null : deviceId,
        'qr_code': qrCode.isEmpty ? null : qrCode,
        'status': status,
      };

      if (roomId != null && roomId.isNotEmpty) {
        requestBody['room'] = roomId;
      }

      developer.log('Request body: $requestBody', name: 'EquipmentScreen.Save');

      final url = isEditing
          ? '${ApiConfig.equipment}$equipmentId/'
          : ApiConfig.equipment;

      developer.log('Request URL: $url', name: 'EquipmentScreen.Save');
      developer.log('Request method: ${isEditing ? 'PUT' : 'POST'}', name: 'EquipmentScreen.Save');

      final headers = {
        'Authorization': 'Bearer ${widget.accessToken}',
        'Content-Type': 'application/json',
      };

      developer.log('Request headers: $headers', name: 'EquipmentScreen.Save');

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

      developer.log('Save response status: ${response.statusCode}', name: 'EquipmentScreen.Save');
      developer.log('Save response body: ${response.body}', name: 'EquipmentScreen.Save');

      if (response.statusCode == 200 || response.statusCode == 201) {
        developer.log('Equipment saved successfully', name: 'EquipmentScreen.Save');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Equipment updated successfully' : 'Equipment added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else {
        developer.log('Save failed with status: ${response.statusCode}', name: 'EquipmentScreen.Save');
        try {
          final errorData = json.decode(response.body);
          developer.log('Error data: $errorData', name: 'EquipmentScreen.Save');

          String errorMessage = 'Failed to ${isEditing ? 'update' : 'add'} equipment.';
          if (errorData is Map && errorData.containsKey('device_id')) {
            errorMessage += ' Device ID already exists.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        } catch (e) {
          developer.log('Failed to parse error response: $e', name: 'EquipmentScreen.Save');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to ${isEditing ? 'update' : 'add'} equipment. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log('Save equipment error: $e', name: 'EquipmentScreen.Save');
      developer.log('Stack trace: $stackTrace', name: 'EquipmentScreen.Save');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${isEditing ? 'updating' : 'adding'} equipment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<dynamic> get filteredEquipment {
    final filtered = equipment.where((item) {
      bool roomMatch = _filterRoom == 'all' ||
          (_filterRoom == 'unassigned' && item['room'] == null) ||
          item['room']?.toString() == _filterRoom;

      bool typeMatch = _filterType == 'all' || item['type'] == _filterType;

      return roomMatch && typeMatch;
    }).toList();

    developer.log('Filtered equipment: ${filtered.length} items', name: 'EquipmentScreen.Filter');
    return filtered;
  }

  String _getRoomName(String? roomId) {
    if (roomId == null) return 'Unassigned';
    final room = rooms.firstWhere(
          (r) => r['id'].toString() == roomId.toString(),
      orElse: () => null,
    );
    return room != null ? room['name'] : 'Unknown Room';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      case 'maintenance':
        return Colors.orange;
      case 'error':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String? type) {
    final option = EQUIPMENT_TYPE_OPTIONS.firstWhere(
          (option) => option['value'] == type,
      orElse: () => {'value': type ?? '', 'label': type ?? 'Unknown'},
    );
    return option['label']!;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredEquipment;
    final onlineCount = equipment.where((e) => e['status'] == 'online').length;
    final esp32Count = equipment.where((e) => e['type']?.toLowerCase() == 'esp32').length;

    developer.log('Building UI with ${filtered.length} filtered items', name: 'EquipmentScreen.Build');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              // Show debug info dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Debug Info'),
                  content: SingleChildScrollView(
                    child: Text(
                      'Base URL: ${ApiConfig.baseUrl}\n'
                          'Token Length: ${widget.accessToken.length}\n'
                          'Equipment Count: ${equipment.length}\n'
                          'Rooms Count: ${rooms.length}\n'
                          'Error Message: $_errorMessage\n'
                          'Is Loading: $isLoading',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Debug Info',
          ),
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
                                Icon(Icons.devices, color: Colors.blue[700], size: 24),
                                const SizedBox(height: 4),
                                FittedBox(
                                  child: Text(
                                    '${equipment.length}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const FittedBox(
                                  child: Text('Total Equipment', style: TextStyle(fontSize: 12)),
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
                                Icon(Icons.online_prediction, color: Colors.green[700], size: 24),
                                const SizedBox(height: 4),
                                FittedBox(
                                  child: Text(
                                    '$onlineCount',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const FittedBox(
                                  child: Text('Online', style: TextStyle(fontSize: 12)),
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
                                Icon(Icons.memory, color: Colors.purple[700], size: 24),
                                const SizedBox(height: 4),
                                FittedBox(
                                  child: Text(
                                    '$esp32Count',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const FittedBox(
                                  child: Text('ESP32 Devices', style: TextStyle(fontSize: 12)),
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
          if (_filterRoom != 'all' || _filterType != 'all')
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_filterRoom != 'all')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('Room: ${_filterRoom == 'unassigned' ? 'Unassigned' : _getRoomName(_filterRoom)}'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _filterRoom = 'all'),
                        ),
                      ),
                    if (_filterType != 'all')
                      Chip(
                        label: Text('Type: ${_getTypeLabel(_filterType)}'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _filterType = 'all'),
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

          // Equipment List
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
                    const Icon(Icons.devices_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      equipment.isEmpty ? 'No Equipment Found' : 'No Equipment Match Filters',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      equipment.isEmpty ? 'Add your first equipment to get started' : 'Try adjusting your filters',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditEquipmentDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Equipment'),
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
                  final item = filtered[index];
                  final statusColor = _getStatusColor(item['status']);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.2),
                        child: Icon(
                          Icons.devices,
                          color: statusColor,
                        ),
                      ),
                      title: Text(
                        item['name'] ?? 'Unknown Equipment',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type: ${_getTypeLabel(item['type'])} • Room: ${_getRoomName(item['room']?.toString())}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item['device_id'] != null)
                            Text(
                              'Device ID: ${item['device_id']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item['status']?.toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAddEditEquipmentDialog(equipmentItem: item);
                          } else if (value == 'delete') {
                            _deleteEquipment(item['id'], item['name']);
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
        onPressed: () => _showAddEditEquipmentDialog(),
        tooltip: 'Add Equipment',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempFilterRoom = _filterRoom;
        String tempFilterType = _filterType;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
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
                              'Filter Equipment',
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
                              value: tempFilterRoom,
                              decoration: const InputDecoration(
                                labelText: 'Filter by Room',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'all',
                                  child: Text('All Rooms'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'unassigned',
                                  child: Text('Unassigned'),
                                ),
                                ...rooms.map((room) => DropdownMenuItem<String>(
                                  value: room['id'].toString(),
                                  child: Text(
                                    room['name'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )).toList(),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  tempFilterRoom = value ?? 'all';
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: tempFilterType,
                              decoration: const InputDecoration(
                                labelText: 'Filter by Type',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'all',
                                  child: Text('All Types'),
                                ),
                                ...EQUIPMENT_TYPE_OPTIONS.map((option) => DropdownMenuItem<String>(
                                  value: option['value'],
                                  child: Text(
                                    option['label']!,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )).toList(),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  tempFilterType = value ?? 'all';
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
                                _filterRoom = 'all';
                                _filterType = 'all';
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Clear'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _filterRoom = tempFilterRoom;
                                _filterType = tempFilterType;
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