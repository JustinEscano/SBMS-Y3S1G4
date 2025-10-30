import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/Screens/HelpSupportScreen.dart';
import 'package:mobile/Screens/PrivacyPolicyScreen.dart';
import 'package:mobile/Screens/ChangePasswordScreen.dart';
import 'package:mobile/Screens/AboutScreen.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../Config/api.dart';

class ProfileWidgets {
  static Widget buildProfileHeader({
    required BuildContext context,
    required Map<String, dynamic>? profileData,
    required File? profilePicture,
    required bool isEditing,
    required bool isProfileDeleted,
    required VoidCallback onPickImage,
    VoidCallback? onCardTap,
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

    ImageProvider? backgroundImage;
    bool hasImage = false;

    if (profilePicture != null) {
      backgroundImage = FileImage(profilePicture);
      hasImage = true;
    } else if (!isProfileDeleted &&
        profileData != null &&
        profileData['profile'] != null &&
        profileData['profile']['profile_picture'] != null &&
        profileData['profile']['profile_picture'].toString().isNotEmpty) {
      String imageUrl = _getProfilePictureUrl(profileData['profile']['profile_picture']);
      if (imageUrl.isNotEmpty) {
        backgroundImage = NetworkImage(imageUrl);
        hasImage = true;
      }
    }

    return GestureDetector(
      onTap: onCardTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Color(0xFF121822),
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
                          name: 'ProfileHeader.Image',
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
                        child: GestureDetector(
                          onTap: onPickImage,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF184BFB),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
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
                        style: GoogleFonts.urbanist(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profileData?['email'] ??
                            (isProfileDeleted ? 'Create a new profile' : 'Smart Building Dashboard User'),
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      if (onCardTap != null)
                        Text(
                          'Edit Profile',
                          style: GoogleFonts.urbanist(
                            fontSize: 12,
                            color: Color(0xFF184BFB),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onCardTap != null)
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
      color: Colors.black,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Color(0xFF121822),
        ),
        child: Column(
          children: [
            _buildTextField(
              controller: usernameController,
              label: 'Username',
              icon: Icons.perm_identity,
              validator: (value) => value!.isEmpty ? 'Username is required' : null,
              enabled: isEditing,
            ),
            const Divider(height: 1, color: Colors.white24),
            _buildTextField(
              controller: emailController,
              icon: Icons.email,
              label: 'Email',
              validator: (value) => value!.contains('@') ? null : 'Invalid email',
              enabled: isEditing,
            ),
            const Divider(height: 1, color: Colors.white24),
            _buildTextField(
              controller: fullNameController,
              icon: Icons.perm_identity_rounded,
              label: 'Full Name',
              enabled: isEditing,
            ),
            const Divider(height: 1, color: Colors.white24),
            _buildTextField(
              controller: organizationController,
              icon: Icons.business,
              label: 'Organization',
              enabled: isEditing,
            ),
            const Divider(height: 1, color: Colors.white24),
            _buildTextField(
              controller: addressController,
              icon: Icons.house,
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
    required IconData icon,
    required String label,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.urbanist(color: Colors.white),
        prefixIcon: Icon(icon, color: Color(0xFF184BFB)),
        contentPadding: const EdgeInsets.all(16.0),
        border: InputBorder.none,
      ),
      enabled: enabled,
      style: GoogleFonts.urbanist(fontSize: 16, color: Colors.white),
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
            color: Color(0xFF184BFB),
            isLoading: false,
          ),
        if (!isProfileDeleted)
          _buildButton(
            text: 'Save Changes',
            onPressed: onUpdateProfile,
            color: Color(0xFF184BFB),
            isLoading: false,
          ),
        if (!isProfileDeleted)
          _buildButton(
            text: 'Delete Profile',
            onPressed: onDeleteProfile,
            color: Colors.red,
            isLoading: false,
          ),
      ],
    );
  }

  static Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    required bool isLoading,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
            text,
            style: GoogleFonts.urbanist(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ).animate().scale(duration: 200.ms),
      ),
    );
  }

  static Widget buildOptionsCard(
      BuildContext context,
      String accessToken,
      String refreshToken,
      ) {
    return Card(
      color: Colors.black,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Color(0xFF121822),
        ),
        child: Column(
          children: [
            _buildOptionTile(
              icon: Icons.lock,
              title: 'Change Password',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangePasswordScreen(
                      accessToken: accessToken,
                      refreshToken: refreshToken,
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Colors.white24),
            _buildOptionTile(
              icon: Icons.info,
              title: 'About Us',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AboutScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Colors.white24),
            _buildOptionTile(
              icon: Icons.help,
              title: 'Help & Support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Helpsupportscreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Colors.white24),
            _buildOptionTile(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Privacypolicyscreen(),
                  ),
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
      leading: Icon(icon, color: Color(0xFF184BFB)),
      title: Text(title, style: GoogleFonts.urbanist(fontSize: 16, color: Colors.white)),
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
      isLoading: false,
    );
  }
}