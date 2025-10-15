import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import '../Config/api.dart';
import '../Services/auth_service.dart';
import '../Widgets/EquipmentManagementWidgets.dart';

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
  bool isRefreshingToken = false;
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
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
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

  Future<bool> _checkNetworkConnectivity() async {
    developer.log('=== CHECKING NETWORK CONNECTIVITY ===', name: 'EquipmentScreen.Network');
    try {
      final backendResponse = await http.get(Uri.parse(ApiConfig.baseUrl)).timeout(const Duration(seconds: 5));
      if (backendResponse.statusCode >= 200 && backendResponse.statusCode < 300) {
        developer.log('Backend reachable: ${ApiConfig.baseUrl} (Status: ${backendResponse.statusCode})', name: 'EquipmentScreen.Network');
        return true;
      }
      developer.log('Backend ping failed (Status: ${backendResponse.statusCode}), falling back to google.com', name: 'EquipmentScreen.Network');
    } catch (e) {
      developer.log('Backend ping failed: $e, falling back to google.com', name: 'EquipmentScreen.Network');
    }

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

  Future<bool> _refreshToken() async {
    setState(() {
      isRefreshingToken = true;
      _errorMessage = 'Refreshing session...';
    });
    try {
      final success = await AuthService().refresh();
      if (success) {
        developer.log('Token refreshed successfully', name: 'EquipmentScreen.Auth');
        return true;
      }
      setState(() {
        _errorMessage = 'Failed to refresh session. Please log in again.';
      });
      developer.log('Token refresh failed', name: 'EquipmentScreen.Auth');
      return false;
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Error refreshing session: $e';
      });
      developer.log('Token refresh error: $e', name: 'EquipmentScreen.Auth');
      developer.log('Stack trace: $stackTrace', name: 'EquipmentScreen.Auth');
      return false;
    } finally {
      setState(() {
        isRefreshingToken = false;
      });
    }
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
        // TEMPORARY BYPASS: Comment out to force API calls even if check fails
        // return;
      }

      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
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
        _errorMessage = e.toString().contains('Session expired') ? e.toString() : 'Error loading data: $e';
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
        if (response.statusCode == 401) {
          if (await _refreshToken()) {
            final newHeaders = AuthService().getAuthHeaders();
            developer.log('Retrying $requestName with new token', name: 'EquipmentScreen.HTTP');
            return await _makeHttpRequest(url, newHeaders, requestName);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        }
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
        if (!(await AuthService().ensureValidToken())) {
          throw Exception('Session expired. Please log in again.');
        }
        final url = '${ApiConfig.equipment}$equipmentId/';
        final headers = AuthService().getAuthHeaders();

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
        } else if (response.statusCode == 401) {
          if (await _refreshToken()) {
            return _deleteEquipment(equipmentId, equipmentName);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
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
            return EquipmentManagementWidgets.buildAddEditEquipmentDialog(
              context,
              isEditing: isEditing,
              equipmentItem: equipmentItem,
              rooms: rooms,
              equipmentTypeOptions: EQUIPMENT_TYPE_OPTIONS,
              equipmentStatusOptions: EQUIPMENT_STATUS_OPTIONS,
              nameController: nameController,
              deviceIdController: deviceIdController,
              qrCodeController: qrCodeController,
              selectedRoomId: selectedRoomId,
              selectedStatus: selectedStatus,
              selectedType: selectedType,
              onRoomChanged: (value) => setDialogState(() => selectedRoomId = value),
              onStatusChanged: (value) => setDialogState(() => selectedStatus = value),
              onTypeChanged: (value) => setDialogState(() => selectedType = value),
              onSave: () {
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
              onCancel: () => Navigator.of(context).pop(),
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
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
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
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _saveEquipment(
            equipmentId: equipmentId,
            name: name,
            type: type,
            deviceId: deviceId,
            qrCode: qrCode,
            roomId: roomId,
            status: status,
            isEditing: isEditing,
          );
        } else {
          throw Exception('Session expired. Please log in again.');
        }
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EquipmentManagementWidgets.buildFilterDialog(
          context,
          currentFilterRoom: _filterRoom,
          currentFilterType: _filterType,
          rooms: rooms,
          equipmentTypeOptions: EQUIPMENT_TYPE_OPTIONS,
          onFilterRoomChanged: (value) => _filterRoom = value,
          onFilterTypeChanged: (value) => _filterType = value,
          onApply: () => Navigator.of(context).pop(),
          onClear: () => Navigator.of(context).pop(),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredEquipment;
    final onlineCount = equipment.where((e) => e['status'] == 'online').length;
    final esp32Count = equipment.where((e) => e['type']?.toLowerCase() == 'esp32').length;

    developer.log('Building UI with ${filtered.length} filtered items', name: 'EquipmentScreen.Build');

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Equipment Management',
          style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),),
        backgroundColor: const Color(0xFF1F1E23),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => EquipmentManagementWidgets.buildDebugDialog(
                  context,
                  baseUrl: ApiConfig.baseUrl,
                  tokenLength: AuthService().accessToken?.length ?? widget.accessToken.length,
                  equipmentCount: equipment.length,
                  roomsCount: rooms.length,
                  errorMessage: _errorMessage,
                  isLoading: isLoading,
                  isRefreshingToken: isRefreshingToken,
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
            onPressed: isRefreshingToken ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          EquipmentManagementWidgets.buildSummaryCards(context, equipment.length, onlineCount, esp32Count),
          EquipmentManagementWidgets.buildFilterChips(
            context,
            filterRoom: _filterRoom,
            filterType: _filterType,
            getRoomName: _getRoomName,
            getTypeLabel: _getTypeLabel,
            onRemoveRoomFilter: () => setState(() => _filterRoom = 'all'),
            onRemoveTypeFilter: () => setState(() => _filterType = 'all'),
          ),
          if (_errorMessage.isNotEmpty)
            EquipmentManagementWidgets.buildErrorBanner(context, _errorMessage),
          Expanded(
            child: isLoading || isRefreshingToken
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? EquipmentManagementWidgets.buildEmptyState(
              context,
              hasEquipment: equipment.isNotEmpty,
              onAddEquipment: () => _showAddEditEquipmentDialog(),
            )
                : EquipmentManagementWidgets.buildEquipmentList(
              context,
              equipmentList: filtered.cast<Map<String, dynamic>>(),
              getRoomName: _getRoomName,
              getTypeLabel: _getTypeLabel,
              getStatusColor: _getStatusColor,
              onEdit: (equipment) => _showAddEditEquipmentDialog(equipmentItem: equipment),
              onDelete: (equipmentId, equipmentName) => _deleteEquipment(equipmentId, equipmentName),
              onRefresh: _loadData,
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
}