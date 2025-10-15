import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../utils/constants.dart';
import '../Services/auth_service.dart';
import './LoginScreen.dart';
import '../Widgets/ProfileWidgets.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // Refresh token
  Future<bool> _refreshToken() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.refresh();
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, authService.accessToken!);
        await prefs.setString(_refreshTokenKey, authService.refreshToken!);
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Token refresh failed: $e', name: 'ProfileScreen.Token');
      return false;
    }
  }

  // Helper method to determine the correct profile picture URL
  String _getProfilePictureUrl(String? picturePath) {
    if (picturePath == null || picturePath.isEmpty) {
      return '';
    }
    if (picturePath.startsWith('http://') || picturePath.startsWith('https://')) {
      return picturePath;
    }
    return ApiConfig.getMediaUrl(picturePath);
  }

  // Fetch profile data from backend
  Future<void> _fetchProfile() async {
    if (!mounted) return; // Check if widget is mounted
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profileData = await authService.apiService.fetchProfile();
      if (mounted) { // Check before setState
        setState(() {
          _profileData = profileData;
          _usernameController.text = _profileData?['username'] ?? '';
          _emailController.text = _profileData?['email'] ?? '';
          _fullNameController.text = _profileData?['profile']['full_name'] ?? '';
          _organizationController.text = _profileData?['profile']['organization'] ?? '';
          _addressController.text = _profileData?['profile']['address'] ?? '';
          _isProfileDeleted = false;
        });
      }
      final profilePictureUrl = _getProfilePictureUrl(_profileData?['profile']['profile_picture']);
      if (profilePictureUrl.isNotEmpty) {
        developer.log(
          'Profile picture URL: $profilePictureUrl',
          name: 'ProfileScreen.Image',
        );
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        final success = await _refreshToken();
        if (success) {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final profileData = await authService.apiService.fetchProfile();
            if (mounted) { // Check before setState
              setState(() {
                _profileData = profileData;
                _usernameController.text = _profileData?['username'] ?? '';
                _emailController.text = _profileData?['email'] ?? '';
                _fullNameController.text = _profileData?['profile']['full_name'] ?? '';
                _organizationController.text = _profileData?['profile']['organization'] ?? '';
                _addressController.text = _profileData?['profile']['address'] ?? '';
                _isProfileDeleted = false;
              });
            }
            final profilePictureUrl = _getProfilePictureUrl(_profileData?['profile']['profile_picture']);
            if (profilePictureUrl.isNotEmpty) {
              developer.log(
                'Profile picture URL after retry: $profilePictureUrl',
                name: 'ProfileScreen.Image',
              );
            }
            return;
          } catch (retryError) {
            if (mounted) { // Check before navigation and SnackBar
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
        if (mounted) { // Check before navigation
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (mounted) { // Check before SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) { // Check before setState
        setState(() => _isLoading = false);
      }
    }
  }

  // Pick profile picture
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) { // Check before setState
      setState(() => _profilePicture = File(pickedFile.path));
    }
  }

  // Update profile data
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return; // Check if widget is mounted
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profileData = await authService.apiService.updateProfile(
        username: _usernameController.text,
        email: _emailController.text,
        fullName: _fullNameController.text,
        organization: _organizationController.text,
        address: _addressController.text,
        profilePicture: _profilePicture,
      );
      if (mounted) { // Check before setState
        setState(() {
          _profileData = profileData;
          _profilePicture = null;
          _isEditing = false;
        });
      }
      imageCache.clear();
      imageCache.clearLiveImages();
      if (mounted) { // Check before SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
      await _fetchProfile();
    } catch (e) {
      if (e.toString().contains('401')) {
        final success = await _refreshToken();
        if (success) {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final profileData = await authService.apiService.updateProfile(
              username: _usernameController.text,
              email: _emailController.text,
              fullName: _fullNameController.text,
              organization: _organizationController.text,
              address: _addressController.text,
              profilePicture: _profilePicture,
            );
            if (mounted) { // Check before setState
              setState(() {
                _profileData = profileData;
                _profilePicture = null;
                _isEditing = false;
              });
            }
            imageCache.clear();
            imageCache.clearLiveImages();
            if (mounted) { // Check before SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated successfully')),
              );
            }
            await _fetchProfile();
            return;
          } catch (retryError) {
            if (mounted) { // Check before navigation and SnackBar
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
        if (mounted) { // Check before navigation
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (mounted) { // Check before SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) { // Check before setState
        setState(() => _isLoading = false);
      }
    }
  }

  // Create new profile
  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return; // Check if widget is mounted
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profileData = await authService.apiService.createProfile(
        fullName: _fullNameController.text,
        organization: _organizationController.text,
        address: _addressController.text,
        profilePicture: _profilePicture,
      );
      if (mounted) { // Check before setState
        setState(() {
          _profileData = profileData;
          _profilePicture = null;
          _isEditing = false;
          _isProfileDeleted = false;
        });
      }
      imageCache.clear();
      imageCache.clearLiveImages();
      if (mounted) { // Check before SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile created successfully')),
        );
      }
      await _fetchProfile();
    } catch (e) {
      if (e.toString().contains('401')) {
        final success = await _refreshToken();
        if (success) {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final profileData = await authService.apiService.createProfile(
              fullName: _fullNameController.text,
              organization: _organizationController.text,
              address: _addressController.text,
              profilePicture: _profilePicture,
            );
            if (mounted) { // Check before setState
              setState(() {
                _profileData = profileData;
                _profilePicture = null;
                _isEditing = false;
                _isProfileDeleted = false;
              });
            }
            imageCache.clear();
            imageCache.clearLiveImages();
            if (mounted) { // Check before SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile created successfully')),
              );
            }
            await _fetchProfile();
            return;
          } catch (retryError) {
            if (mounted) { // Check before navigation and SnackBar
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
        if (mounted) { // Check before navigation
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (mounted) { // Check before SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) { // Check before setState
        setState(() => _isLoading = false);
      }
    }
  }

  // Delete profile
  Future<void> _deleteProfile() async {
    if (!mounted) return; // Check if widget is mounted
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.apiService.deleteProfile();
      if (mounted) { // Check before setState
        setState(() {
          _profileData = null;
          _profilePicture = null;
          _isProfileDeleted = true;
          _fullNameController.clear();
          _organizationController.clear();
          _addressController.clear();
        });
      }
      imageCache.clear();
      imageCache.clearLiveImages();
      if (mounted) { // Check before SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile deleted successfully')),
        );
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        final success = await _refreshToken();
        if (success) {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            await authService.apiService.deleteProfile();
            if (mounted) { // Check before setState
              setState(() {
                _profileData = null;
                _profilePicture = null;
                _isProfileDeleted = true;
                _fullNameController.clear();
                _organizationController.clear();
                _addressController.clear();
              });
            }
            imageCache.clear();
            imageCache.clearLiveImages();
            if (mounted) { // Check before SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile deleted successfully')),
              );
            }
            return;
          } catch (retryError) {
            if (mounted) { // Check before navigation and SnackBar
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
        if (mounted) { // Check before navigation
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (mounted) { // Check before SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) { // Check before setState
        setState(() => _isLoading = false);
      }
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
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      if (mounted) { // Check before navigation
        Navigator.of(context).pop();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) { // Check before navigation and SnackBar
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
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
                color: Color.fromRGBO(31, 30, 35, 100),
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
            foregroundColor: Colors.white,
            backgroundColor: Color.fromRGBO(31, 30, 35, 100),
          ),
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
                    ProfileWidgets.buildProfileHeader(
                      context: context,
                      profileData: _profileData,
                      profilePicture: _profilePicture,
                      isEditing: _isEditing,
                      isProfileDeleted: _isProfileDeleted,
                      onPickImage: _pickImage,
                    ),
                    const SizedBox(height: 24),
                    if (!_isProfileDeleted)
                      ProfileWidgets.buildProfileFields(
                        usernameController: _usernameController,
                        emailController: _emailController,
                        fullNameController: _fullNameController,
                        organizationController: _organizationController,
                        addressController: _addressController,
                        isEditing: _isEditing,
                      ),
                    const SizedBox(height: 24),
                    if (_isEditing)
                      ProfileWidgets.buildActionButtons(
                        context: context,
                        isProfileDeleted: _isProfileDeleted,
                        onUpdateProfile: _updateProfile,
                        onCreateProfile: _createProfile,
                        onDeleteProfile: () => _showDeleteConfirmation(context),
                      ),
                    const SizedBox(height: 24),
                    ProfileWidgets.buildOptionsCard(context),
                    const SizedBox(height: 24),
                    ProfileWidgets.buildLogoutButton(
                      context: context,
                      onLogout: () => _logout(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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