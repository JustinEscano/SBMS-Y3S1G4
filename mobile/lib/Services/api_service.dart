import 'package:dio/dio.dart';
import 'package:mobile/Services/auth_service.dart';
import 'package:mobile/utils/constants.dart';
import 'dart:io';

class ApiService {
  final AuthService _authService;
  final Dio _dio;

  ApiService(this._authService) : _dio = Dio();

  Future<List<dynamic>> fetchRooms() async {
    final headers = _authService.getAuthHeaders();
    final response = await _dio.get(
      ApiConfig.rooms,
      options: Options(headers: headers),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.data is List ? response.data : [];
    }
    throw Exception('Failed to load rooms: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchEquipment() async {
    final headers = _authService.getAuthHeaders();
    final response = await _dio.get(
      ApiConfig.equipment,
      options: Options(headers: headers),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.data is List ? response.data : [];
    }
    throw Exception('Failed to load equipment: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchSensorLogs() async {
    final headers = _authService.getAuthHeaders();
    final response = await _dio.get(
      ApiConfig.sensorLog,
      options: Options(headers: headers),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.data is List ? response.data : [];
    }
    throw Exception('Failed to load sensor logs: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchLatestSensorData() async {
    final headers = _authService.getAuthHeaders();
    final response = await _dio.get(
      ApiConfig.latestSensorData,
      options: Options(headers: headers),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = response.data;
      return data['success'] == true ? (data['data'] ?? []) : [];
    }
    throw Exception('Failed to load latest sensor data: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchMaintenanceRequests() async {
    final headers = _authService.getAuthHeaders();
    final response = await _dio.get(
      ApiConfig.maintenanceRequest,
      options: Options(headers: headers),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.data is List ? response.data : [];
    }
    throw Exception('Failed to load maintenance requests: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchNotifications() async {
    final headers = _authService.getAuthHeaders();
    final response = await _dio.get(
      ApiConfig.notification(page: 1, pageSize: 10),
      options: Options(headers: headers),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = response.data;
      return data['results'] is List ? data['results'] : [];
    }
    throw Exception('Failed to load notifications: ${response.statusCode}');
  }

  Future<String> fetchUserRole() async {
    if (!(await _authService.ensureValidToken())) {
      throw Exception('Invalid or expired token');
    }
    final headers = _authService.getAuthHeaders();
    final response = await _dio.get(
      ApiConfig.userInfo,
      options: Options(headers: headers),
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final userData = response.data;
      String role = userData['role']?.toString().toLowerCase() ?? 'client';
      if (!['client', 'employee', 'admin', 'superadmin'].contains(role)) {
        role = 'client';
      }
      print('Fetched role: $role');
      return role;
    }
    throw Exception('Failed to load user role: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    if (!(await _authService.ensureValidToken())) {
      throw Exception('Invalid or expired token');
    }
    final headers = _authService.getAuthHeaders();
    final response = await _dio.get(
      ApiConfig.profile,
      options: Options(headers: headers),
    );
    if (response.statusCode == 200) {
      return response.data;
    }
    throw Exception('Failed to fetch profile: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> updateProfile({
    required String username,
    required String email,
    required String fullName,
    required String organization,
    required String address,
    File? profilePicture,
  }) async {
    if (!(await _authService.ensureValidToken())) {
      throw Exception('Invalid or expired token');
    }
    final headers = _authService.getAuthHeaders();
    final formData = FormData.fromMap({
      'username': username,
      'email': email,
      'full_name': fullName,
      'organization': organization,
      'address': address,
    });

    if (profilePicture != null) {
      formData.files.add(MapEntry(
        'profile_picture',
        await MultipartFile.fromFile(
          profilePicture.path,
          filename: 'profile_picture.jpg',
        ),
      ));
    }

    final response = await _dio.patch(
      ApiConfig.profile,
      data: formData,
      options: Options(headers: headers),
    );

    if (response.statusCode == 200) {
      return response.data;
    }
    throw Exception('Failed to update profile: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createProfile({
    required String fullName,
    required String organization,
    required String address,
    File? profilePicture,
  }) async {
    if (!(await _authService.ensureValidToken())) {
      throw Exception('Invalid or expired token');
    }
    final headers = _authService.getAuthHeaders();
    final formData = FormData.fromMap({
      'full_name': fullName,
      'organization': organization,
      'address': address,
    });

    if (profilePicture != null) {
      formData.files.add(MapEntry(
        'profile_picture',
        await MultipartFile.fromFile(
          profilePicture.path,
          filename: 'profile_picture.jpg',
        ),
      ));
    }

    final response = await _dio.post(
      ApiConfig.profile,
      data: formData,
      options: Options(headers: headers),
    );

    if (response.statusCode == 201) {
      return response.data;
    }
    throw Exception('Failed to create profile: ${response.statusCode}');
  }

  Future<void> deleteProfile() async {
    if (!(await _authService.ensureValidToken())) {
      throw Exception('Invalid or expired token');
    }
    final headers = _authService.getAuthHeaders();
    final response = await _dio.delete(
      ApiConfig.profile,
      options: Options(headers: headers),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete profile: ${response.statusCode}');
    }
  }
}