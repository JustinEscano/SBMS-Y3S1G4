// SettingsPage.tsx - Fixed mapping to use nested profile from response
import React, { useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css"; // Reuse enhanced CSS
import { useAuth } from "../context/AuthContext"; // Adjust path as needed
import { userService } from "../services/userService"; // Adjust path as needed
import { useUser } from "../hooks/useUser"; // Adjust path as needed
import type { User, Profile, UserWithProfile } from "../types/dashboardTypes"; // Import provided types

const SettingsPage: React.FC = () => {
  const { token, logout } = useAuth(); // Add logout for security
  const { user: apiUser, refetch } = useUser(token); // Use hook for latest user data
  const [expandedSection, setExpandedSection] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Combined Profile Form State - Use UserWithProfile for merged data
  const [profileData, setProfileData] = useState<UserWithProfile | null>(null);

  // Security Form State
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmNewPassword, setConfirmNewPassword] = useState("");

  // Fetch and initialize profile for current user on mount/apiUser change
  useEffect(() => {
    const fetchProfile = async () => {
      if (token && apiUser) {
        try {
          // Fetch current profile without ID (assumes /api/profile/ endpoint)
          const profileResponse = await userService.getProfile();
          console.log('Fetched profile response:', profileResponse); // Debug: Inspect structure/values
          const fetchedProfile: Profile = {
            full_name: profileResponse.profile?.full_name || apiUser.username,
            organization: profileResponse.profile?.organization || "",
            address: profileResponse.profile?.address || "",
            profile_picture: profileResponse.profile?.profile_picture || undefined,
          };
          console.log('Mapped profile:', fetchedProfile); // Debug: Confirm mapping
          setProfileData({
            ...apiUser,  // Base User
            profile: fetchedProfile,
          });
        } catch (err) {
          console.error("Failed to fetch profile:", err); // Already logs error details (e.g., 404)
          // Fallback to defaults - this is why DB data isn't shown if fetch fails
          const fallbackProfile: Profile = {
            full_name: apiUser.username,
            organization: "",
            address: "",
            profile_picture: undefined,
          };
          console.log('Using fallback profile (fetch failed):', fallbackProfile); // Debug: Confirm fallback
          setProfileData({
            ...apiUser,
            profile: fallbackProfile,
          });
        }
      }
    };

    fetchProfile();
  }, [apiUser, token]);

  const toggleSection = (section: string) => {
    setExpandedSection(expandedSection === section ? null : section);
    if (error || success) {
      setError(null);
      setSuccess(null);
    }
  };

  const handleUpdateProfile = async () => {
    if (!profileData || !apiUser?.id) {
      setError("No user ID available.");
      return;
    }

    // Collect changes (flat for backend, from User & Profile)
    const changes: Partial<User & Profile> = {};
    if (profileData.username?.trim() && profileData.username.trim() !== apiUser.username) {
      changes.username = profileData.username.trim();
    }
    if (profileData.email?.trim() && profileData.email.trim() !== apiUser.email) {
      changes.email = profileData.email.trim();
    }
    const p = profileData.profile;
    if (p?.full_name?.trim() && p.full_name.trim() !== apiUser.username) {
      changes.full_name = p.full_name.trim();
    }
    if (p?.organization?.trim()) {
      changes.organization = p.organization.trim();
    }
    if (p?.address?.trim()) {
      changes.address = p.address.trim();
    }

    if (Object.keys(changes).length === 0 && !p?.profile_picture) {
      setSuccess("No changes needed.");
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Handle file upload
      let updateData: Partial<User & Profile> | FormData = changes;
      if (p?.profile_picture instanceof File) {
        const formData = new FormData();
        Object.entries(changes).forEach(([key, value]) => {
          if (value !== undefined && value !== null && value !== '') {
            formData.append(key, value as string);
          }
        });
        formData.append('profile_picture', p.profile_picture);
        updateData = formData;
      }

      // Send flat to /profile/ (backend separates)
      // Robustness: After update, refetch to sync, but since fetch may fail, consider making updateProfile return updated data
      // and setProfileData from it (uncomment below if service supports return value).
      const updatedResponse = await userService.updateProfile(updateData);
      console.log('Update response:', updatedResponse); // Debug: Inspect if returns updated data
      // Optional: If update returns data, map and set here for immediate UI sync
      // const updatedProfile: Profile = {
      //   full_name: updatedResponse.profile?.full_name || p.full_name,
      //   organization: updatedResponse.profile?.organization || p.organization,
      //   address: updatedResponse.profile?.address || p.address,
      //   profile_picture: updatedResponse.profile?.profile_picture || p.profile_picture,
      // };
      // setProfileData({ ...profileData, profile: updatedProfile });

      await refetch();  // Sync hook - useEffect will refetch profile (may fallback if fetch fails)

      setSuccess("Profile updated successfully!");
    } catch (err: any) {
      console.error("Update profile error:", err);
      const errorMsg = err.response?.data?.non_field_errors?.[0] || 
                       err.response?.data?.username?.[0] || 
                       err.response?.data?.full_name?.[0] || 
                       "Failed to update profile. Please try again.";
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleChangePassword = async () => {
    if (!apiUser?.id) return;

    if (newPassword.length < 6) {
      setError("New password must be at least 6 characters.");
      return;
    }

    if (newPassword !== confirmNewPassword) {
      setError("Passwords do not match.");
      return;
    }

    try {
      setLoading(true);
      setError(null);

      await userService.changePassword({
        current_password: currentPassword,
        new_password: newPassword,
      });

      setSuccess("Password changed successfully! Logging out for security...");
      
      setCurrentPassword("");
      setNewPassword("");
      setConfirmNewPassword("");
      
      setTimeout(() => logout(), 1500);
    } catch (err: any) {
      console.error("Change password error:", err);
      const errorMsg = err.response?.data?.current_password?.[0] || err.response?.data?.new_password?.[0] || err.response?.data?.non_field_errors?.[0] || "Failed to change password. Please check your current password and try again.";
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  if (!profileData) return <div>Loading...</div>; // Guard

  const p: Profile = profileData.profile!;  // Non-null assertion since always set

  return (
    <PageLayout initialSection={{ parent: "Settings" }}>
      <div className="profile-page-container">
        <h2 className="text-xl font-semibold text-white mb-4">Settings</h2>
        {error && <p className="text-red-400 text-sm mb-2">{error}</p>}
        {success && <p className="text-green-400 text-sm mb-2">{success}</p>}

        {/* Combined Profile Section */}
        <div className="settings-section">
          <button
            className="profile-option w-full text-left"
            onClick={() => toggleSection("profile")}
          >
            <span className="option-icon">👤</span>
            <span className="option-label">Profile</span>
            <span className="toggle-icon">{expandedSection === "profile" ? "▲" : "▼"}</span>
          </button>
          {expandedSection === "profile" && (
            <div className="settings-form mt-3 p-3 bg-gray-800 rounded-lg">
              <>
                <label className="block text-sm text-gray-400 mb-1">Username</label>
                <input
                  type="text"
                  value={profileData.username || ""}
                  onChange={(e) => setProfileData({ ...profileData, username: e.target.value })}
                  className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                  placeholder="Enter username"
                />
                <label className="block text-sm text-gray-400 mb-1">Email</label>
                <input
                  type="email"
                  value={profileData.email || ""}
                  onChange={(e) => setProfileData({ ...profileData, email: e.target.value })}
                  className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                  placeholder="Enter email"
                />
                <label className="block text-sm text-gray-400 mb-1">Full Name</label>
                <input
                  type="text"
                  value={p.full_name || profileData.username || ""}
                  onChange={(e) => setProfileData({ 
                    ...profileData, 
                    profile: { ...p, full_name: e.target.value } 
                  })}
                  className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                  placeholder="Enter full name"
                />
                <label className="block text-sm text-gray-400 mb-1">Organization</label>
                <input
                  type="text"
                  value={p.organization || ""}
                  onChange={(e) => setProfileData({ 
                    ...profileData, 
                    profile: { ...p, organization: e.target.value } 
                  })}
                  className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                  placeholder="Enter organization"
                />
                <label className="block text-sm text-gray-400 mb-1">Address</label>
                <input
                  type="text"
                  value={p.address || ""}
                  onChange={(e) => setProfileData({ 
                    ...profileData, 
                    profile: { ...p, address: e.target.value } 
                  })}
                  className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                  placeholder="Enter address"
                />
                <label className="block text-sm text-gray-400 mb-1">Profile Picture</label>
                {/* Display current picture if URL */}
                {p.profile_picture && typeof p.profile_picture === 'string' && (
                  <div className="current-picture-preview mb-2">
                    <img 
                      src={p.profile_picture} 
                      alt="Current Profile Picture" 
                      className="profile-picture-preview"
                      style={{ maxWidth: '100px', maxHeight: '100px', borderRadius: '50%', objectFit: 'cover' }}
                    />
                    <p className="text-gray-400 text-sm">Current picture. Choose new to replace.</p>
                  </div>
                )}
                {/* Preview new selected file */}
                {p.profile_picture && typeof p.profile_picture !== 'string' && (
                  <div className="new-picture-preview mb-2">
                    <img 
                      src={URL.createObjectURL(p.profile_picture as File)} 
                      alt="New Profile Picture Preview" 
                      className="profile-picture-preview"
                      style={{ maxWidth: '100px', maxHeight: '100px', borderRadius: '50%', objectFit: 'cover' }}
                    />
                    <p className="text-green-400 text-sm">Preview: {(p.profile_picture as File).name}</p>
                  </div>
                )}
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      setProfileData({ 
                        ...profileData, 
                        profile: { ...p, profile_picture: file } 
                      });
                    }
                  }}
                  className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                />
                <button
                  onClick={handleUpdateProfile}
                  disabled={loading}
                  className="profile-option w-full"
                >
                  {loading ? "Saving..." : "Update Profile"}
                </button>
              </>
            </div>
          )}
        </div>

        {/* Security Section - Unchanged */}
        <div className="settings-section">
          <button
            className="profile-option w-full text-left"
            onClick={() => toggleSection("security")}
          >
            <span className="option-icon">🔒</span>
            <span className="option-label">Security</span>
            <span className="toggle-icon">{expandedSection === "security" ? "▲" : "▼"}</span>
          </button>
          {expandedSection === "security" && (
            <div className="settings-form mt-3 p-3 bg-gray-800 rounded-lg">
              <label className="block text-sm text-gray-400 mb-1">Current Password</label>
              <input
                type="password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                placeholder="Enter current password"
              />
              <label className="block text-sm text-gray-400 mb-1">New Password</label>
              <input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                placeholder="Enter new password"
              />
              <label className="block text-sm text-gray-400 mb-1">Confirm New Password</label>
              <input
                type="password"
                value={confirmNewPassword}
                onChange={(e) => setConfirmNewPassword(e.target.value)}
                className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                placeholder="Confirm new password"
              />
              <button
                onClick={handleChangePassword}
                disabled={loading}
                className="profile-option w-full"
              >
                {loading ? "Updating..." : "Change Password"}
              </button>
            </div>
          )}
        </div>
      </div>
    </PageLayout>
  );
};

export default SettingsPage;