import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  final String baseUrl = 'http://10.0.2.2:8000/api';

  // Standardized field values - use these across web and mobile
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      _errorMessage = '';
    });

    try {
      final headers = {
        'Authorization': 'Bearer ${widget.accessToken}',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/equipment/'), headers: headers),
        http.get(Uri.parse('$baseUrl/rooms/'), headers: headers),
      ]).timeout(const Duration(seconds: 10));

      if (responses[0].statusCode == 200) {
        final equipmentData = json.decode(responses[0].body);
        setState(() {
          equipment = equipmentData is List ? equipmentData : [];
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load equipment. Status: ${responses[0].statusCode}';
        });
      }

      if (responses[1].statusCode == 200) {
        final roomsData = json.decode(responses[1].body);
        setState(() {
          rooms = roomsData is List ? roomsData : [];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteEquipment(String equipmentId, String equipmentName) async {
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
        final response = await http.delete(
          Uri.parse('$baseUrl/equipment/$equipmentId/'),
          headers: {
            'Authorization': 'Bearer ${widget.accessToken}',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Equipment "$equipmentName" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete equipment. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting equipment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddEditEquipmentDialog({Map<String, dynamic>? equipmentItem}) {
    final isEditing = equipmentItem != null;
    final nameController = TextEditingController(text: equipmentItem?['name'] ?? '');
    final deviceIdController = TextEditingController(text: equipmentItem?['device_id'] ?? '');
    final qrCodeController = TextEditingController(text: equipmentItem?['qr_code'] ?? '');

    String selectedRoomId = equipmentItem?['room']?.toString() ?? '';
    String selectedStatus = equipmentItem?['status'] ?? 'offline';
    String selectedType = equipmentItem?['type'] ?? 'sensor';

    // Ensure the selected type exists in our options, otherwise default to 'sensor'
    if (!EQUIPMENT_TYPE_OPTIONS.any((option) => option['value'] == selectedType)) {
      selectedType = 'sensor';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Equipment' : 'Add New Equipment'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Equipment Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.devices),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Fixed Equipment Type Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Equipment Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: EQUIPMENT_TYPE_OPTIONS.map((option) => DropdownMenuItem<String>(
                          value: option['value'],
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 250),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  option['label']!,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  option['description']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
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
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: deviceIdController,
                        decoration: const InputDecoration(
                          labelText: 'Device ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.memory),
                          hintText: 'e.g., ESP32_001',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: qrCodeController,
                        decoration: const InputDecoration(
                          labelText: 'QR Code',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code),
                          hintText: 'QR code identifier',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRoomId.isEmpty ? null : selectedRoomId,
                        decoration: const InputDecoration(
                          labelText: 'Assign to Room',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.room),
                        ),
                        hint: const Text('Select a room (optional)'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('No room assigned'),
                          ),
                          ...rooms.map((room) => DropdownMenuItem<String>(
                            value: room['id'].toString(),
                            child: Text('${room['name']} (Floor ${room['floor']})'),
                          )).toList(),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRoomId = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Fixed Status Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.power_settings_new),
                        ),
                        items: EQUIPMENT_STATUS_OPTIONS.map((option) => DropdownMenuItem<String>(
                          value: option['value'],
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 250),
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
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        option['label']!,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        option['description']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
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
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '* Required fields',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
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
                  child: Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
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
    if (name.isEmpty || type.isEmpty) {
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

      final url = isEditing
          ? '$baseUrl/equipment/$equipmentId/'
          : '$baseUrl/equipment/';

      final response = isEditing
          ? await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10))
          : await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Equipment updated successfully' : 'Equipment added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else {
        final errorData = json.decode(response.body);
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
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${isEditing ? 'updating' : 'adding'} equipment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<dynamic> get filteredEquipment {
    return equipment.where((item) {
      bool roomMatch = _filterRoom == 'all' ||
          (_filterRoom == 'unassigned' && item['room'] == null) ||
          item['room']?.toString() == _filterRoom;

      bool typeMatch = _filterType == 'all' || item['type'] == _filterType;

      return roomMatch && typeMatch;
    }).toList();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Management'),
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
          // Summary Cards
          Container(
            height: 120,
            margin: const EdgeInsets.all(16),
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
                          Text(
                            '${equipment.length}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('Total Equipment', style: TextStyle(fontSize: 12)),
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
                          Text(
                            '$onlineCount',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('Online', style: TextStyle(fontSize: 12)),
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
                          Text(
                            '$esp32Count',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('ESP32 Devices', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          if (_filterRoom != 'all' || _filterType != 'all')
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
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

          // Error Message
          if (_errorMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.devices_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    equipment.isEmpty ? 'No Equipment Found' : 'No Equipment Match Filters',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(equipment.isEmpty ? 'Add your first equipment to get started' : 'Try adjusting your filters'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditEquipmentDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Equipment'),
                  ),
                ],
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
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Type: ${_getTypeLabel(item['type'])} • Room: ${_getRoomName(item['room']?.toString())}'),
                          if (item['device_id'] != null)
                            Text('Device ID: ${item['device_id']}'),
                          Row(
                            children: [
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
            return AlertDialog(
              title: const Text('Filter Equipment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tempFilterRoom,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Room',
                      border: OutlineInputBorder(),
                    ),
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
                        child: Text(room['name']),
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
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('All Types'),
                      ),
                      ...EQUIPMENT_TYPE_OPTIONS.map((option) => DropdownMenuItem<String>(
                        value: option['value'],
                        child: Text(option['label']!),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
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
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterRoom = tempFilterRoom;
                      _filterType = tempFilterType;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}