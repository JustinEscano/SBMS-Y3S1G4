import 'package:dio/dio.dart';
import 'package:Orbit/Services/auth_service.dart';
import 'package:Orbit/utils/constants.dart';
import 'dart:io';

class ApiService {
  final AuthService _authService;
  final Dio _dio;

  ApiService(this._authService) : _dio = Dio() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (await _authService.ensureValidToken()) {
          options.headers.addAll(_authService.getAuthHeaders());
        } else {
          print('No valid token available for request: ${options.uri}');
        }
        return handler.next(options);
      },
      onError: (DioError error, handler) async {
        if (error.response?.statusCode == 401) {
          print('401 Unauthorized detected. Attempting token refresh...');
          if (await _authService.refresh()) {
            print('Token refreshed successfully. Retrying request...');
            error.requestOptions.headers.addAll(_authService.getAuthHeaders());
            try {
              final retryResponse = await _dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            } catch (retryError) {
              print('Retry failed: $retryError');
              return handler.reject(error);
            }
          } else {
            print('Token refresh failed. Logging out...');
            await _authService.logout();
            return handler.reject(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<List<dynamic>> fetchRooms() async {
    final response = await _dio.get(
      ApiConfig.rooms,
      options: Options(headers: _authService.getAuthHeaders()),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.data is List ? response.data : [];
    }
    throw Exception('Failed to load rooms: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchEquipment() async {
    final response = await _dio.get(
      ApiConfig.equipment,
      options: Options(headers: _authService.getAuthHeaders()),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.data is List ? response.data : [];
    }
    throw Exception('Failed to load equipment: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchSensorLogs() async {
    final response = await _dio.get(
      ApiConfig.sensorLog,
      options: Options(headers: _authService.getAuthHeaders()),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.data is List ? response.data : [];
    }
    throw Exception('Failed to load sensor logs: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchLatestSensorData() async {
    final response = await _dio.get(
      ApiConfig.latestSensorData,
      options: Options(headers: _authService.getAuthHeaders()),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = response.data;
      return data['success'] == true ? (data['data'] ?? []) : [];
    }
    throw Exception('Failed to load latest sensor data: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchMaintenanceRequests() async {
    final response = await _dio.get(
      ApiConfig.maintenanceRequest,
      options: Options(headers: _authService.getAuthHeaders()),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.data is List ? response.data : [];
    }
    throw Exception('Failed to load maintenance requests: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchNotifications() async {
    final response = await _dio.get(
      ApiConfig.notification(page: 1, pageSize: 10),
      options: Options(headers: _authService.getAuthHeaders()),
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
    final response = await _dio.get(
      ApiConfig.userInfo,
      options: Options(headers: _authService.getAuthHeaders()),
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
    final response = await _dio.get(
      ApiConfig.profile,
      options: Options(headers: _authService.getAuthHeaders()),
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
      options: Options(headers: _authService.getAuthHeaders()),
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
      options: Options(headers: _authService.getAuthHeaders()),
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
    final response = await _dio.delete(
      ApiConfig.profile,
      options: Options(headers: _authService.getAuthHeaders()),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete profile: ${response.statusCode}');
    }
  }
}