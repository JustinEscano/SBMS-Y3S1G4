import 'package:flutter/material.dart';
import 'dart:typed_data';

class MaintenanceDetailsWidgets {
  static Widget buildDialogHeader(BuildContext context, {required String title, required IconData icon}) {
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

  static Widget buildDialogFooter(
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

  static Widget buildDetailRow(BuildContext context, String label, String value, IconData icon, [Color? color]) {
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

  static Widget buildCommentCard(BuildContext context, Map<String, String> comment) {
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
  }

  static Widget buildCommentPagination(BuildContext context, int currentPage, int totalPages, VoidCallback onPrevious, VoidCallback onNext) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? onPrevious : null,
          ),
          Text(
            'Page $currentPage of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages ? onNext : null,
          ),
        ],
      ),
    );
  }

  static Widget buildCommentSection(BuildContext context, {
    required List<Map<String, String>> comments,
    required int currentPage,
    required int totalPages,
    required VoidCallback onPreviousPage,
    required VoidCallback onNextPage,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comments', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (comments.isEmpty)
              Text(
                'No comments yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            if (comments.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) => buildCommentCard(context, comments[index]),
              ),
            if (totalPages > 1)
              buildCommentPagination(context, currentPage, totalPages, onPreviousPage, onNextPage),
          ],
        ),
      ),
    );
  }

  static Widget buildCommentInputSection(BuildContext context, {
    required TextEditingController responseController,
    required bool canComment,
    required String effectiveRole,
    required VoidCallback onAddComment,
    required String? selectedAssignedToId,
    required List<dynamic> users,
    required ValueChanged<String?> onAssignedToChanged,
    required bool isRefreshingToken,
  }) {
    if (!canComment) {
      return Padding(
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
                  'Commenting is restricted to Admins, Superadmins, or owners/assigned Employees/Clients. Your role: $effectiveRole',
                  style: TextStyle(color: Colors.yellow[900], fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
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
              controller: responseController,
              decoration: InputDecoration(
                labelText: 'Comment',
                hintText: 'Enter your comment...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.comment),
                filled: true,
                fillColor: Colors.grey[50],
                errorText: responseController.text.isEmpty && responseController.text.trim().isEmpty
                    ? 'Comment cannot be empty'
                    : null,
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
                  onPressed: responseController.text.isEmpty || isRefreshingToken
                      ? null
                      : onAddComment,
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
            if (effectiveRole == 'admin' || effectiveRole == 'superadmin') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedAssignedToId,
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
                  ...users
                      .where((user) => user['role'] == 'employee' || user['role'] == 'admin')
                      .map((user) => DropdownMenuItem<String>(
                    value: user['id'].toString(),
                    child: Text('${user['username']} (${user['email']})', overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: onAssignedToChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget buildAttachmentSection(BuildContext context, {
    required List<dynamic> attachments,
    required String Function(String?) getAttachmentUrl,
    required Future<Uint8List?> Function(String) fetchImageData,
    required void Function(String, String) openAttachment,
    required String Function(String?) getUserName,
  }) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Card(
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
              final mediaUrl = getAttachmentUrl(attachment['file']);
              final isImage = attachment['file_type'].startsWith('image');

              return isImage
                  ? FutureBuilder<Uint8List?>(
                future: fetchImageData(attachment['file']),
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
                      onTap: () => openAttachment(attachment['file'], attachment['file_name']),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => openAttachment(attachment['file'], attachment['file_name']),
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
                          'Uploaded by ${getUserName(attachment['uploaded_by']?.toString())} at ${DateTime.parse(attachment['uploaded_at']).toLocal()}',
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
                  'Uploaded by ${getUserName(attachment['uploaded_by']?.toString())} at ${DateTime.parse(attachment['uploaded_at']).toLocal()}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                onTap: () => openAttachment(attachment['file'], attachment['file_name']),
              );
            }),
          ],
        ),
      ),
    );
  }

  static Widget buildRequestDetailsCard(BuildContext context, {
    required Map<String, dynamic> requestData,
    required String Function(String?) getEquipmentName,
    required String Function(String?) getUserName,
    required String Function(String?) getStatusLabel,
    required Color Function(String) getStatusColor,
  }) {
    final statusColor = getStatusColor(requestData['status'] ?? '');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request Details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            buildDetailRow(context, 'Issue', requestData['issue'] ?? 'No description', Icons.description),
            const SizedBox(height: 12),
            buildDetailRow(context, 'Status', getStatusLabel(requestData['status']), Icons.assignment, statusColor),
            const SizedBox(height: 12),
            buildDetailRow(context, 'Requested By', getUserName(requestData['user']?.toString()), Icons.person),
            const SizedBox(height: 12),
            buildDetailRow(
              context,
              'Scheduled Date',
              requestData['scheduled_date'] != null
                  ? '${DateTime.parse(requestData['scheduled_date']).day}/${DateTime.parse(requestData['scheduled_date']).month}/${DateTime.parse(requestData['scheduled_date']).year}'
                  : 'Not scheduled',
              Icons.calendar_today,
            ),
            if (requestData['resolved_at'] != null) ...[
              const SizedBox(height: 12),
              buildDetailRow(
                context,
                'Resolved At',
                '${DateTime.parse(requestData['resolved_at']).day}/${DateTime.parse(requestData['resolved_at']).month}/${DateTime.parse(requestData['resolved_at']).year} ${DateTime.parse(requestData['resolved_at']).hour.toString().padLeft(2, '0')}:${DateTime.parse(requestData['resolved_at']).minute.toString().padLeft(2, '0')}',
                Icons.check_circle,
                Colors.green,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget buildAddEditMaintenanceDialog(BuildContext context, {
    required bool isEditing,
    required Map<String, dynamic> requestData,
    required List<dynamic> users,
    required List<dynamic> equipment,
    required List<Map<String, String>> statusOptions,
    required String userRole,
    required String? currentUserId,
    required TextEditingController issueController,
    required String selectedUserId,
    required String selectedEquipmentId,
    required String selectedStatus,
    required DateTime selectedDate,
    required DateTime? resolvedDate,
    required ValueChanged<String> onUserIdChanged,
    required ValueChanged<String> onEquipmentIdChanged,
    required ValueChanged<String> onStatusChanged,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<DateTime?> onResolvedDateChanged,
    required VoidCallback onSave,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogHeader(
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
                    if (userRole == 'admin' || userRole == 'superadmin' || isEditing) ...[
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
                        items: users.map((user) => DropdownMenuItem<String>(
                          value: user['id'].toString(),
                          child: Text('${user['username']} (${user['email']})', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: userRole == 'client' ? null : (value) => onUserIdChanged(value ?? ''),
                        disabledHint: Text(userRole == 'client' ? 'You (Client)' : 'Select user'),
                      ),
                    ] else ...[
                      Text(
                        'Requested by: You (${userRole})',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
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
                      items: equipment.map((eq) => DropdownMenuItem<String>(
                        value: eq['id'].toString(),
                        child: Text('${eq['name']} (${eq['type']})', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (value) => onEquipmentIdChanged(value ?? ''),
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
                    if (userRole == 'admin' || userRole == 'superadmin') ...[
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
                        items: statusOptions.map((option) => DropdownMenuItem<String>(
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
                        onChanged: (value) => onStatusChanged(value ?? 'pending'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) onDateChanged(picked);
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
                    if ((userRole == 'admin' || userRole == 'superadmin') && (selectedStatus == 'resolved' || resolvedDate != null)) ...[
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
                              onResolvedDateChanged(DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                timePicked.hour,
                                timePicked.minute,
                              ));
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
                              onPressed: () => onResolvedDateChanged(null),
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
            buildDialogFooter(
              context,
              onAction: onSave,
              actionText: isEditing ? 'Update' : 'Create',
            ),
          ],
        ),
      ),
    );
  }

  static Color _getStatusColor(String status) {
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
}