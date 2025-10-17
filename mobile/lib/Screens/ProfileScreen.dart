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
import './ProfileDetails.dart';
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
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _organizationController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _profileData;
  File? _profilePicture;
  bool _isLoading = false;
  bool _isProfileDeleted = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

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

  String _getProfilePictureUrl(String? picturePath) {
    if (picturePath == null || picturePath.isEmpty) {
      return '';
    }
    if (picturePath.startsWith('http://') || picturePath.startsWith('https://')) {
      return picturePath;
    }
    return ApiConfig.getMediaUrl(picturePath);
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profileData = await authService.apiService.fetchProfile();
      if (mounted) {
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
        developer.log('Profile picture URL: $profilePictureUrl', name: 'ProfileScreen.Image');
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        final success = await _refreshToken();
        if (success) {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final profileData = await authService.apiService.fetchProfile();
            if (mounted) {
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
              developer.log('Profile picture URL after retry: $profilePictureUrl', name: 'ProfileScreen.Image');
            }
            return;
          } catch (retryError) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error fetching profile after retry: $retryError', style: GoogleFonts.urbanist()),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching profile: $e', style: GoogleFonts.urbanist()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
              Text('Logging out...', style: GoogleFonts.urbanist()),
            ],
          ),
        );
      },
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e', style: GoogleFonts.urbanist()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 50.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'My Profile',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              background: Container(
                color: Color(0xFF1F1E23),
              ),
            ),
            foregroundColor: Colors.white,
            backgroundColor: Color(0xFF1F1E23),
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
                      isEditing: false,
                      isProfileDeleted: _isProfileDeleted,
                      onPickImage: () {}, // No image picking here
                      onCardTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileDetails(
                              accessToken: widget.accessToken,
                              refreshToken: authService.refreshToken ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    ProfileWidgets.buildOptionsCard(context, widget.accessToken, authService.refreshToken ?? ''),
                    const SizedBox(height: 15),
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