import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../Config/api.dart';
import '../Services/auth_service.dart';
import 'package:jwt_decode/jwt_decode.dart';
import '../Widgets/MaintenanceDetailsWidgets.dart';

class MaintenanceDetailsScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;
  final String userRole;
  final List<dynamic> users;
  final List<dynamic> equipment;
  final List<Map<String, String>> statusOptions;
  final Map<String, dynamic>? request;
  final VoidCallback onSave;
  final String? currentUserId;

  const MaintenanceDetailsScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
    required this.userRole,
    required this.users,
    required this.equipment,
    required this.statusOptions,
    this.request,
    required this.onSave,
    this.currentUserId,
  });

  @override
  State<MaintenanceDetailsScreen> createState() => _MaintenanceDetailsScreenState();
}

class _MaintenanceDetailsScreenState extends State<MaintenanceDetailsScreen> {
  final TextEditingController _responseController = TextEditingController();
  String? _selectedAssignedToId;
  int _currentCommentPage = 1;
  final int _commentsPerPage = 5;
  bool isRefreshingToken = false;
  bool isLoadingDetails = true;
  String? _currentUserId;
  String? _verifiedUserRole;
  Map<String, dynamic> _requestData = {};

  @override
  void initState() {
    super.initState();
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
    developer.log('User Role: ${widget.userRole}', name: 'MaintenanceDetailsScreen');
    try {
      Map<String, dynamic> payload = Jwt.parseJwt(widget.accessToken);
      developer.log('Token Payload: $payload', name: 'MaintenanceDetailsScreen');
      setState(() {
        _verifiedUserRole = payload['role']?.toString();
        _currentUserId = widget.currentUserId ?? payload['user_id']?.toString();
      });
    } catch (e) {
      developer.log('Error decoding token: $e', name: 'MaintenanceDetailsScreen');
      setState(() {
        _verifiedUserRole = null;
        _currentUserId = widget.currentUserId;
      });
    }
    _requestData = Map.from(widget.request ?? {});
    if (widget.request == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final result = await _showAddEditMaintenanceDialog();
        Navigator.pop(context, result);
      });
    } else {
      _refreshDetails();
    }
  }

  Future<void> _refreshDetails() async {
    if (widget.request == null) return;
    setState(() {
      isLoadingDetails = true;
    });
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.maintenanceRequestDetail(widget.request!['id'].toString())),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _requestData = json.decode(response.body);
          developer.log('Loaded request details: $_requestData', name: 'MaintenanceDetailsScreen');
        });
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _refreshDetails();
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        throw Exception('Failed to load request details: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log('Error refreshing details: $e\nStack trace: $stackTrace', name: 'MaintenanceDetailsScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading details: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoadingDetails = false;
      });
    }
  }

  Future<bool> _refreshToken() async {
    setState(() {
      isRefreshingToken = true;
    });
    try {
      final success = await AuthService().refresh();
      if (success) {
        developer.log('Token refreshed successfully', name: 'MaintenanceDetailsScreen.Auth');
        return true;
      }
      developer.log('Token refresh failed', name: 'MaintenanceDetailsScreen.Auth');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to refresh session. Please log in again.'), backgroundColor: Colors.red),
      );
      return false;
    } catch (e, stackTrace) {
      developer.log('Token refresh error: $e\nStack trace: $stackTrace', name: 'MaintenanceDetailsScreen.Auth');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing session: $e'), backgroundColor: Colors.red),
      );
      return false;
    } finally {
      setState(() {
        isRefreshingToken = false;
      });
    }
  }

  String _getAttachmentUrl(String? filePath) {
    if (filePath == null || filePath.isEmpty) return '';
    return filePath.startsWith('http://') || filePath.startsWith('https://')
        ? filePath
        : ApiConfig.getMediaUrl(filePath);
  }

  Future<Uint8List?> _fetchImageData(String url) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final mediaUrl = _getAttachmentUrl(url);
      final uri = Uri.parse(mediaUrl);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return await _fetchImageData(url);
        }
      }
      return null;
    } catch (e, stackTrace) {
      developer.log('Error fetching image: $e\nStack trace: $stackTrace', name: 'MaintenanceDetailsScreen.Image');
      return null;
    }
  }

  Future<void> _openAttachment(String url, String fileName) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final mediaUrl = _getAttachmentUrl(url);
      final uri = Uri.parse(mediaUrl);
      developer.log('Opening attachment: $mediaUrl', name: 'MaintenanceDetailsScreen.Attachment');

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        final result = await OpenFilex.open(filePath);
        if (result.message.isNotEmpty && result.message != 'done') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open $fileName: ${result.message}'), backgroundColor: Colors.red),
          );
        }
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _openAttachment(url, fileName);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download $fileName: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e, stackTrace) {
      developer.log('Error opening attachment: $e\nStack trace: $stackTrace', name: 'MaintenanceDetailsScreen.Attachment');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening $fileName: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteMaintenanceRequest(String requestId, String issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Delete Maintenance Request', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to delete this request?\n\n"${issue.length > 100 ? '${issue.substring(0, 100)}...' : issue}"',
            style: GoogleFonts.urbanist(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.urbanist(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete', style: GoogleFonts.urbanist(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        if (!(await AuthService().ensureValidToken())) {
          throw Exception('Session expired. Please log in again.');
        }
        final url = ApiConfig.maintenanceRequestDetail(requestId);
        final headers = AuthService().getAuthHeaders();

        final response = await http.delete(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

        if (response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request deleted successfully'), backgroundColor: Colors.green),
          );
          widget.onSave();
          Navigator.of(context).pop();
        } else if (response.statusCode == 401) {
          if (await _refreshToken()) {
            return _deleteMaintenanceRequest(requestId, issue);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      } catch (e, stackTrace) {
        developer.log('Error deleting request: $e\nStack trace: $stackTrace', name: 'MaintenanceDetailsScreen');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadAttachment(String requestId) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          isLoadingDetails = true;
        });
        final file = result.files.single;
        final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.maintenanceRequestUploadAttachment(requestId)));
        request.headers.addAll(headers);
        request.files.add(await http.MultipartFile.fromPath('file', file.path!));
        request.fields['file_name'] = file.name;

        final response = await request.send().timeout(const Duration(seconds: 10));
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attachment uploaded successfully'), backgroundColor: Colors.green),
          );
          _refreshDetails();
        } else if (response.statusCode == 401) {
          if (await _refreshToken()) {
            return _uploadAttachment(requestId);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error uploading attachment: $e\nStack trace: $stackTrace', name: 'MaintenanceDetailsScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading attachment: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoadingDetails = false;
      });
    }
  }

  Future<void> _respondToMaintenanceRequest(String requestId, String responseText, String? assignedToId) async {
    if (responseText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot be empty'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final body = <String, dynamic>{'response': responseText};
      if (assignedToId != null && assignedToId.isNotEmpty) {
        body['assigned_to'] = assignedToId;
      }

      setState(() {
        isLoadingDetails = true;
      });
      final response = await http.post(
        Uri.parse(ApiConfig.maintenanceRequestRespond(requestId)),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully'), backgroundColor: Colors.green),
        );
        _responseController.clear();
        setState(() {
          _selectedAssignedToId = null;
          _currentCommentPage = 1;
        });
        _refreshDetails();
        widget.onSave();
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _respondToMaintenanceRequest(requestId, responseText, assignedToId);
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: ${errorData['error'] ?? 'Status ${response.statusCode}'}'), backgroundColor: Colors.red),
        );
      }
    } catch (e, stackTrace) {
      developer.log('Error adding comment: $e\nStack trace: $stackTrace', name: 'MaintenanceDetailsScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoadingDetails = false;
      });
    }
  }

  Future<void> _saveMaintenanceRequest({
    String? requestId,
    required String userId,
    required String equipmentId,
    required String issue,
    required String status,
    required DateTime scheduledDate,
    DateTime? resolvedAt,
    required bool isEditing,
  }) async {
    if (issue.isEmpty || equipmentId.isEmpty || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in required fields (User, Equipment, Issue)'), backgroundColor: Colors.red),
      );
      return;
    }

    if (status == 'resolved' && resolvedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resolved requests require a resolved date'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final requestBody = <String, dynamic>{
        'user': userId,
        'equipment': equipmentId,
        'issue': issue,
        'status': status,
        'scheduled_date': '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
      };

      if (resolvedAt != null) {
        requestBody['resolved_at'] = resolvedAt.toIso8601String();
      }

      final url = isEditing ? ApiConfig.maintenanceRequestDetail(requestId!) : ApiConfig.maintenanceRequest;

      setState(() {
        isLoadingDetails = true;
      });
      final response = isEditing
          ? await http.put(Uri.parse(url), headers: headers, body: json.encode(requestBody))
          : await http.post(Uri.parse(url), headers: headers, body: json.encode(requestBody));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Request updated successfully' : 'Request created successfully'), backgroundColor: Colors.green),
        );
        widget.onSave();
        Navigator.of(context).pop(true);  // Pop dialog with true to indicate save
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _saveMaintenanceRequest(
            requestId: requestId,
            userId: userId,
            equipmentId: equipmentId,
            issue: issue,
            status: status,
            scheduledDate: scheduledDate,
            resolvedAt: resolvedAt,
            isEditing: isEditing,
          );
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${isEditing ? 'update' : 'create'} request: ${errorData['error'] ?? response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e, stackTrace) {
      developer.log('Error saving request: $e\nStack trace: $stackTrace', name: 'MaintenanceDetailsScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ${isEditing ? 'updating' : 'creating'} request: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoadingDetails = false;
      });
    }
  }

  List<Map<String, String>> _parseComments(String? comments) {
    if (comments == null || comments.trim().isEmpty) return [];
    final commentList = comments.split('\n').where((line) => line.trim().isNotEmpty).toList();
    return commentList.map((comment) {
      final match = RegExp(r'\[(.*?)\]\s*(.*?)\s*\((.*?)\):\s*(.*)').firstMatch(comment);
      return {
        'timestamp': match?.group(1) ?? '',
        'user': match?.group(2) ?? '',
        'role': match?.group(3) ?? '',
        'text': match?.group(4) ?? comment,
      };
    }).toList();
  }

  String _getEquipmentName(String? equipmentId) {
    final eq = widget.equipment.firstWhere((e) => e['id']?.toString() == equipmentId, orElse: () => {});
    return eq['name'] as String? ?? 'Unknown Equipment';
  }

  String _getUserName(String? userId) {
    final user = widget.users.firstWhere((u) => u['id']?.toString() == userId, orElse: () => {});
    return user['username'] as String? ?? 'Unknown User';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
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

  String _getStatusLabel(String? status) {
    final option = widget.statusOptions.firstWhere(
          (option) => option['value'] == status,
      orElse: () => {'value': status ?? '', 'label': status ?? 'Unknown'},
    );
    return option['label']!;
  }

  List<Map<String, String>> get paginatedComments {
    final comments = _parseComments(_requestData['comments'] as String?);
    final startIndex = (_currentCommentPage - 1) * _commentsPerPage;
    final endIndex = startIndex + _commentsPerPage;
    return comments.sublist(startIndex, endIndex.clamp(0, comments.length));
  }

  int get totalCommentPages {
    final comments = _parseComments(_requestData['comments'] as String?);
    return (comments.length / _commentsPerPage).ceil();
  }

  Future<bool?> _showAddEditMaintenanceDialog() async {
    final isEditing = widget.request != null;
    final issueController = TextEditingController(text: _requestData['issue'] as String? ?? '');
    String selectedUserId = widget.userRole == 'client' && !isEditing
        ? _currentUserId ?? (widget.users.isNotEmpty ? widget.users.first['id'].toString() : '')
        : _requestData['user']?.toString() ?? (widget.users.isNotEmpty ? widget.users.first['id'].toString() : '');
    String selectedEquipmentId = _requestData['equipment']?.toString() ?? (widget.equipment.isNotEmpty ? widget.equipment.first['id'].toString() : '');
    String selectedStatus = _requestData['status'] as String? ?? 'pending';
    DateTime selectedDate = _requestData['scheduled_date'] != null
        ? DateTime.tryParse(_requestData['scheduled_date'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 1))
        : DateTime.now().add(const Duration(days: 1));
    DateTime? resolvedDate = _requestData['resolved_at'] != null
        ? DateTime.tryParse(_requestData['resolved_at'] as String? ?? '')
        : null;

    if (widget.users.isEmpty || widget.equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot create/edit request: Users or equipment data not loaded'), backgroundColor: Colors.red),
      );
      return false;
    }

    if (isEditing && widget.userRole == 'client' && _requestData['user']?.toString() != _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit your own requests'), backgroundColor: Colors.red),
      );
      return false;
    }

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return MaintenanceDetailsWidgets.buildAddEditMaintenanceDialog(
              context,
              isEditing: isEditing,
              requestData: _requestData,
              users: widget.users,
              equipment: widget.equipment,
              statusOptions: widget.statusOptions,
              userRole: widget.userRole,
              currentUserId: _currentUserId,
              issueController: issueController,
              selectedUserId: selectedUserId,
              selectedEquipmentId: selectedEquipmentId,
              selectedStatus: selectedStatus,
              selectedDate: selectedDate,
              resolvedDate: resolvedDate,
              onUserIdChanged: (value) => setDialogState(() => selectedUserId = value),
              onEquipmentIdChanged: (value) => setDialogState(() => selectedEquipmentId = value),
              onStatusChanged: (value) {
                setDialogState(() {
                  selectedStatus = value;
                  if (selectedStatus != 'resolved') resolvedDate = null;
                });
              },
              onDateChanged: (value) => setDialogState(() => selectedDate = value),
              onResolvedDateChanged: (value) => setDialogState(() => resolvedDate = value),
              onSave: () {
                _saveMaintenanceRequest(
                  requestId: widget.request?['id']?.toString(),
                  userId: selectedUserId,
                  equipmentId: selectedEquipmentId,
                  issue: issueController.text,
                  status: selectedStatus,
                  scheduledDate: selectedDate,
                  resolvedAt: resolvedDate,
                  isEditing: isEditing,
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.request == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: const SizedBox(),  // Empty body since dialog will cover
      );
    }

    if (isLoadingDetails) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      );
    }

    final statusColor = _getStatusColor(_requestData['status'] as String?);
    final attachments = _requestData['attachments'] as List<dynamic>? ?? [];
    final effectiveRole = _verifiedUserRole ?? widget.userRole;
    final canComment = effectiveRole == 'admin' ||
        effectiveRole == 'superadmin' ||
        ((effectiveRole == 'employee' || effectiveRole == 'client') &&
            (_currentUserId != null &&
                (_requestData['user']?.toString() == _currentUserId || _requestData['assigned_to']?.toString() == _currentUserId)));
    final canEdit = effectiveRole == 'admin' || effectiveRole == 'superadmin' || (effectiveRole == 'client' && _requestData['user']?.toString() == _currentUserId);
    final canDelete = effectiveRole == 'admin' || effectiveRole == 'superadmin';

    developer.log('Can Comment: $canComment, Can Edit: $canEdit, Can Delete: $canDelete', name: 'MaintenanceDetailsScreen');
    developer.log('Effective Role: $effectiveRole, Current User ID: $_currentUserId', name: 'MaintenanceDetailsScreen');

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          _getEquipmentName(_requestData['equipment']?.toString()),
          style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1F1E23),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: _showAddEditMaintenanceDialog,
              tooltip: 'Edit Request',
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteMaintenanceRequest(widget.request!['id'].toString(), _requestData['issue'] as String? ?? ''),
              tooltip: 'Delete Request',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isRefreshingToken
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : RefreshIndicator(
              onRefresh: _refreshDetails,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: const Color(0xFF1F1E1E),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MaintenanceDetailsWidgets.buildRequestDetailsCard(
                    context,
                    requestData: _requestData,
                    getEquipmentName: _getEquipmentName,
                    getUserName: _getUserName,
                    getStatusLabel: _getStatusLabel,
                    getStatusColor: _getStatusColor,
                  ),
                  const SizedBox(height: 16),
                  MaintenanceDetailsWidgets.buildCommentSection(
                    context,
                    comments: paginatedComments,
                    currentPage: _currentCommentPage,
                    totalPages: totalCommentPages,
                    onPreviousPage: () => setState(() => _currentCommentPage--),
                    onNextPage: () => setState(() => _currentCommentPage++),
                  ),
                  const SizedBox(height: 16),
                  MaintenanceDetailsWidgets.buildCommentInputSection(
                    context,
                    responseController: _responseController,
                    canComment: canComment,
                    effectiveRole: effectiveRole,
                    onAddComment: () => _respondToMaintenanceRequest(
                      widget.request!['id'].toString(),
                      _responseController.text,
                      _selectedAssignedToId,
                    ),
                    selectedAssignedToId: _selectedAssignedToId,
                    users: widget.users,
                    onAssignedToChanged: (value) => setState(() => _selectedAssignedToId = value),
                    isRefreshingToken: isRefreshingToken,
                  ),
                  const SizedBox(height: 16),
                  MaintenanceDetailsWidgets.buildAttachmentSection(
                    context,
                    attachments: attachments,
                    getAttachmentUrl: _getAttachmentUrl,
                    fetchImageData: _fetchImageData,
                    openAttachment: _openAttachment,
                    getUserName: _getUserName,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      onPressed: isRefreshingToken ? null : () => _uploadAttachment(widget.request!['id'].toString()),
                      icon: const Icon(Icons.attach_file, color: Colors.white),
                      label: Text(
                        'Add Attachment',
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF184BFB),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}