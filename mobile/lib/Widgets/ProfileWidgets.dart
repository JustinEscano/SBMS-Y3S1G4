import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../utils/constants.dart';

class ProfileWidgets {
  static Widget buildProfileHeader({
    required BuildContext context,
    required Map<String, dynamic>? profileData,
    required File? profilePicture,
    required bool isEditing,
    required bool isProfileDeleted,
    required VoidCallback onPickImage,
  }) {
    String _getProfilePictureUrl(String? picturePath) {
      if (picturePath == null || picturePath.isEmpty) {
        return '';
      }
      if (picturePath.startsWith('http://') || picturePath.startsWith('https://')) {
        return picturePath;
      }
      return ApiConfig.getMediaUrl(picturePath);
    }

    // Determine image source
    ImageProvider? backgroundImage;
    bool hasImage = false;

    if (profilePicture != null) {
      // Use local file if available (e.g., during editing)
      backgroundImage = FileImage(profilePicture);
      hasImage = true;
    } else if (!isProfileDeleted &&
        profileData != null &&
        profileData['profile'] != null &&
        profileData['profile']['profile_picture'] != null &&
        profileData['profile']['profile_picture'].toString().isNotEmpty) {
      // Use remote URL if not deleted and valid
      String imageUrl = _getProfilePictureUrl(profileData['profile']['profile_picture']);
      if (imageUrl.isNotEmpty) {
        backgroundImage = NetworkImage(imageUrl);
        hasImage = true;
      }
    }

    return GestureDetector(
      onTap: isEditing && !isProfileDeleted ? onPickImage : null,
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
                      backgroundImage: backgroundImage,
                      backgroundColor: Colors.grey[200],
                      child: !hasImage
                          ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                          : null,
                      onBackgroundImageError: hasImage
                          ? (error, stackTrace) {
                        developer.log(
                          'Error loading profile picture: $error',
                          name: 'ProfileScreen.Image',
                          error: error,
                          stackTrace: stackTrace,
                        );
                      }
                          : null,
                    ).animate().scale(duration: 300.ms),
                    if (isEditing && !isProfileDeleted)
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
                        profileData?['profile']['full_name'] ??
                            (isProfileDeleted ? 'No Profile' : 'User Profile'),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profileData?['email'] ??
                            (isProfileDeleted ? 'Create a new profile' : 'Smart Building Dashboard User'),
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

  static Widget buildProfileFields({
    required TextEditingController usernameController,
    required TextEditingController emailController,
    required TextEditingController fullNameController,
    required TextEditingController organizationController,
    required TextEditingController addressController,
    required bool isEditing,
  }) {
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
              controller: usernameController,
              label: 'Username',
              validator: (value) => value!.isEmpty ? 'Username is required' : null,
              enabled: isEditing,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: emailController,
              label: 'Email',
              validator: (value) => value!.contains('@') ? null : 'Invalid email',
              enabled: isEditing,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: fullNameController,
              label: 'Full Name',
              enabled: isEditing,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: organizationController,
              label: 'Organization',
              enabled: isEditing,
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: addressController,
              label: 'Address',
              enabled: isEditing,
            ),
          ],
        ),
      ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),
    );
  }

  static Widget _buildTextField({
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

  static Widget buildActionButtons({
    required BuildContext context,
    required bool isProfileDeleted,
    required VoidCallback onUpdateProfile,
    required VoidCallback onCreateProfile,
    required VoidCallback onDeleteProfile,
  }) {
    return Column(
      children: [
        if (isProfileDeleted)
          _buildButton(
            text: 'Create Profile',
            onPressed: onCreateProfile,
            color: Colors.blue,
          ),
        if (!isProfileDeleted)
          _buildButton(
            text: 'Save Changes',
            onPressed: onUpdateProfile,
            color: Colors.blue,
          ),
        if (!isProfileDeleted)
          _buildButton(
            text: 'Delete Profile',
            onPressed: onDeleteProfile,
            color: Colors.red,
          ),
      ],
    );
  }

  static Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
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
      )
    );
  }

  static Widget buildOptionsCard(BuildContext context) {
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

  static Widget _buildOptionTile({
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

  static Widget buildLogoutButton({
    required BuildContext context,
    required VoidCallback onLogout,
  }) {
    return _buildButton(
      text: 'Log Out',
      onPressed: onLogout,
      color: Colors.red,
    );
  }
}