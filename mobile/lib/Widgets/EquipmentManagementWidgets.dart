import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EquipmentManagementWidgets {
  static Widget buildDialogHeader(
      BuildContext context, {String title = '', IconData icon = Icons.devices}) {
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
        String? secondaryActionText,
        VoidCallback? onSecondaryAction,
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
          if (secondaryActionText != null && onSecondaryAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(
                secondaryActionText,
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
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

  static Widget buildAddEditEquipmentDialog(
      BuildContext context, {
        required bool isEditing,
        required Map<String, dynamic>? equipmentItem,
        required List<dynamic> rooms,
        required List<Map<String, String>> equipmentTypeOptions,
        required List<Map<String, String>> equipmentStatusOptions,
        required Function(String?, String, String, String, String, String?, String) onSave,
        required VoidCallback onCancel,
      }) {
    final nameController = TextEditingController(text: equipmentItem?['name'] ?? '');
    final deviceIdController = TextEditingController(text: equipmentItem?['device_id'] ?? '');
    final qrCodeController = TextEditingController(text: equipmentItem?['qr_code'] ?? '');
    String selectedRoomId = equipmentItem?['room']?.toString() ?? '';
    String selectedStatus = equipmentItem?['status'] ?? 'offline';
    String selectedType = equipmentItem?['type'] ?? 'sensor';
    String? nameError;
    String? typeError;

    if (!equipmentTypeOptions.any((option) => option['value'] == selectedType)) {
      selectedType = 'sensor';
    }

    return Container(
      width: double.infinity, // Ensure dialog takes full width within constraints
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 400,
        minWidth: 300, // Add minimum width to prevent collapse
      ),
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          void validateInputs() {
            setDialogState(() {
              nameError = nameController.text.isEmpty ? 'Equipment name is required' : null;
              typeError = selectedType.isEmpty ? 'Equipment type is required' : null;
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildDialogHeader(
                context,
                title: isEditing ? 'Edit Equipment' : 'Add Equipment',
                icon: Icons.devices,
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360), // Constrain inner content width
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Equipment Details',
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
                              labelText: 'Equipment Name *',
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
                              prefixIcon: const Icon(Icons.devices, color: Colors.white70),
                            ),
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => validateInputs(),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: InputDecoration(
                              labelText: 'Equipment Type *',
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
                              errorText: typeError,
                              errorStyle: GoogleFonts.urbanist(color: Colors.red, fontSize: 12),
                              prefixIcon: const Icon(Icons.category, color: Colors.white70),
                            ),
                            dropdownColor: const Color(0xFF121822),
                            style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                            isExpanded: true, // Ensure dropdown takes available width
                            items: equipmentTypeOptions
                                .map((option) => DropdownMenuItem(
                              value: option['value'],
                              child: Text(
                                option['label']!,
                                style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedType = value ?? 'sensor';
                              });
                              validateInputs();
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: deviceIdController,
                            style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Device ID',
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
                              prefixIcon: const Icon(Icons.memory, color: Colors.white70),
                              hintText: 'e.g., ESP32_001',
                              hintStyle: GoogleFonts.urbanist(color: Colors.white70, fontSize: 14),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: qrCodeController,
                            style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'QR Code',
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
                              prefixIcon: const Icon(Icons.qr_code, color: Colors.white70),
                              hintText: 'QR code identifier',
                              hintStyle: GoogleFonts.urbanist(color: Colors.white70, fontSize: 14),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedRoomId.isEmpty ? null : selectedRoomId,
                            decoration: InputDecoration(
                              labelText: 'Assign to Room',
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
                              prefixIcon: const Icon(Icons.room, color: Colors.white70),
                              hintText: 'Select a room (optional)',
                              hintStyle: GoogleFonts.urbanist(color: Colors.white70, fontSize: 14),
                            ),
                            dropdownColor: const Color(0xFF121822),
                            style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
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
                                  style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                selectedRoomId = value ?? '';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: InputDecoration(
                              labelText: 'Status',
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
                              prefixIcon: const Icon(Icons.power_settings_new, color: Colors.white70),
                            ),
                            dropdownColor: const Color(0xFF121822),
                            style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                            isExpanded: true,
                            items: equipmentStatusOptions
                                .map((option) => DropdownMenuItem(
                              value: option['value'],
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
                                    child: Text(
                                      option['label']!,
                                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedStatus = value ?? 'offline';
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
                  ),
                ),
              ),
              buildDialogFooter(
                context,
                actionText: isEditing ? 'Update' : 'Add',
                onAction: () {
                  validateInputs();
                  if (nameError == null && typeError == null) {
                    onSave(
                      equipmentItem?['id']?.toString(),
                      nameController.text,
                      selectedType,
                      deviceIdController.text,
                      qrCodeController.text,
                      selectedRoomId.isEmpty ? null : selectedRoomId,
                      selectedStatus,
                    );
                  }
                },
                onCancel: onCancel,
              ),
            ],
          );
        },
      ),
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
    required VoidCallback onAddEquipment,
    required bool hasEquipment,
    required bool isRefreshingToken,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.devices_outlined, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            hasEquipment ? 'No Equipment Match Filters' : 'No Equipment Found',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasEquipment ? 'Try adjusting your filters' : 'Add your first equipment to get started',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isRefreshingToken ? null : onAddEquipment,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Add Equipment',
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

  static Widget buildEquipmentList({
    required List<Map<String, dynamic>> equipmentList,
    required String Function(String?) getRoomName,
    required String Function(String?) getTypeLabel,
    required Color Function(String?) getStatusColor,
    required Function(Map<String, dynamic>) onEdit,
    required Function(String, String) onDelete,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: equipmentList.length,
      itemBuilder: (context, index) {
        final equipment = equipmentList[index];
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: getStatusColor(equipment['status']).withOpacity(0.2),
                child: Icon(
                  Icons.devices,
                  color: getStatusColor(equipment['status']),
                ),
              ),
              title: Text(
                equipment['name'] ?? 'Unknown Equipment',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type: ${getTypeLabel(equipment['type'])} • Room: ${getRoomName(equipment['room']?.toString())}',
                    style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (equipment['device_id'] != null)
                    Text(
                      'Device ID: ${equipment['device_id']}',
                      style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: getStatusColor(equipment['status']).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      equipment['status']?.toUpperCase() ?? 'UNKNOWN',
                      style: GoogleFonts.urbanist(
                        color: getStatusColor(equipment['status']),
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
                    onEdit(equipment);
                  } else if (value == 'delete') {
                    onDelete(equipment['id'].toString(), equipment['name'] ?? 'Unknown');
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
            ),
          ),
        );
      },
    );
  }

  static Widget buildSummaryCards({
    required int equipmentCount,
    required int onlineCount,
    required int esp32Count,
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
                    const Icon(Icons.devices, color: Color(0xFF184BFB), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '$equipmentCount',
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Total Equipment',
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
                    const Icon(Icons.online_prediction, color: Color(0xFF184BFB), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '$onlineCount',
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Online',
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
                    const Icon(Icons.memory, color: Color(0xFF184BFB), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '$esp32Count',
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ESP32 Devices',
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

  static Widget buildFilterChips({
    required String filterRoom,
    required String filterType,
    required String Function(String?) getRoomName,
    required String Function(String?) getTypeLabel,
    required VoidCallback onRemoveRoomFilter,
    required VoidCallback onRemoveTypeFilter,
  }) {
    if (filterRoom == 'all' && filterType == 'all') {
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (filterRoom != 'all')
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(
                    'Room: ${filterRoom == 'unassigned' ? 'Unassigned' : getRoomName(filterRoom)}',
                    style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF121822),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
                  onDeleted: onRemoveRoomFilter,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
              ),
            if (filterType != 'all')
              Chip(
                label: Text(
                  'Type: ${getTypeLabel(filterType)}',
                  style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
                ),
                backgroundColor: const Color(0xFF121822),
                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
                onDeleted: onRemoveTypeFilter,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget buildFilterDialog(
      BuildContext context, {
        required String currentFilterRoom,
        required String currentFilterType,
        required List<dynamic> rooms,
        required List<Map<String, String>> equipmentTypeOptions,
        required ValueChanged<String> onFilterRoomChanged,
        required ValueChanged<String> onFilterTypeChanged,
        required VoidCallback onApply,
        required VoidCallback onClear,
        required VoidCallback onCancel,
      }) {
    String tempFilterRoom = currentFilterRoom;
    String tempFilterType = currentFilterType;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        maxWidth: 400,
        minWidth: 300,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildDialogHeader(
            context,
            title: 'Filter Equipment',
            icon: Icons.filter_list,
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: tempFilterRoom,
                        decoration: InputDecoration(
                          labelText: 'Filter by Room',
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
                          prefixIcon: const Icon(Icons.room, color: Colors.white70),
                        ),
                        dropdownColor: const Color(0xFF121822),
                        style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<String>(
                            value: 'all',
                            child: Text(
                              'All Rooms',
                              style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'unassigned',
                            child: Text(
                              'Unassigned',
                              style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...rooms.map((room) => DropdownMenuItem<String>(
                            value: room['id'].toString(),
                            child: Text(
                              room['name'],
                              style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                        onChanged: (value) {
                          tempFilterRoom = value ?? 'all';
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tempFilterType,
                        decoration: InputDecoration(
                          labelText: 'Filter by Type',
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
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<String>(
                            value: 'all',
                            child: Text(
                              'All Types',
                              style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...equipmentTypeOptions.map((option) => DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(
                              option['label']!,
                              style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                        onChanged: (value) {
                          tempFilterType = value ?? 'all';
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          buildDialogFooter(
            context,
            onCancel: onCancel,
            onAction: () {
              onFilterRoomChanged(tempFilterRoom);
              onFilterTypeChanged(tempFilterType);
              onApply();
            },
            actionText: 'Apply',
            secondaryActionText: 'Clear',
            onSecondaryAction: () {
              onFilterRoomChanged('all');
              onFilterTypeChanged('all');
              onClear();
            },
          ),
        ],
      ),
    );
  }

  static Widget buildDeleteConfirmationDialog({
    required String equipmentName,
    required VoidCallback onConfirm,
  }) {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 400, minWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogHeader(
              context,
              title: 'Delete Equipment',
              icon: Icons.delete,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Are you sure you want to delete "$equipmentName"? This will also delete all sensor data associated with this equipment.',
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

  static Widget buildDebugDialog(
      BuildContext context, {
        required String baseUrl,
        required int tokenLength,
        required int equipmentCount,
        required int roomsCount,
        required String errorMessage,
        required bool isLoading,
        required bool isRefreshingToken,
        required VoidCallback onClose,
      }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 400, minWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildDialogHeader(
            context,
            title: 'Debug Info',
            icon: Icons.bug_report,
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Information',
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Base URL: $baseUrl',
                        style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Token Length: $tokenLength',
                        style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Equipment Count: $equipmentCount',
                        style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Rooms Count: $roomsCount',
                        style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Error Message: $errorMessage',
                        style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                      ),
                      Text(
                        'Is Loading: $isLoading',
                        style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Is Refreshing Token: $isRefreshingToken',
                        style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          buildDialogFooter(
            context,
            actionText: 'Close',
            onAction: onClose,
          ),
        ],
      ),
    );
  }

  static Color _getStatusColor(String? status) {
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
}