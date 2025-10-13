// SettingsPage.tsx - Enhanced with expandable sections for Account Details and Security
import React, { useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css"; // Reuse enhanced CSS
import { useAuth } from "../context/AuthContext"; // Adjust path as needed
import { userService } from "../services/userService"; // Adjust path as needed
import { useUser } from "../hooks/useUser"; // Adjust path as needed
import type { User } from "../types/dashboardTypes";

const SettingsPage: React.FC = () => {
  const { token, logout } = useAuth(); // Add logout for security
  const { user: apiUser, refetch } = useUser(token); // Use hook for latest user data
  const [expandedSection, setExpandedSection] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Account Details Form State - Initialize with API user
  const [newUsername, setNewUsername] = useState(apiUser?.username || "");

  // Update form state when API user changes (e.g., after refetch)
  useEffect(() => {
    setNewUsername(apiUser?.username || "");
  }, [apiUser?.username]);

  // Security Form State
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmNewPassword, setConfirmNewPassword] = useState("");

  const toggleSection = (section: string) => {
    setExpandedSection(expandedSection === section ? null : section);
    // Clear error/success when expanding
    if (error || success) {
      setError(null);
      setSuccess(null);
    }
  };

  const handleUpdateUsername = async () => {
    if (!apiUser?.id) {
      setError("No user ID available.");
      return;
    }

    if (newUsername.trim() === "") {
      setError("Username cannot be empty.");
      return;
    }

    if (newUsername.trim() === apiUser.username) {
      setSuccess("No changes needed.");
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await userService.update(apiUser.id, { username: newUsername });

      // Refetch to sync latest data across app
      await refetch();

      setSuccess("Username updated successfully! Reloading page...");
      
      // Reload the page after a short delay to ensure the change is visible app-wide
      setTimeout(() => {
        window.location.reload();
      }, 1500); // 1.5s delay for user to see success message
    } catch (err: any) {
      console.error("Update username error:", err);
      const errorMsg = err.response?.data?.username?.[0] || err.response?.data?.non_field_errors?.[0] || "Failed to update username. Please try again.";
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

      // Real API call to change password using userService (PATCH to user endpoint with current_password and new password)
      await userService.changePassword(apiUser.id, {
        current_password: currentPassword,
        new_password: newPassword,
      });

      setSuccess("Password changed successfully! Logging out for security...");
      
      // Clear form
      setCurrentPassword("");
      setNewPassword("");
      setConfirmNewPassword("");
      
      // Force re-login for security (new session with updated password)
      setTimeout(() => {
        logout();
      }, 1500);
    } catch (err: any) {
      console.error("Change password error:", err);
      const errorMsg = err.response?.data?.current_password?.[0] || err.response?.data?.new_password?.[0] || err.response?.data?.non_field_errors?.[0] || "Failed to change password. Please check your current password and try again.";
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <PageLayout initialSection={{ parent: "Settings" }}>
      <div className="profile-page-container">
        <h2 className="text-xl font-semibold text-white mb-4">Settings</h2>
        {error && <p className="text-red-400 text-sm mb-2">{error}</p>}
        {success && <p className="text-green-400 text-sm mb-2">{success}</p>}

        {/* Account Details Section */}
        <div className="settings-section">
          <button
            className="profile-option w-full text-left"
            onClick={() => toggleSection("account")}
          >
            <span className="option-icon">👤</span>
            <span className="option-label">Account Details</span>
            <span className="toggle-icon">{expandedSection === "account" ? "▲" : "▼"}</span>
          </button>
          {expandedSection === "account" && (
            <div className="settings-form mt-3 p-3 bg-gray-800 rounded-lg">
              <label className="block text-sm text-gray-400 mb-1">New Username</label>
              <input
                type="text"
                value={newUsername}
                onChange={(e) => setNewUsername(e.target.value)}
                className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                placeholder="Enter new username"
              />
              <button
                onClick={handleUpdateUsername}
                disabled={loading}
                className="profile-option w-full"
              >
                {loading ? "Saving..." : "Save Changes"}
              </button>
            </div>
          )}
        </div>

        {/* Security Section */}
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