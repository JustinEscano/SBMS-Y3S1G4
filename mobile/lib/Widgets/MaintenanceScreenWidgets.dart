// lib/Widgets/MaintenanceScreenWidgets.dart
import 'package:flutter/material.dart';

class MaintenanceSummaryCards extends StatelessWidget {
  final int pendingCount;
  final int inProgressCount;
  final int resolvedCount;

  const MaintenanceSummaryCards({
    super.key,
    required this.pendingCount,
    required this.inProgressCount,
    required this.resolvedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryCard(context, 'Pending', pendingCount, Icons.pending, Colors.orange[700]!),
          const SizedBox(width: 12),
          _buildSummaryCard(context, 'In Progress', inProgressCount, Icons.work, Colors.blue[700]!),
          const SizedBox(width: 12),
          _buildSummaryCard(context, 'Resolved', resolvedCount, Icons.check_circle, Colors.green[700]!),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaintenanceFilterDialog extends StatelessWidget {
  final String filterStatus;
  final Function(String) onApply;
  final Function() onClear;
  final List<Map<String, String>> statusOptions;

  const MaintenanceFilterDialog({
    super.key,
    required this.filterStatus,
    required this.onApply,
    required this.onClear,
    required this.statusOptions,
  });

  @override
  Widget build(BuildContext context) {
    String tempFilterStatus = filterStatus;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5, maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogHeader(context, title: 'Filter Maintenance Requests', icon: Icons.filter_list),
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
                    onChanged: (value) => setDialogState(() => tempFilterStatus = value ?? 'all'),
                  ),
                ),
                _buildDialogFooter(
                  context,
                  onAction: () {
                    onApply(tempFilterStatus);
                    Navigator.of(context).pop();
                  },
                  actionText: 'Apply',
                  extraAction: TextButton(
                    onPressed: () {
                      onClear();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogHeader(BuildContext context, {required String title, required IconData icon}) {
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

  Widget _buildDialogFooter(
      BuildContext context,
      {required VoidCallback onAction, required String actionText, Widget? extraAction}
      ) {
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
}

class MaintenanceRequestList extends StatelessWidget {
  final List<dynamic> paginatedRequests;
  final String Function(String?) getEquipmentName;
  final String Function(String?) getUserName;
  final Color Function(String) getStatusColor;
  final String Function(String?) getStatusLabel;
  final Function(Map<String, dynamic>) onTap;

  const MaintenanceRequestList({
    super.key,
    required this.paginatedRequests,
    required this.getEquipmentName,
    required this.getUserName,
    required this.getStatusColor,
    required this.getStatusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: paginatedRequests.length,
      itemBuilder: (context, index) {
        final request = paginatedRequests[index];
        final statusColor = getStatusColor(request['status'] ?? '');
        final equipmentName = getEquipmentName(request['equipment']?.toString());
        final userName = getUserName(request['user']?.toString());
        final statusLabel = getStatusLabel(request['status']);
        final scheduledDate = request['scheduled_date'] != null
            ? '${DateTime.parse(request['scheduled_date']).day}/${DateTime.parse(request['scheduled_date']).month}/${DateTime.parse(request['scheduled_date']).year}'
            : null;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              child: Icon(Icons.build, color: statusColor),
            ),
            title: Text(
              equipmentName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'By: $userName',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (scheduledDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Scheduled: $scheduledDate',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
              ],
            ),
            onTap: () => onTap(request),
          ),
        );
      },
    );
  }
}

class MaintenancePagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const MaintenancePagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Text(
            'Page $currentPage of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class MaintenanceEmptyState extends StatelessWidget {
  final bool hasRequests;
  final VoidCallback? onCreate;

  const MaintenanceEmptyState({
    super.key,
    required this.hasRequests,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
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
          if (onCreate != null)
            ElevatedButton.icon(
              onPressed: onCreate,
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
}

class MaintenanceErrorMessage extends StatelessWidget {
  final String errorMessage;

  const MaintenanceErrorMessage({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
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
}

class MaintenanceFilterChip extends StatelessWidget {
  final String filterStatus;
  final String Function(String?) getStatusLabel;
  final Color Function(String) getStatusColor;
  final VoidCallback onDeleted;

  const MaintenanceFilterChip({
    super.key,
    required this.filterStatus,
    required this.getStatusLabel,
    required this.getStatusColor,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Chip(
        label: Text('Status: ${getStatusLabel(filterStatus)}', style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: getStatusColor(filterStatus).withOpacity(0.1),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onDeleted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}