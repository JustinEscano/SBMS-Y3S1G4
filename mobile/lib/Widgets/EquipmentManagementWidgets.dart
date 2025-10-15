import 'package:flutter/material.dart';

class EquipmentManagementWidgets {
  static Widget buildSummaryCards(BuildContext context, int totalCount, int onlineCount, int esp32Count) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: const Color(0xFF1F1E23),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.devices, color: Colors.blue[700], size: 24),
                          const SizedBox(height: 4),
                          FittedBox(
                            child: Text(
                              '$totalCount',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const FittedBox(
                            child: Text('Total Equipment', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: const Color(0xFF1F1E23),
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
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const FittedBox(
                            child: Text('Online', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: const Color(0xFF1F1E23),
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
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const FittedBox(
                            child: Text('ESP32 Devices', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
    );
  }

  static Widget buildFilterChips(BuildContext context, {
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
                  label: Text('Room: ${filterRoom == 'unassigned' ? 'Unassigned' : getRoomName(filterRoom)}'),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: onRemoveRoomFilter,
                ),
              ),
            if (filterType != 'all')
              Chip(
                label: Text('Type: ${getTypeLabel(filterType)}'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: onRemoveTypeFilter,
              ),
          ],
        ),
      ),
    );
  }

  static Widget buildErrorBanner(BuildContext context, String errorMessage) {
    return Container(
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
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildEmptyState(BuildContext context, {
    required bool hasEquipment,
    required VoidCallback onAddEquipment,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.devices_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              hasEquipment ? 'No Equipment Match Filters' : 'No Equipment Found',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasEquipment ? 'Try adjusting your filters' : 'Add your first equipment to get started',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddEquipment,
              icon: const Icon(Icons.add),
              label: const Text('Add Equipment'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildEquipmentCard(BuildContext context, {
    required Map<String, dynamic> equipment,
    required String Function(String?) getRoomName,
    required String Function(String?) getTypeLabel,
    required Color Function(String?) getStatusColor,
    required Function(Map<String, dynamic>) onEdit,
    required Function(String, String) onDelete,
  }) {
    final statusColor = getStatusColor(equipment['status']);

    return Card(
      color: const Color(0xFF1F1E23),
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
          equipment['name'] ?? 'Unknown Equipment',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${getTypeLabel(equipment['type'])} • Room: ${getRoomName(equipment['room']?.toString())}',
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
            if (equipment['device_id'] != null)
              Text(
                'Device ID: ${equipment['device_id']}',
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
                equipment['status']?.toUpperCase() ?? 'UNKNOWN',
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
              onEdit(equipment);
            } else if (value == 'delete') {
              onDelete(equipment['id'], equipment['name']);
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
  }

  static Widget buildEquipmentList(BuildContext context, {
    required List<Map<String, dynamic>> equipmentList,
    required String Function(String?) getRoomName,
    required String Function(String?) getTypeLabel,
    required Color Function(String?) getStatusColor,
    required Function(Map<String, dynamic>) onEdit,
    required Function(String, String) onDelete,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: equipmentList.length,
        itemBuilder: (context, index) {
          final equipment = equipmentList[index];
          return buildEquipmentCard(
            context,
            equipment: equipment,
            getRoomName: getRoomName,
            getTypeLabel: getTypeLabel,
            getStatusColor: getStatusColor,
            onEdit: onEdit,
            onDelete: onDelete,
          );
        },
      ),
    );
  }

  static Widget buildDialogHeader(BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onClose,
  }) {
    return Container(
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
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  static Widget buildDialogFooter(BuildContext context, {
    required VoidCallback onCancel,
    required VoidCallback onAction,
    required String actionText,
    String? secondaryActionText,
    VoidCallback? onSecondaryAction,
  }) {
    return Container(
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
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
          if (secondaryActionText != null && onSecondaryAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionText),
            ),
          ],
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  static Widget buildAddEditEquipmentDialog(BuildContext context, {
    required bool isEditing,
    required Map<String, dynamic>? equipmentItem,
    required List<dynamic> rooms,
    required List<Map<String, String>> equipmentTypeOptions,
    required List<Map<String, String>> equipmentStatusOptions,
    required TextEditingController nameController,
    required TextEditingController deviceIdController,
    required TextEditingController qrCodeController,
    required String selectedRoomId,
    required String selectedStatus,
    required String selectedType,
    required ValueChanged<String> onRoomChanged,
    required ValueChanged<String> onStatusChanged,
    required ValueChanged<String> onTypeChanged,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogHeader(
              context,
              title: isEditing ? 'Edit Equipment' : 'Add New Equipment',
              icon: isEditing ? Icons.edit : Icons.add,
              onClose: onCancel,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    buildTypeDropdown(
                      context,
                      selectedType: selectedType,
                      equipmentTypeOptions: equipmentTypeOptions,
                      onTypeChanged: onTypeChanged,
                    ),
                    const SizedBox(height: 16),
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
                    buildRoomDropdown(
                      context,
                      selectedRoomId: selectedRoomId,
                      rooms: rooms,
                      onRoomChanged: onRoomChanged,
                    ),
                    const SizedBox(height: 16),
                    buildStatusDropdown(
                      context,
                      selectedStatus: selectedStatus,
                      equipmentStatusOptions: equipmentStatusOptions,
                      onStatusChanged: onStatusChanged,
                    ),
                    const SizedBox(height: 12),
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
            buildDialogFooter(
              context,
              onCancel: onCancel,
              onAction: onSave,
              actionText: isEditing ? 'Update' : 'Add',
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildTypeDropdown(BuildContext context, {
    required String selectedType,
    required List<Map<String, String>> equipmentTypeOptions,
    required ValueChanged<String> onTypeChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: selectedType,
      decoration: const InputDecoration(
        labelText: 'Equipment Type *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
        isDense: true,
      ),
      isExpanded: true,
      items: equipmentTypeOptions.map((option) => DropdownMenuItem<String>(
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
      onChanged: (value) => onTypeChanged(value ?? 'sensor'),
      selectedItemBuilder: (BuildContext context) {
        return equipmentTypeOptions.map<Widget>((option) {
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
    );
  }

  static Widget buildRoomDropdown(BuildContext context, {
    required String selectedRoomId,
    required List<dynamic> rooms,
    required ValueChanged<String> onRoomChanged,
  }) {
    return DropdownButtonFormField<String>(
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
      onChanged: (value) => onRoomChanged(value ?? ''),
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
    );
  }

  static Widget buildStatusDropdown(BuildContext context, {
    required String selectedStatus,
    required List<Map<String, String>> equipmentStatusOptions,
    required ValueChanged<String> onStatusChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: selectedStatus,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.power_settings_new),
        isDense: true,
      ),
      isExpanded: true,
      items: equipmentStatusOptions.map((option) => DropdownMenuItem<String>(
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
      onChanged: (value) => onStatusChanged(value ?? 'offline'),
      selectedItemBuilder: (BuildContext context) {
        return equipmentStatusOptions.map<Widget>((option) {
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
    );
  }

  static Widget buildFilterDialog(BuildContext context, {
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
            buildDialogHeader(
              context,
              title: 'Filter Equipment',
              icon: Icons.filter_list,
              onClose: onCancel,
            ),
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
                        tempFilterRoom = value ?? 'all';
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
                        ...equipmentTypeOptions.map((option) => DropdownMenuItem<String>(
                          value: option['value'],
                          child: Text(
                            option['label']!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                      ],
                      onChanged: (value) {
                        tempFilterType = value ?? 'all';
                      },
                    ),
                  ],
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
      ),
    );
  }

  static Widget buildDebugDialog(BuildContext context, {
    required String baseUrl,
    required int tokenLength,
    required int equipmentCount,
    required int roomsCount,
    required String errorMessage,
    required bool isLoading,
    required bool isRefreshingToken,
  }) {
    return AlertDialog(
      title: const Text('Debug Info'),
      content: SingleChildScrollView(
        child: Text(
          'Base URL: $baseUrl\n'
              'Token Length: $tokenLength\n'
              'Equipment Count: $equipmentCount\n'
              'Rooms Count: $roomsCount\n'
              'Error Message: $errorMessage\n'
              'Is Loading: $isLoading\n'
              'Is Refreshing Token: $isRefreshingToken',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
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
