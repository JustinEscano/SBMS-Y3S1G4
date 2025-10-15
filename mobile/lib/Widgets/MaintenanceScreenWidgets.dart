import 'package:flutter/material.dart';

class MaintenanceScreenWidgets {
  static Widget buildDialogHeader(BuildContext context, {String title = '', IconData icon = Icons.edit}) {
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

  static Widget buildSummaryCards(BuildContext context, int pendingCount, int inProgressCount, int resolvedCount) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          buildSummaryCard(context, 'Pending', pendingCount, Icons.pending, Colors.orange[700]!),
          const SizedBox(width: 12),
          buildSummaryCard(context, 'In Progress', inProgressCount, Icons.work, Colors.blue[700]!),
          const SizedBox(width: 12),
          buildSummaryCard(context, 'Resolved', resolvedCount, Icons.check_circle, Colors.green[700]!),
        ],
      ),
    );
  }

  static Widget buildSummaryCard(BuildContext context, String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: const Color(0xFF1F1E23),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text('$count', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
        ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              child: DropdownButtonFormField<String>(
                value: tempFilterStatus,
                decoration: InputDecoration(
                  labelText: 'Filter by Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.filter_alt),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(value: 'all', child: Text('All Statuses')),
                  ...statusOptions.map((option) => DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(option['label']!),
                  )),
                ],
                onChanged: (value) => tempFilterStatus = value ?? 'all',
              ),
            ),
            buildDialogFooter(
              context,
              onAction: () => onFilterChanged(tempFilterStatus),
              actionText: 'Apply',
              extraAction: TextButton(
                onPressed: onClearFilter,
                child: const Text('Clear'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildMaintenanceRequestCard(BuildContext context, {
    required Map<String, dynamic> request,
    required String Function(String?) getEquipmentName,
    required String Function(String?) getUserName,
    required String Function(String?) getStatusLabel,
    required Color Function(String) getStatusColor,
    required VoidCallback onTap,
  }) {
    final statusColor = getStatusColor(request['status'] ?? '');

    return Card(
      color: const Color(0xFF1F1E23),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(Icons.build, color: statusColor),
        ),
        title: Text(
          getEquipmentName(request['equipment']?.toString()),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              request['issue'] ?? 'No description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    getStatusLabel(request['status']),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'By: ${getUserName(request['user']?.toString())}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (request['scheduled_date'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Scheduled: ${DateTime.parse(request['scheduled_date']).day}/${DateTime.parse(request['scheduled_date']).month}/${DateTime.parse(request['scheduled_date']).year}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
          ],
        ),
        onTap: onTap,
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
          Icon(Icons.build_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            hasRequests ? 'No Requests Match Filters' : 'No Maintenance Requests',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            hasRequests ? 'Try adjusting your filters' : 'Create your first maintenance request',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: canCreateRequest ? onCreateRequest : null,
            icon: const Icon(Icons.add),
            label: const Text('Create Request'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildErrorBanner(BuildContext context, String errorMessage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(errorMessage, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  static Widget buildFilterChip(BuildContext context, {
    required String filterStatus,
    required String Function(String?) getStatusLabel,
    required Color Function(String) getStatusColor,
    required VoidCallback onRemoveFilter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Chip(
        label: Text('Status: ${getStatusLabel(filterStatus)}', style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: getStatusColor(filterStatus).withOpacity(0.1),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemoveFilter,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? onPreviousPage : null,
            color: Colors.white,
          ),
          Text(
            'Page $currentPage of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages ? onNextPage : null,
            color: Colors.white,
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
    required Color Function(String) getStatusColor,
    required Function(Map<String, dynamic>) onRequestTap,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return buildMaintenanceRequestCard(
          context,
          request: request,
          getEquipmentName: getEquipmentName,
          getUserName: getUserName,
          getStatusLabel: getStatusLabel,
          getStatusColor: getStatusColor,
          onTap: () => onRequestTap(request),
        );
      },
    );
  }

  static Widget buildMaintenanceRequestListWithPagination(BuildContext context, {
    required List<Map<String, dynamic>> requests,
    required int currentPage,
    required int totalPages,
    required String Function(String?) getEquipmentName,
    required String Function(String?) getUserName,
    required String Function(String?) getStatusLabel,
    required Color Function(String) getStatusColor,
    required Function(Map<String, dynamic>) onRequestTap,
    required VoidCallback onPreviousPage,
    required VoidCallback onNextPage,
  }) {
    return Column(
      children: [
        Expanded(
          child: buildMaintenanceRequestList(
            context,
            requests: requests,
            getEquipmentName: getEquipmentName,
            getUserName: getUserName,
            getStatusLabel: getStatusLabel,
            getStatusColor: getStatusColor,
            onRequestTap: onRequestTap,
          ),
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
