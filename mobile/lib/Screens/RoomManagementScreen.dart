import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Config/api.dart'; // Updated import to point to ../Config/api.dart

class RoomManagementScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const RoomManagementScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  List<dynamic> rooms = [];
  bool isLoading = true;
  String _errorMessage = '';

  // Standardized room type options - use these across web and mobile
  static const List<Map<String, String>> ROOM_TYPE_OPTIONS = [
    {'value': 'office', 'label': 'Office', 'description': 'Office spaces'},
    {'value': 'lab', 'label': 'Laboratory', 'description': 'Laboratory and research spaces'},
    {'value': 'meeting', 'label': 'Meeting Room', 'description': 'Conference and meeting rooms'},
    {'value': 'storage', 'label': 'Storage', 'description': 'Storage areas and warehouses'},
    {'value': 'corridor', 'label': 'Corridor', 'description': 'Hallways and corridors'},
    {'value': 'utility', 'label': 'Utility', 'description': 'Utility and service rooms'},
  ];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.rooms),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final roomsData = json.decode(response.body);
        setState(() {
          rooms = roomsData is List ? roomsData : [];
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load rooms. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading rooms: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteRoom(String roomId, String roomName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Room'),
          content: Text('Are you sure you want to delete "$roomName"?\n\nThis will also delete all equipment assigned to this room.'),
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
          Uri.parse('${ApiConfig.rooms}$roomId/'),
          headers: {
            'Authorization': 'Bearer ${widget.accessToken}',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Room "$roomName" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadRooms(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete room. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddEditRoomDialog({Map<String, dynamic>? room}) {
    final isEditing = room != null;
    final nameController = TextEditingController(text: room?['name'] ?? '');
    final floorController = TextEditingController(text: room?['floor']?.toString() ?? '');
    final capacityController = TextEditingController(text: room?['capacity']?.toString() ?? '');

    String selectedType = room?['type'] ?? 'office';

    // Ensure the selected type exists in our options, otherwise default to 'office'
    if (!ROOM_TYPE_OPTIONS.any((option) => option['value'] == selectedType)) {
      selectedType = 'office';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Room' : 'Add New Room'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Room Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.room),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: floorController,
                        decoration: const InputDecoration(
                          labelText: 'Floor *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.layers),
                          hintText: 'e.g., 1, 2, 3',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Capacity *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people),
                          hintText: 'Number of people',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      // Replace TextField with DropdownButtonFormField for Room Type
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Room Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: ROOM_TYPE_OPTIONS.map((option) => DropdownMenuItem<String>(
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
                            selectedType = value ?? 'office';
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
                    _saveRoom(
                      roomId: room?['id'],
                      name: nameController.text,
                      floor: floorController.text,
                      capacity: capacityController.text,
                      type: selectedType,
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

  Future<void> _saveRoom({
    String? roomId,
    required String name,
    required String floor,
    required String capacity,
    required String type,
    required bool isEditing,
  }) async {
    // Validate inputs
    if (name.isEmpty || floor.isEmpty || capacity.isEmpty || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate numeric inputs
    int? floorNumber = int.tryParse(floor);
    int? capacityNumber = int.tryParse(capacity);

    if (floorNumber == null || capacityNumber == null || capacityNumber <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid numbers for floor and capacity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final requestBody = {
        'name': name,
        'floor': floorNumber,
        'capacity': capacityNumber,
        'type': type,
      };

      final url = isEditing
          ? '${ApiConfig.rooms}$roomId/'
          : ApiConfig.rooms;

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
            content: Text(isEditing ? 'Room updated successfully' : 'Room added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRooms(); // Refresh the list
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to ${isEditing ? 'update' : 'add'} room.';
        if (errorData is Map && errorData.containsKey('name')) {
          errorMessage += ' Room name already exists.';
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
          content: Text('Error ${isEditing ? 'updating' : 'adding'} room: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getRoomTypeLabel(String? type) {
    final option = ROOM_TYPE_OPTIONS.firstWhere(
          (option) => option['value'] == type,
      orElse: () => {'value': type ?? '', 'label': type ?? 'Unknown'},
    );
    return option['label']!;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate some statistics
    final totalCapacity = rooms.fold<int>(0, (sum, room) => sum + (room['capacity'] as int? ?? 0));
    final floorCount = rooms.map((room) => room['floor']).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Summary Cards
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
                          Icon(Icons.room, color: Colors.blue[700], size: 24),
                          const SizedBox(height: 4),
                          Text(
                            '${rooms.length}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('Total Rooms', style: TextStyle(fontSize: 12)),
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
                          Icon(Icons.layers, color: Colors.green[700], size: 24),
                          const SizedBox(height: 4),
                          Text(
                            '$floorCount',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('Floors', style: TextStyle(fontSize: 12)),
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
                          Icon(Icons.people, color: Colors.orange[700], size: 24),
                          const SizedBox(height: 4),
                          Text(
                            '$totalCapacity',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('Total Capacity', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
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

          // Rooms List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : rooms.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.room_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No Rooms Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Add your first room to get started'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditRoomDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Room'),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadRooms,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          room['floor']?.toString() ?? '?',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        room['name'] ?? 'Unknown Room',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Floor ${room['floor']} • ${_getRoomTypeLabel(room['type'])}'),
                          Text('Capacity: ${room['capacity']} people'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAddEditRoomDialog(room: room);
                          } else if (value == 'delete') {
                            _deleteRoom(room['id'], room['name']);
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
        onPressed: () => _showAddEditRoomDialog(),
        tooltip: 'Add Room',
        child: const Icon(Icons.add),
      ),
    );
  }
}