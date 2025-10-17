import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RoomManagementWidgets {
  static Widget buildDialogHeader(BuildContext context, {String title = '', IconData icon = Icons.meeting_room}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1E23),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF184BFB), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  static Widget buildDialogFooter(
      BuildContext context, {
        required VoidCallback onAction,
        String actionText = 'Save',
        VoidCallback? onCancel,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onCancel ?? () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF184BFB),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              actionText,
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildAddEditRoomDialog(
      BuildContext context, {
        required bool isEditing,
        Map<String, dynamic>? room,
        required List<Map<String, String>> roomTypeOptions,
        required Function(String?, String, String, String, String) onSave,
        required VoidCallback onCancel,
      }) {
    final nameController = TextEditingController(text: room?['name'] ?? '');
    final floorController = TextEditingController(text: room?['floor']?.toString() ?? '');
    final capacityController = TextEditingController(text: room?['capacity']?.toString() ?? '');
    String selectedType = room?['type'] ?? roomTypeOptions.first['value']!;
    String? nameError;
    String? floorError;
    String? capacityError;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        void validateInputs() {
          setDialogState(() {
            nameError = nameController.text.isEmpty ? 'Room name is required' : null;
            floorError = int.tryParse(floorController.text) == null ? 'Enter a valid floor number' : null;
            capacityError = int.tryParse(capacityController.text) == null || int.parse(capacityController.text) <= 0
                ? 'Enter a valid capacity (greater than 0)'
                : null;
          });
        }

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7, maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildDialogHeader(
                context,
                title: isEditing ? 'Edit Room' : 'Add Room',
                icon: Icons.meeting_room,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room Details',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Room Name *',
                        labelStyle: GoogleFonts.urbanist(color: Colors.white70, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF121822),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF184BFB)),
                        ),
                        errorText: nameError,
                        errorStyle: GoogleFonts.urbanist(color: Colors.red, fontSize: 12),
                        prefixIcon: const Icon(Icons.room, color: Colors.white70),
                      ),
                      onChanged: (_) => validateInputs(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: floorController,
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Floor Number *',
                        labelStyle: GoogleFonts.urbanist(color: Colors.white70, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF121822),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF184BFB)),
                        ),
                        errorText: floorError,
                        errorStyle: GoogleFonts.urbanist(color: Colors.red, fontSize: 12),
                        prefixIcon: const Icon(Icons.layers, color: Colors.white70),
                      ),
                      onChanged: (_) => validateInputs(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: capacityController,
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Capacity *',
                        labelStyle: GoogleFonts.urbanist(color: Colors.white70, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF121822),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF184BFB)),
                        ),
                        errorText: capacityError,
                        errorStyle: GoogleFonts.urbanist(color: Colors.red, fontSize: 12),
                        prefixIcon: const Icon(Icons.people, color: Colors.white70),
                      ),
                      onChanged: (_) => validateInputs(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Room Type *',
                        labelStyle: GoogleFonts.urbanist(color: Colors.white70, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF121822),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF184BFB)),
                        ),
                        prefixIcon: const Icon(Icons.category, color: Colors.white70),
                      ),
                      dropdownColor: const Color(0xFF121822),
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                      items: roomTypeOptions
                          .map((option) => DropdownMenuItem(
                        value: option['value'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              option['label']!,
                              style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              option['description']!,
                              style: GoogleFonts.urbanist(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value ?? roomTypeOptions.first['value']!;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '* Required fields',
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              buildDialogFooter(
                context,
                actionText: isEditing ? 'Update' : 'Add',
                onAction: () {
                  validateInputs();
                  if (nameError == null && floorError == null && capacityError == null) {
                    onSave(
                      room?['id']?.toString(),
                      nameController.text,
                      floorController.text,
                      capacityController.text,
                      selectedType,
                    );
                  }
                },
                onCancel: onCancel,
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget buildCustomFAB({
    required VoidCallback? onPressed,
    required String tooltip,
    required bool isEnabled,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(isEnabled ? 1.0 : 0.95),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isEnabled
                ? const LinearGradient(
              colors: [Color(0xFF184BFB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : const LinearGradient(
              colors: [Colors.grey, Colors.grey],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Tooltip(
            message: tooltip,
            textStyle: GoogleFonts.urbanist(color: Colors.white, fontSize: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1E23),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add_circle,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  static Widget buildErrorBanner(String errorMessage) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: GoogleFonts.urbanist(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildEmptyState({
    required VoidCallback onAddRoom,
    required bool isRefreshingToken,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.meeting_room_outlined, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            'No Rooms Found',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first room to get started',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isRefreshingToken ? null : onAddRoom,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Add Room',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRefreshingToken ? Colors.grey : const Color(0xFF184BFB),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildRoomList({
    required List<dynamic> rooms,
    required Function(String, String) onDeleteRoom,
    required Function(Map<String, dynamic>) onEditRoom,
    required Function(String?) getRoomTypeLabel,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Card(
          color: const Color(0xFF121822),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF184BFB).withOpacity(0.2),
                child: Text(
                  room['floor']?.toString() ?? '?',
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF184BFB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                room['name'] ?? 'Unknown Room',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Floor ${room['floor']} • ${getRoomTypeLabel(room['type'])}',
                    style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                  ),
                  Text(
                    'Capacity: ${room['capacity']} people',
                    style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEditRoom(room);
                  } else if (value == 'delete') {
                    onDeleteRoom(room['id'].toString(), room['name'] ?? 'Unknown');
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: GoogleFonts.urbanist(fontSize: 14, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                color: const Color(0xFF1F1E23),
              ),
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }

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
              color: const Color(0xFF121822),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.room, color: Color(0xFF184BFB), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '$roomCount',
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Rooms',
                      style: GoogleFonts.urbanist(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              color: const Color(0xFF121822),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.layers, color: Color(0xFF184BFB), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '$floorCount',
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Floors',
                      style: GoogleFonts.urbanist(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              color: const Color(0xFF121822),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people, color: Color(0xFF184BFB), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '$totalCapacity',
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Capacity',
                      style: GoogleFonts.urbanist(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildDeleteConfirmationDialog({
    required String roomName,
    required VoidCallback onConfirm,
  }) {
    return Builder(
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E1E1E),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogHeader(
              context,
              title: 'Delete Room',
              icon: Icons.delete,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Are you sure you want to delete "$roomName"? This will also delete all equipment assigned to this room.',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ),
            buildDialogFooter(
              context,
              actionText: 'Delete',
              onAction: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        ),
      ),
    );
  }
}