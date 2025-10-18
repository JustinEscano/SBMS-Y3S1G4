import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Config/api.dart';
import '../Services/auth_service.dart';
import '../Widgets/RoomManagementWidgets.dart';

class RoomManagementScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const RoomManagementScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  List<dynamic> rooms = [];
  bool isLoading = true;
  bool isRefreshingToken = false;
  String _errorMessage = '';

  static const List<Map<String, String>> ROOM_TYPE_OPTIONS = [
    {'value': 'office', 'label': 'Office', 'description': 'Office spaces'},
    {'value': 'lab', 'label': 'Laboratory', 'description': 'Laboratory and research spaces'},
    {'value': 'meeting', 'label': 'Meeting Room', 'description': 'Conference and meeting rooms'},
    {'value': 'storage', 'label': 'Storage', 'description': 'Storage areas and warehouses'},
    {'value': 'corridor', 'label': 'Corridor', 'description': 'Hallways and corridors'},
    {'value': 'utility', 'label': 'Utility', 'description': 'Utility and service rooms'},
  ];

  @override
  void initState() {
    super.initState();
    AuthService().setTokens(widget.accessToken, widget.refreshToken);
    _loadRooms();
  }

  Future<bool> _refreshToken() async {
    setState(() {
      isRefreshingToken = true;
      _errorMessage = 'Refreshing session...';
    });
    try {
      final success = await AuthService().refresh();
      if (success) {
        return true;
      }
      setState(() {
        _errorMessage = 'Failed to refresh session. Please log in again.';
      });
      return false;
    } catch (e) {
      setState(() {
        _errorMessage = 'Error refreshing session: $e';
      });
      return false;
    } finally {
      setState(() {
        isRefreshingToken = false;
      });
    }
  }

  Future<void> _loadRooms() async {
    setState(() {
      isLoading = true;
      _errorMessage = '';
    });

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();

      final response = await http.get(
        Uri.parse(ApiConfig.rooms),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final roomsData = json.decode(response.body);
        setState(() {
          rooms = roomsData is List ? roomsData : [];
        });
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _loadRooms();
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load rooms. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('Session expired') ? e.toString() : 'Error loading rooms: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteRoom(String roomId, String roomName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return RoomManagementWidgets.buildDeleteConfirmationDialog(
          roomName: roomName,
          onConfirm: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );

    if (confirmed == true) {
      try {
        if (!(await AuthService().ensureValidToken())) {
          throw Exception('Session expired. Please log in again.');
        }
        final headers = AuthService().getAuthHeaders();

        final response = await http.delete(
          Uri.parse('${ApiConfig.rooms}$roomId/'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Room "$roomName" deleted successfully',
                style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _loadRooms();
        } else if (response.statusCode == 401) {
          if (await _refreshToken()) {
            return _deleteRoom(roomId, roomName);
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete room. Status: ${response.statusCode}',
                style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting room: $e',
              style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showAddEditRoomDialog({Map<String, dynamic>? room}) {
    final isEditing = room != null;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1E1E1E),
          child: RoomManagementWidgets.buildAddEditRoomDialog(
            context,
            isEditing: isEditing,
            room: room,
            roomTypeOptions: ROOM_TYPE_OPTIONS,
            onSave: (roomId, name, floor, capacity, type) => _saveRoom(
              roomId,
              name,
              floor,
              capacity,
              type,
              isEditing,
            ),
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _saveRoom(
      String? roomId,
      String name,
      String floor,
      String capacity,
      String type,
      bool isEditing,
      ) async {
    if (name.isEmpty || floor.isEmpty || capacity.isEmpty || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all required fields',
            style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    int? floorNumber = int.tryParse(floor);
    int? capacityNumber = int.tryParse(capacity);

    if (floorNumber == null || capacityNumber == null || capacityNumber <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter valid numbers for floor and capacity',
            style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      if (!(await AuthService().ensureValidToken())) {
        throw Exception('Session expired. Please log in again.');
      }
      final headers = AuthService().getAuthHeaders();
      final requestBody = {
        'name': name,
        'floor': floorNumber,
        'capacity': capacityNumber,
        'type': type,
      };

      final url = isEditing ? '${ApiConfig.rooms}$roomId/' : ApiConfig.rooms;

      final response = isEditing
          ? await http.put(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10))
          : await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Room updated successfully' : 'Room added successfully',
              style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadRooms();
      } else if (response.statusCode == 401) {
        if (await _refreshToken()) {
          return _saveRoom(
            roomId,
            name,
            floor,
            capacity,
            type,
            isEditing,
          );
        } else {
          throw Exception('Session expired. Please log in again.');
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to ${isEditing ? 'update' : 'add'} room.';
        if (errorData is Map && errorData.containsKey('name')) {
          errorMessage += ' Room name already exists.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error ${isEditing ? 'updating' : 'adding'} room: $e',
            style: GoogleFonts.urbanist(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _getRoomTypeLabel(String? type) {
    final option = ROOM_TYPE_OPTIONS.firstWhere(
          (option) => option['value'] == type,
      orElse: () => {'value': type ?? '', 'label': type ?? 'Unknown'},
    );
    return option['label']!;
  }

  @override
  Widget build(BuildContext context) {
    final totalCapacity = rooms.fold<int>(0, (sum, room) => sum + (room['capacity'] as int? ?? 0));
    final floorCount = rooms.map((room) => room['floor']).toSet().length;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Room Management',
          style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1F1E23),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: isRefreshingToken ? null : _loadRooms,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          RoomManagementWidgets.buildSummaryCards(
            roomCount: rooms.length,
            floorCount: floorCount,
            totalCapacity: totalCapacity,
          ),
          if (_errorMessage.isNotEmpty)
            RoomManagementWidgets.buildErrorBanner(_errorMessage),
          Expanded(
            child: isLoading || isRefreshingToken
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF184BFB)))
                : RefreshIndicator(
              onRefresh: _loadRooms,
              color: const Color(0xFF184BFB),
              backgroundColor: const Color(0xFF1F1E23),
              child: rooms.isEmpty
                  ? RoomManagementWidgets.buildEmptyState(
                onAddRoom: () => _showAddEditRoomDialog(),
                isRefreshingToken: isRefreshingToken,
              )
                  : RoomManagementWidgets.buildRoomList(
                rooms: rooms,
                onDeleteRoom: _deleteRoom,
                onEditRoom: (room) => _showAddEditRoomDialog(room: room),
                getRoomTypeLabel: _getRoomTypeLabel,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: RoomManagementWidgets.buildCustomFAB(
        onPressed: isRefreshingToken ? null : () => _showAddEditRoomDialog(),
        tooltip: 'Add Room',
        isEnabled: !isRefreshingToken,
      ),
    );
  }
}