import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';

class MaintenanceDetailsWidgets {
  static Widget buildDialogHeader(BuildContext context, {required String title, required IconData icon}) {
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
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  static Widget buildDialogFooter(
      BuildContext context, {required VoidCallback onAction, String actionText = 'Create', Widget? extraAction}) {
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
          if (extraAction != null) ...[
            const SizedBox(width: 8),
            extraAction,
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

  static Widget buildDetailRow(BuildContext context, String label, String value, IconData icon, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? const Color(0xFF184BFB), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color ?? Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildCommentCard(BuildContext context, Map<String, String> comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1E23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${comment['user'] ?? 'Unknown'} (${comment['role'] ?? 'Unknown'})',
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                comment['timestamp'] ?? 'No timestamp',
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment['text'] ?? 'No comment text',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              color: Colors.white,
            ),
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
            icon: const Icon(Icons.chevron_left, color: Colors.white70),
            onPressed: currentPage > 1 ? onPrevious : null,
          ),
          Text(
            'Page $currentPage of $totalPages',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white70),
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
      color: const Color(0xFF1F1E23),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments',
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (comments.isEmpty)
              Text(
                'No comments yet',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  color: Colors.white70,
                ),
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Commenting is restricted to Admins, Superadmins, or owners/assigned users. Your role: $effectiveRole',
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    color: Colors.yellow[900],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: const Color(0xFF1F1E23),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF184BFB), width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Comment',
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              decoration: InputDecoration(
                labelText: 'Comment',
                hintText: 'Enter your comment...',
                labelStyle: GoogleFonts.urbanist(color: Colors.white70),
                hintStyle: GoogleFonts.urbanist(color: Colors.white54),
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
                prefixIcon: const Icon(Icons.comment, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF2A2A2E),
                errorText: responseController.text.trim().isEmpty && responseController.text.isNotEmpty
                    ? 'Comment cannot be empty'
                    : null,
              ),
              style: GoogleFonts.urbanist(color: Colors.white),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            if (effectiveRole == 'admin' || effectiveRole == 'superadmin') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedAssignedToId,
                decoration: InputDecoration(
                  labelText: 'Assign To (Optional)',
                  labelStyle: GoogleFonts.urbanist(color: Colors.white70),
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
                  prefixIcon: const Icon(Icons.person_add, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2E),
                ),
                isExpanded: true,
                dropdownColor: const Color(0xFF1F1E23),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'None',
                      style: GoogleFonts.urbanist(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...users
                      .where((user) => user['role'] == 'employee' || user['role'] == 'admin')
                      .map((user) => DropdownMenuItem<String>(
                    value: user['id'].toString(),
                    child: Text(
                      '${user['username']} (${user['email']})',
                      style: GoogleFonts.urbanist(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                ],
                onChanged: onAssignedToChanged,
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: responseController.text.trim().isEmpty || isRefreshingToken ? null : onAddComment,
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                label: Text(
                  'Add Comment',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF184BFB),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
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
      color: const Color(0xFF1F1E23),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attachments',
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...attachments.map((attachment) {
              final mediaUrl = getAttachmentUrl(attachment['file'] as String?);
              final isImage = (attachment['file_type'] as String?)?.startsWith('image') ?? false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: isImage
                    ? FutureBuilder<Uint8List?>(
                  future: fetchImageData(attachment['file'] as String? ?? ''),
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
                          attachment['file_name'] as String? ?? 'Unknown',
                          style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Failed to load image',
                          style: GoogleFonts.urbanist(fontSize: 12, color: Colors.white70),
                        ),
                        onTap: () => openAttachment(attachment['file'] as String? ?? '', attachment['file_name'] as String? ?? 'Unknown'),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => openAttachment(attachment['file'] as String? ?? '', attachment['file_name'] as String? ?? 'Unknown'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              snapshot.data!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return ListTile(
                                  leading: const Icon(Icons.error, color: Colors.red),
                                  title: Text(
                                    attachment['file_name'] as String? ?? 'Unknown',
                                    style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Failed to load image',
                                    style: GoogleFonts.urbanist(fontSize: 12, color: Colors.white70),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Uploaded by ${getUserName(attachment['uploaded_by']?.toString())} at ${DateTime.tryParse(attachment['uploaded_at'] as String? ?? '')?.toLocal().toString().split('.')[0] ?? 'Unknown'}',
                            style: GoogleFonts.urbanist(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ],
                    );
                  },
                )
                    : ListTile(
                  leading: Icon(
                    (attachment['file_type'] as String?)?.startsWith('image') ?? false ? Icons.image : Icons.picture_as_pdf,
                    color: const Color(0xFF184BFB),
                  ),
                  title: Text(
                    attachment['file_name'] as String? ?? 'Unknown',
                    style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Uploaded by ${getUserName(attachment['uploaded_by']?.toString())} at ${DateTime.tryParse(attachment['uploaded_at'] as String? ?? '')?.toLocal().toString().split('.')[0] ?? 'Unknown'}',
                    style: GoogleFonts.urbanist(fontSize: 12, color: Colors.white70),
                  ),
                  onTap: () => openAttachment(attachment['file'] as String? ?? '', attachment['file_name'] as String? ?? 'Unknown'),
                ),
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
    required Color Function(String?) getStatusColor,
  }) {
    final statusColor = getStatusColor(requestData['status'] as String?);

    return Card(
      color: const Color(0xFF1F1E23),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Details',
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            buildDetailRow(
              context,
              'Issue',
              requestData['issue'] as String? ?? 'No description',
              Icons.description,
            ),
            const SizedBox(height: 12),
            buildDetailRow(
              context,
              'Status',
              getStatusLabel(requestData['status'] as String?),
              Icons.assignment,
              statusColor,
            ),
            const SizedBox(height: 12),
            buildDetailRow(
              context,
              'Requested By',
              getUserName(requestData['user']?.toString()),
              Icons.person,
            ),
            const SizedBox(height: 12),
            buildDetailRow(
              context,
              'Scheduled Date',
              requestData['scheduled_date'] != null
                  ? DateTime.tryParse(requestData['scheduled_date'] as String? ?? '')?.toString().split(' ')[0] ?? 'Not scheduled'
                  : 'Not scheduled',
              Icons.calendar_today,
            ),
            if (requestData['resolved_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: buildDetailRow(
                  context,
                  'Resolved At',
                  DateTime.tryParse(requestData['resolved_at'] as String? ?? '')?.toString().split('.')[0] ?? 'Unknown',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF1E1E1E),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (userRole == 'admin' || userRole == 'superadmin' || isEditing) ...[
                    DropdownButtonFormField<String>(
                      value: selectedUserId.isEmpty ? null : selectedUserId,
                      decoration: InputDecoration(
                        labelText: 'User *',
                        labelStyle: GoogleFonts.urbanist(color: Colors.white70),
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
                        prefixIcon: const Icon(Icons.person, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2E),
                        errorText: selectedUserId.isEmpty ? 'Please select a user' : null,
                      ),
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1F1E23),
                      items: users.map((user) => DropdownMenuItem<String>(
                        value: user['id'].toString(),
                        child: Text(
                          '${user['username']} (${user['email']})',
                          style: GoogleFonts.urbanist(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: userRole == 'client' ? null : (value) => onUserIdChanged(value ?? ''),
                      disabledHint: Text(
                        userRole == 'client' ? 'You (Client)' : 'Select user',
                        style: GoogleFonts.urbanist(color: Colors.white70),
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Requested by: You (${userRole})',
                        style: GoogleFonts.urbanist(fontSize: 16, color: Colors.white70),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedEquipmentId.isEmpty ? null : selectedEquipmentId,
                    decoration: InputDecoration(
                      labelText: 'Equipment *',
                      labelStyle: GoogleFonts.urbanist(color: Colors.white70),
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
                      prefixIcon: const Icon(Icons.devices, color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2E),
                      errorText: selectedEquipmentId.isEmpty ? 'Please select equipment' : null,
                    ),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1F1E23),
                    items: equipment.map((eq) => DropdownMenuItem<String>(
                      value: eq['id'].toString(),
                      child: Text(
                        '${eq['name']} (${eq['type']})',
                        style: GoogleFonts.urbanist(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (value) => onEquipmentIdChanged(value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: issueController,
                    decoration: InputDecoration(
                      labelText: 'Issue Description *',
                      hintText: 'Describe the maintenance issue...',
                      labelStyle: GoogleFonts.urbanist(color: Colors.white70),
                      hintStyle: GoogleFonts.urbanist(color: Colors.white54),
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
                      prefixIcon: const Icon(Icons.description, color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2E),
                      errorText: issueController.text.trim().isEmpty ? 'Issue description is required' : null,
                    ),
                    style: GoogleFonts.urbanist(color: Colors.white),
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 16),
                  if (userRole == 'admin' || userRole == 'superadmin') ...[
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: GoogleFonts.urbanist(color: Colors.white70),
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
                        prefixIcon: const Icon(Icons.assignment, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2E),
                      ),
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1F1E23),
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
                            Text(
                              option['label']!,
                              style: GoogleFonts.urbanist(color: Colors.white),
                            ),
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
                        labelStyle: GoogleFonts.urbanist(color: Colors.white70),
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
                        prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2E),
                        errorText: selectedDate == null ? 'Please select a date' : null,
                      ),
                      child: Text(
                        selectedDate != null
                            ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                            : 'Select date',
                        style: GoogleFonts.urbanist(color: Colors.white),
                      ),
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
                          labelStyle: GoogleFonts.urbanist(color: Colors.white70),
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
                          prefixIcon: const Icon(Icons.check_circle, color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2E),
                          suffixIcon: resolvedDate != null
                              ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () => onResolvedDateChanged(null),
                          )
                              : null,
                          errorText: selectedStatus == 'resolved' && resolvedDate == null ? 'Please select resolved date' : null,
                        ),
                        child: Text(
                          resolvedDate != null
                              ? '${resolvedDate.day}/${resolvedDate.month}/${resolvedDate.year} ${resolvedDate.hour.toString().padLeft(2, '0')}:${resolvedDate.minute.toString().padLeft(2, '0')}'
                              : 'Select date and time',
                          style: GoogleFonts.urbanist(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '* Required fields',
                    style: GoogleFonts.urbanist(fontSize: 12, color: Colors.white70),
                  ),
                ],
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