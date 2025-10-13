import 'package:flutter/material.dart';

class RoomManagementWidgets {
  // Summary Cards Widget
  static Widget buildSummaryCards({
    required int roomCount,
    required int floorCount,
    required int totalCapacity,
  }) {
    return Container(
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
                      '$roomCount',
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
    );
  }

  // Error Banner Widget
  static Widget buildErrorBanner(String errorMessage) {
    return Container(
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
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Empty State Widget
  static Widget buildEmptyState({
    required VoidCallback onAddRoom,
    required bool isRefreshingToken,
  }) {
    return Center(
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
            onPressed: isRefreshingToken ? null : onAddRoom,
            icon: const Icon(Icons.add),
            label: const Text('Add Room'),
          ),
        ],
      ),
    );
  }

  // Room List Widget
  static Widget buildRoomList({
    required List<dynamic> rooms,
    required Function(String, String) onDeleteRoom,
    required Function(Map<String, dynamic>) onEditRoom,
    required Function(String?) getRoomTypeLabel,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        // This will be handled by the parent widget
      },
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
                  Text('Floor ${room['floor']} • ${getRoomTypeLabel(room['type'])}'),
                  Text('Capacity: ${room['capacity']} people'),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEditRoom(room);
                  } else if (value == 'delete') {
                    onDeleteRoom(room['id'], room['name']);
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
    );
  }

  // Add/Edit Room Dialog Widget
  static Widget buildAddEditRoomDialog({
    required bool isEditing,
    required Map<String, dynamic>? room,
    required List<Map<String, String>> roomTypeOptions,
    required Function(String?, String, String, String, String, bool) onSave,
  }) {
    final nameController = TextEditingController(text: room?['name'] ?? '');
    final floorController = TextEditingController(text: room?['floor']?.toString() ?? '');
    final capacityController = TextEditingController(text: room?['capacity']?.toString() ?? '');

    String selectedType = room?['type'] ?? 'office';

    if (!roomTypeOptions.any((option) => option['value'] == selectedType)) {
      selectedType = 'office';
    }

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
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Room Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: roomTypeOptions.map((option) => DropdownMenuItem<String>(
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
                onSave(
                  room?['id'],
                  nameController.text,
                  floorController.text,
                  capacityController.text,
                  selectedType,
                  isEditing,
                );
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  // Delete Confirmation Dialog Widget
  static Widget buildDeleteConfirmationDialog({
    required String roomName,
    required VoidCallback onConfirm,
  }) {
    return Builder(
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "$roomName"?\n\nThis will also delete all equipment assigned to this room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
