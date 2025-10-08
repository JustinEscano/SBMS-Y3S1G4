import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../Config/api.dart';
import './LoginScreen.dart';

class ProfileScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const ProfileScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // SharedPreferences keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Form controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _organizationController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Profile data and state
  Map<String, dynamic>? _profileData;
  File? _profilePicture;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isProfileDeleted = false;

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // Refresh token
  Future<String?> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);
      if (refreshToken == null) {
        throw Exception('No refresh token found');
      }
      final response = await _dio.post(
        ApiConfig.refreshToken,
        data: {'refresh': refreshToken},
      );
      if (response.statusCode == 200) {
        final newAccessToken = response.data['access'];
        await prefs.setString(_accessTokenKey, newAccessToken);
        return newAccessToken;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Helper method to determine the correct profile picture URL
  String _getProfilePictureUrl(String? picturePath) {
    if (picturePath == null || picturePath.isEmpty) {
      return '';
    }
    // Check if the path is already a full URL
    if (picturePath.startsWith('http://') || picturePath.startsWith('https://')) {
      return picturePath;
    }
    // Otherwise, construct the URL using getMediaUrl
    return ApiConfig.getMediaUrl(picturePath);
  }

  // Fetch profile data from backend
  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_accessTokenKey);
      if (token == null) {
        throw Exception('No access token found');
      }

      final response = await _dio.get(
        ApiConfig.profile,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _profileData = response.data;
          _usernameController.text = _profileData?['username'] ?? '';
          _emailController.text = _profileData?['email'] ?? '';
          _fullNameController.text = _profileData?['profile']['full_name'] ?? '';
          _organizationController.text = _profileData?['profile']['organization'] ?? '';
          _addressController.text = _profileData?['profile']['address'] ?? '';
          _isProfileDeleted = false;
        });
        final profilePictureUrl = _getProfilePictureUrl(_profileData?['profile']['profile_picture']);
        if (profilePictureUrl.isNotEmpty) {
          developer.log(
            'Profile picture URL: $profilePictureUrl',
            name: 'ProfileScreen.Image',
          );
        }
      } else {
        throw Exception('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        final newToken = await _refreshToken();
        if (newToken != null) {
          try {
            final response = await _dio.get(
              ApiConfig.profile,
              options: Options(
                headers: {'Authorization': 'Bearer $newToken'},
              ),
            );
            if (response.statusCode == 200) {
              setState(() {
                _profileData = response.data;
                _usernameController.text = _profileData?['username'] ?? '';
                _emailController.text = _profileData?['email'] ?? '';
                _fullNameController.text = _profileData?['profile']['full_name'] ?? '';
                _organizationController.text = _profileData?['profile']['organization'] ?? '';
                _addressController.text = _profileData?['profile']['address'] ?? '';
                _isProfileDeleted = false;
              });
              final profilePictureUrl = _getProfilePictureUrl(_profileData?['profile']['profile_picture']);
              if (profilePictureUrl.isNotEmpty) {
                developer.log(
                  'Profile picture URL after retry: $profilePictureUrl',
                  name: 'ProfileScreen.Image',
                );
              }
              return;
            }
          } catch (retryError) {
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error fetching profile after retry: $retryError'), backgroundColor: Colors.red),
              );
            }
          }
        }
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Pick profile picture
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profilePicture = File(pickedFile.path));
    }
  }

  // Update profile data
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_accessTokenKey);
      if (token == null) {
        throw Exception('No access token found');
      }

      final formData = FormData.fromMap({
        'username': _usernameController.text,
        'email': _emailController.text,
        'full_name': _fullNameController.text,
        'organization': _organizationController.text,
        'address': _addressController.text,
      });

      if (_profilePicture != null) {
        formData.files.add(MapEntry(
          'profile_picture',
          await MultipartFile.fromFile(
            _profilePicture!.path,
            filename: 'profile_picture.jpg',
          ),
        ));
      }

      final response = await _dio.patch(
        ApiConfig.profile,
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _profileData = response.data;
          _profilePicture = null;
          _isEditing = false;
        });
        imageCache.clear();
        imageCache.clearLiveImages();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
        await _fetchProfile();
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        final newToken = await _refreshToken();
        if (newToken != null) {
          try {
            final formData = FormData.fromMap({
              'username': _usernameController.text,
              'email': _emailController.text,
              'full_name': _fullNameController.text,
              'organization': _organizationController.text,
              'address': _addressController.text,
            });

            if (_profilePicture != null) {
              formData.files.add(MapEntry(
                'profile_picture',
                await MultipartFile.fromFile(
                  _profilePicture!.path,
                  filename: 'profile_picture.jpg',
                ),
              ));
            }

            final response = await _dio.patch(
              ApiConfig.profile,
              data: formData,
              options: Options(
                headers: {'Authorization': 'Bearer $newToken'},
              ),
            );

            if (response.statusCode == 200) {
              setState(() {
                _profileData = response.data;
                _profilePicture = null;
                _isEditing = false;
              });
              imageCache.clear();
              imageCache.clearLiveImages();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully')),
                );
              }
              await _fetchProfile();
              return;
            }
          } catch (retryError) {
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating profile after retry: $retryError'), backgroundColor: Colors.red),
              );
            }
          }
        }
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Create new profile
  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_accessTokenKey);
      if (token == null) {
        throw Exception('No access token found');
      }

      final formData = FormData.fromMap({
        'full_name': _fullNameController.text,
        'organization': _organizationController.text,
        'address': _addressController.text,
      });

      if (_profilePicture != null) {
        formData.files.add(MapEntry(
          'profile_picture',
          await MultipartFile.fromFile(
            _profilePicture!.path,
            filename: 'profile_picture.jpg',
          ),
        ));
      }

      final response = await _dio.post(
        ApiConfig.profile,
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201) {
        setState(() {
          _profileData = response.data;
          _profilePicture = null;
          _isEditing = false;
          _isProfileDeleted = false;
        });
        imageCache.clear();
        imageCache.clearLiveImages();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile created successfully')),
          );
        }
        await _fetchProfile();
      } else {
        throw Exception('Failed to create profile: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        final newToken = await _refreshToken();
        if (newToken != null) {
          try {
            final formData = FormData.fromMap({
              'full_name': _fullNameController.text,
              'organization': _organizationController.text,
              'address': _addressController.text,
            });

            if (_profilePicture != null) {
              formData.files.add(MapEntry(
                'profile_picture',
                await MultipartFile.fromFile(
                  _profilePicture!.path,
                  filename: 'profile_picture.jpg',
                ),
              ));
            }

            final response = await _dio.post(
              ApiConfig.profile,
              data: formData,
              options: Options(
                headers: {'Authorization': 'Bearer $newToken'},
              ),
            );

            if (response.statusCode == 201) {
              setState(() {
                _profileData = response.data;
                _profilePicture = null;
                _isEditing = false;
                _isProfileDeleted = false;
              });
              imageCache.clear();
              imageCache.clearLiveImages();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile created successfully')),
                );
              }
              await _fetchProfile();
              return;
            }
          } catch (retryError) {
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error creating profile after retry: $retryError'), backgroundColor: Colors.red),
              );
            }
          }
        }
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Delete profile
  Future<void> _deleteProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_accessTokenKey);
      if (token == null) {
        throw Exception('No access token found');
      }

      final response = await _dio.delete(
        ApiConfig.profile,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 204) {
        setState(() {
          _profileData = null;
          _profilePicture = null;
          _isProfileDeleted = true;
          _fullNameController.clear();
          _organizationController.clear();
          _addressController.clear();
        });
        imageCache.clear();
        imageCache.clearLiveImages();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile deleted successfully')),
          );
        }
      } else {
        throw Exception('Failed to delete profile: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        final newToken = await _refreshToken();
        if (newToken != null) {
          try {
            final response = await _dio.delete(
              ApiConfig.profile,
              options: Options(
                headers: {'Authorization': 'Bearer $newToken'},
              ),
            );

            if (response.statusCode == 204) {
              setState(() {
                _profileData = null;
                _profilePicture = null;
                _isProfileDeleted = true;
                _fullNameController.clear();
                _organizationController.clear();
                _addressController.clear();
              });
              imageCache.clear();
              imageCache.clearLiveImages();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile deleted successfully')),
                );
              }
              return;
            }
          } catch (retryError) {
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting profile after retry: $retryError'), backgroundColor: Colors.red),
              );
            }
          }
        }
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to delete your profile? This action cannot be undone.', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProfile();
              },
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Logout function
  Future<void> _logout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text('Logging out...', style: GoogleFonts.poppins()),
            ],
          ),
        );
      },
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);

      if (context.mounted) {
        Navigator.of(context).pop();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirm Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
              child: Text('Log Out', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar with gradient
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'My Profile',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4B79A1), Color(0xFF283E51)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Colors.white),
                onPressed: () {
                  setState(() => _isEditing = !_isEditing);
                },
              ).animate().fadeIn(duration: 300.ms),
            ],
          ),
          // Main content
          SliverToBoxAdapter(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator()).animate().fadeIn()
                : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    _buildProfileHeader(context),
                    const SizedBox(height: 24),
                    // Profile Fields
                    if (!_isProfileDeleted) _buildProfileFields(),
                    const SizedBox(height: 24),
                    // Action Buttons
                    if (_isEditing) _buildActionButtons(context),
                    const SizedBox(height: 24),
                    // Options Card
                    _buildOptionsCard(context),
                    const SizedBox(height: 24),
                    // Logout Button
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Profile Header Widget
  Widget _buildProfileHeader(BuildContext context) {
    return GestureDetector(
      onTap: _isEditing && !_isProfileDeleted ? _pickImage : null,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(2, 2),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 8,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: _profilePicture != null
                          ? FileImage(_profilePicture!)
                          : (_profileData?['profile']['profile_picture'] != null &&
                          _profileData?['profile']['profile_picture'].isNotEmpty
                          ? NetworkImage(_getProfilePictureUrl(_profileData!['profile']['profile_picture']))
                          : null) as ImageProvider?,
                      backgroundColor: Colors.grey[200],
                      child: _profilePicture == null &&
                          (_profileData?['profile']['profile_picture'] == null ||
                              _profileData?['profile']['profile_picture'].isEmpty)
                          ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                          : null,
                      onBackgroundImageError: (error, stackTrace) {
                        developer.log(
                          'Error loading profile picture: $error',
                          name: 'ProfileScreen.Image',
                          error: error,
                          stackTrace: stackTrace,
                        );
                      },
                    ).animate().scale(duration: 300.ms),
                    if (_isEditing && !_isProfileDeleted)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileData?['profile']['full_name'] ??
                            (_isProfileDeleted ? 'No Profile' : 'User Profile'),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profileData?['email'] ??
                            (_isProfileDeleted ? 'Create a new profile' : 'Smart Building Dashboard User'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  // Profile Fields Widget
  Widget _buildProfileFields() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              validator: (value) => value!.isEmpty ? 'Username is required' : null,
              enabled: _isEditing,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              validator: (value) => value!.contains('@') ? null : 'Invalid email',
              enabled: _isEditing,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: _fullNameController,
              label: 'Full Name',
              enabled: _isEditing,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: _organizationController,
              label: 'Organization',
              enabled: _isEditing,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: _addressController,
              label: 'Address',
              enabled: _isEditing,
            ),
          ],
        ),
      ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),
    );
  }

  // Custom TextField Widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        contentPadding: const EdgeInsets.all(16.0),
        border: InputBorder.none,
      ),
      enabled: enabled,
      style: GoogleFonts.poppins(fontSize: 16),
      validator: validator,
    );
  }

  // Action Buttons Widget
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        if (_isProfileDeleted)
          _buildButton(
            text: 'Create Profile',
            onPressed: _createProfile,
            color: Colors.blue,
          ),
        if (!_isProfileDeleted)
          _buildButton(
            text: 'Save Changes',
            onPressed: _updateProfile,
            color: Colors.blue,
          ),
        if (!_isProfileDeleted)
          _buildButton(
            text: 'Delete Profile',
            onPressed: () => _showDeleteConfirmation(context),
            color: Colors.red,
          ),
      ],
    );
  }

  // Custom Button Widget
  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ).animate().scale(duration: 200.ms),
    );
  }

  // Options Card Widget
  Widget _buildOptionsCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildOptionTile(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settings feature coming soon!', style: GoogleFonts.poppins())),
                );
              },
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: Icons.info,
              title: 'About Us',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('About Us feature coming soon!', style: GoogleFonts.poppins())),
                );
              },
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: Icons.help,
              title: 'Help & Support',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Help & Support feature coming soon!', style: GoogleFonts.poppins())),
                );
              },
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Privacy Policy feature coming soon!', style: GoogleFonts.poppins())),
                );
              },
            ),
          ],
        ),
      ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),
    );
  }

  // Option Tile Widget
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    ).animate().fadeIn(duration: 300.ms);
  }

  // Logout Button Widget
  Widget _buildLogoutButton(BuildContext context) {
    return _buildButton(
      text: 'Log Out',
      onPressed: () => _showLogoutConfirmation(context),
      color: Colors.red,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _organizationController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}