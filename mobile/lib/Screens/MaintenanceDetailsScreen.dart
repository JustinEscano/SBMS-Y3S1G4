import 'package:flutter/material.dart';
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
    developer.log('User Role in MaintenanceDetailsScreen: ${widget.userRole}', name: 'MaintenanceDetailsScreen');
    try {
      Map<String, dynamic> payload = Jwt.parseJwt(widget.accessToken);
      developer.log('Token Payload: $payload', name: 'MaintenanceDetailsScreen');
      developer.log('Token Role: ${payload['role']}', name: 'MaintenanceDetailsScreen');
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddEditMaintenanceDialog();
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
    } catch (e) {
      developer.log('Error refreshing details: $e', name: 'MaintenanceDetailsScreen');
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
      developer.log('Token refresh error: $e', name: 'MaintenanceDetailsScreen.Auth');
      developer.log('Stack trace: $stackTrace', name: 'MaintenanceDetailsScreen.Auth');
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
    if (filePath == null || filePath.isEmpty) {
      return '';
    }
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    return ApiConfig.getMediaUrl(filePath);
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
    } catch (e) {
      developer.log('Error fetching image data: $e', name: 'MaintenanceDetailsScreen.Image');
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
    } catch (e) {
      developer.log('Error opening attachment: $e', name: 'MaintenanceDetailsScreen.Attachment');
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
          title: const Text('Delete Maintenance Request'),
          content: Text('Are you sure you want to delete this request?\n\n"${issue.length > 100 ? '${issue.substring(0, 100)}...' : issue}"'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
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
      } catch (e) {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading attachment: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _respondToMaintenanceRequest(String requestId, String responseText, String? assignedToId) async {
    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final body = <String, dynamic>{'response': responseText};
      if (assignedToId != null && assignedToId.isNotEmpty) {
        body['assigned_to'] = assignedToId;
      }

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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e'), backgroundColor: Colors.red),
      );
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

      final response = isEditing
          ? await http.put(Uri.parse(url), headers: headers, body: json.encode(requestBody))
          : await http.post(Uri.parse(url), headers: headers, body: json.encode(requestBody));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Request updated successfully' : 'Request created successfully'), backgroundColor: Colors.green),
        );
        widget.onSave();
        Navigator.of(context).pop();
        if (!isEditing) {
          Navigator.of(context).pop();
        }
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ${isEditing ? 'updating' : 'creating'} request: $e'), backgroundColor: Colors.red),
      );
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
    final eq = widget.equipment.firstWhere((e) => e['id'].toString() == equipmentId?.toString(), orElse: () => null);
    return eq?['name'] ?? 'Unknown Equipment';
  }

  String _getUserName(String? userId) {
    final user = widget.users.firstWhere((u) => u['id'].toString() == userId?.toString(), orElse: () => null);
    return user?['username'] ?? 'Unknown User';
  }

  Color _getStatusColor(String status) {
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

  String _getStatusLabel(String? status) {
    final option = widget.statusOptions.firstWhere(
          (option) => option['value'] == status,
      orElse: () => {'value': status ?? '', 'label': status ?? 'Unknown'},
    );
    return option['label']!;
  }

  List<Map<String, String>> get paginatedComments {
    final comments = _parseComments(_requestData['comments']);
    final startIndex = (_currentCommentPage - 1) * _commentsPerPage;
    final endIndex = startIndex + _commentsPerPage;
    return comments.sublist(startIndex, endIndex.clamp(0, comments.length));
  }

  int get totalCommentPages {
    final comments = _parseComments(_requestData['comments']);
    return (comments.length / _commentsPerPage).ceil();
  }

  void _showAddEditMaintenanceDialog() {
    showDialog(
      context: context,
      builder: (context) => MaintenanceAddEditDialog(
        isEditing: widget.request != null,
        users: widget.users,
        equipment: widget.equipment,
        statusOptions: widget.statusOptions,
        userRole: widget.userRole,
        currentUserId: _currentUserId,
        requestData: _requestData,
        onSave: _saveMaintenanceRequest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.request == null || isLoadingDetails) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final attachments = _requestData['attachments'] as List<dynamic>? ?? [];
    final effectiveRole = _verifiedUserRole ?? widget.userRole;
    final canComment = effectiveRole == 'admin' ||
        effectiveRole == 'superadmin' ||
        ((effectiveRole == 'employee' || effectiveRole == 'client') &&
            (_currentUserId != null &&
                (_requestData['user'] != null && _currentUserId == _requestData['user']?.toString() ||
                    _requestData['assigned_to'] != null && _currentUserId == _requestData['assigned_to']?.toString())));

    return Scaffold(
      appBar: AppBar(
        title: Text(_getEquipmentName(_requestData['equipment']?.toString())),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showAddEditMaintenanceDialog,
            tooltip: 'Edit Request',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteMaintenanceRequest(widget.request!['id'].toString(), _requestData['issue'] ?? ''),
            tooltip: 'Delete Request',
          ),
        ],
      ),
      body: isRefreshingToken
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshDetails,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed: Removed getEquipmentName parameter
              MaintenanceRequestDetailsCard(
                requestData: _requestData,
                getStatusLabel: _getStatusLabel,
                getStatusColor: _getStatusColor,
                getUserName: _getUserName,
              ),
              const SizedBox(height: 16),
              MaintenanceCommentsCard(
                paginatedComments: paginatedComments,
                totalCommentPages: totalCommentPages,
                currentCommentPage: _currentCommentPage,
                onPrevious: _currentCommentPage > 1 ? () => setState(() => _currentCommentPage--) : null,
                onNext: _currentCommentPage < totalCommentPages ? () => setState(() => _currentCommentPage++) : null,
              ),
              const SizedBox(height: 32),
              const MaintenanceDivider(),
              const SizedBox(height: 16),
              MaintenanceCommentInput(
                canComment: canComment,
                responseController: _responseController,
                selectedAssignedToId: _selectedAssignedToId,
                onAssignedToChanged: (value) => setState(() => _selectedAssignedToId = value),
                users: widget.users,
                effectiveRole: effectiveRole,
                isRefreshingToken: isRefreshingToken,
                onAddComment: () => _respondToMaintenanceRequest(
                  widget.request!['id'].toString(),
                  _responseController.text,
                  _selectedAssignedToId,
                ),
              ),
              const SizedBox(height: 16),
              if (attachments.isNotEmpty)
                MaintenanceAttachmentsCard(
                  attachments: attachments,
                  getAttachmentUrl: _getAttachmentUrl,
                  fetchImageData: _fetchImageData,
                  openAttachment: _openAttachment,
                  getUserName: _getUserName,
                ),
              const SizedBox(height: 16),
              MaintenanceAddAttachmentButton(
                isRefreshingToken: isRefreshingToken,
                onPressed: () => _uploadAttachment(widget.request!['id'].toString()),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}