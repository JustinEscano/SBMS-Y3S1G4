import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MaintenanceScreenWidgets {
  static Widget buildDialogHeader(BuildContext context, {String title = '', IconData icon = Icons.edit}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
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
        color: Theme.of(context).colorScheme.surface,
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

  static Widget buildFilterDialog(BuildContext context, {
    required String currentFilterStatus,
    required List<Map<String, String>> statusOptions,
    required ValueChanged<String> onFilterChanged,
    required VoidCallback onClearFilter,
  }) {
    String tempFilterStatus = currentFilterStatus;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF1E1E1E),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogHeader(
              context,
              title: 'Filter Maintenance Requests',
              icon: Icons.filter_list,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  buildFilterChip(
                    label: 'All',
                    isSelected: tempFilterStatus == 'all',
                    onSelected: () => tempFilterStatus = 'all',
                  ),
                  ...statusOptions.map((option) => buildFilterChip(
                    label: option['label']!,
                    isSelected: tempFilterStatus == option['value'],
                    onSelected: () => tempFilterStatus = option['value']!,
                  )),
                ],
              ),
            ),
            buildDialogFooter(
              context,
              onAction: () => onFilterChanged(tempFilterStatus),
              actionText: 'Apply',
              extraAction: TextButton(
                onPressed: onClearFilter,
                child: Text(
                  'Clear',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => onSelected(),
      selectedColor: const Color(0xFF184BFB),
      backgroundColor: const Color(0xFF1F1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      checkmarkColor: Colors.white,
    );
  }

  static Widget buildMaintenanceRequestCard(BuildContext context, {
    required Map<String, dynamic> request,
    required String Function(String?) getEquipmentName,
    required String Function(String?) getUserName,
    required String Function(String?) getStatusLabel,
    required Color Function(String?) getStatusColor,
    required VoidCallback onTap,
  }) {
    final status = request['status'] as String?;
    final statusColor = getStatusColor(status);

    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.2),
                      child: Icon(Icons.build, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        getEquipmentName(request['equipment']?.toString()),
                        style: GoogleFonts.urbanist(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  request['issue'] as String? ?? 'No description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        getStatusLabel(status),
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: statusColor.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: statusColor.withOpacity(0.4)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'By: ${getUserName(request['user']?.toString())}',
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (request['scheduled_date'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Scheduled: ${DateTime.tryParse(request['scheduled_date'] as String? ?? '')?.toString().split(' ')[0] ?? 'Unknown'}',
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget buildEmptyState(BuildContext context, {
    required bool hasRequests,
    required bool canCreateRequest,
    required VoidCallback onCreateRequest,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_outlined, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            hasRequests ? 'No Requests Match Filters' : 'No Maintenance Requests',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasRequests ? 'Try adjusting your filters' : 'Create your first maintenance request',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: canCreateRequest ? onCreateRequest : null,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Create Request',
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
        ],
      ),
    );
  }

  static Widget buildErrorBanner(BuildContext context, String errorMessage) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCDD2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildPaginationControls(BuildContext context, {
    required int currentPage,
    required int totalPages,
    required VoidCallback onPreviousPage,
    required VoidCallback onNextPage,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white70),
            onPressed: currentPage > 1 ? onPreviousPage : null,
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
            onPressed: currentPage < totalPages ? onNextPage : null,
          ),
        ],
      ),
    );
  }

  static Widget buildMaintenanceRequestList(BuildContext context, {
    required List<Map<String, dynamic>> requests,
    required String Function(String?) getEquipmentName,
    required String Function(String?) getUserName,
    required String Function(String?) getStatusLabel,
    required Color Function(String?) getStatusColor,
    required Function(Map<String, dynamic>) onRequestTap,
  }) {
    return Column(
      children: requests.asMap().entries.map((entry) {
        final index = entry.key;
        final request = entry.value;
        return buildMaintenanceRequestCard(
          context,
          request: request,
          getEquipmentName: getEquipmentName,
          getUserName: getUserName,
          getStatusLabel: getStatusLabel,
          getStatusColor: getStatusColor,
          onTap: () => onRequestTap(request),
        );
      }).toList(),
    );
  }

  static Widget buildMaintenanceRequestListWithPagination(BuildContext context, {
    required List<Map<String, dynamic>> requests,
    required int currentPage,
    required int totalPages,
    required String Function(String?) getEquipmentName,
    required String Function(String?) getUserName,
    required String Function(String?) getStatusLabel,
    required Color Function(String?) getStatusColor,
    required Function(Map<String, dynamic>) onRequestTap,
    required VoidCallback onPreviousPage,
    required VoidCallback onNextPage,
  }) {
    return Column(
      children: [
        buildMaintenanceRequestList(
          context,
          requests: requests,
          getEquipmentName: getEquipmentName,
          getUserName: getUserName,
          getStatusLabel: getStatusLabel,
          getStatusColor: getStatusColor,
          onRequestTap: onRequestTap,
        ),
        if (totalPages > 1)
          buildPaginationControls(
            context,
            currentPage: currentPage,
            totalPages: totalPages,
            onPreviousPage: onPreviousPage,
            onNextPage: onNextPage,
          ),
      ],
    );
  }
}