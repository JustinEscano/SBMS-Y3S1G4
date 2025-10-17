// SettingsPage.tsx - Updated to import new SettingsPage.css
import React, { useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import "./SettingsPage.css"; // New dedicated CSS
import { useAuth } from "../context/AuthContext";
import { userService } from "../services/userService";
import { useUser } from "../hooks/useUser";
import { requestOTPPasswordReset, verifyOTPPasswordReset } from "../services/authService"; // Adjust path; reuse your OTP services
import type { User, Profile, UserWithProfile } from "../types/dashboardTypes";

// Simple OTP Modal Component (unchanged)
const OTPModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  onVerify: (otp: string) => void;
  onRequest: () => void;
  otpRequested: boolean;
  error?: string;
}> = ({ isOpen, onClose, onVerify, onRequest, otpRequested, error }) => {
  const [otp, setOtp] = useState("");
  if (!isOpen) return null;
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Verify OTP</h2>
          <button type="button" className="modal-close" onClick={onClose}>×</button>
        </div>
        <div className="modal-content">
          {!otpRequested ? (
            <>
              <p>Click to request a 6-digit OTP via email/SMS.</p>
              <button type="button" onClick={onRequest} className="btn btn-primary w-full mb-2">Request OTP</button>
            </>
          ) : (
            <>
              <p>Enter the 6-digit code sent to your email.</p>
              <input
                type="text"
                inputMode="numeric"
                maxLength={6}
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    if (otp.length === 6) {
                      onVerify(otp);
                      setOtp("");
                    }
                  }
                }}
                className="w-full p-2 bg-gray-700 text-white rounded mb-2"
                placeholder="Enter 6-digit OTP"
              />
              {error && <p className="text-red-400 text-sm mb-2">{error}</p>}
              <button
                type="button"
                onClick={() => { onVerify(otp); setOtp(""); }}
                disabled={otp.length !== 6}
                className="btn btn-primary w-full mb-2"
              >
                Verify & Proceed
              </button>
            </>
          )}
          <button type="button" onClick={onClose} className="btn btn-secondary w-full">Cancel</button>
        </div>
      </div>
    </div>
  );
};

// Delete Modal (no password) — refactored
const DeleteModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void; // no password param anymore
  showConfirm: boolean;
  onSetShowConfirm: (show: boolean) => void;
  error?: string | null;
}> = ({ isOpen, onClose, onConfirm, showConfirm, onSetShowConfirm, error }) => {
  if (!isOpen) return null;
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>{showConfirm ? "Confirm Deletion" : "Delete Account"}</h2>
          <button type="button" className="modal-close" onClick={onClose}>×</button>
        </div>
        <div className="modal-content">
          {!showConfirm ? (
            <>
              <p className="text-red-400 mb-4">⚠️ This will permanently delete your account and all data. Are you sure?</p>
              <button type="button" onClick={() => onSetShowConfirm(true)} className="btn btn-danger w-full mb-2">Yes, Proceed</button>
            </>
          ) : (
            <>
              <p className="text-gray-400 mb-2">Click confirm to permanently delete your account.</p>
              {error && <p className="text-red-400 text-sm mb-2">{error}</p>}
              <button
                type="button"
                onClick={() => onConfirm()}
                className="btn btn-danger w-full mb-2"
              >
                Confirm Delete
              </button>
            </>
          )}
          <button type="button" onClick={onClose} className="btn btn-secondary w-full">Cancel</button>
        </div>
      </div>
    </div>
  );
};

// Password Change Modal Component (unchanged)
const PasswordChangeModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (newPassword: string) => void;
  error?: string;
}> = ({ isOpen, onClose, onConfirm, error }) => {
  const [newPassword, setNewPassword] = useState("");
  const [confirmNewPassword, setConfirmNewPassword] = useState("");
  const [localError, setLocalError] = useState("");
  useEffect(() => {
    if (isOpen) {
      setNewPassword("");
      setConfirmNewPassword("");
      setLocalError("");
    }
  }, [isOpen]);
  if (!isOpen) return null;
  const handleSubmit = (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    setLocalError("");
    if (!newPassword.trim()) {
      setLocalError("Enter new password.");
      return;
    }
    if (newPassword !== confirmNewPassword) {
      setLocalError("New passwords do not match.");
      return;
    }
    if (newPassword.length < 8) {
      setLocalError("New password must be at least 8 characters.");
      return;
    }
    onConfirm(newPassword);
  };
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSubmit();
    }
  };
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Change Password</h2>
          <button type="button" className="modal-close" onClick={onClose}>×</button>
        </div>
        <div className="modal-content">
          <p className="text-gray-400 mb-4">Enter your new password (OTP verified).</p>
          <form onSubmit={handleSubmit} className="space-y-2">
            <label className="block text-sm text-gray-400 mb-1">New Password</label>
            <input
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              onKeyDown={handleKeyDown}
              className="w-full p-2 bg-gray-700 text-white rounded mb-2"
              placeholder="Enter new password"
              autoComplete="off"
            />
            <label className="block text-sm text-gray-400 mb-1">Confirm New Password</label>
            <input
              type="password"
              value={confirmNewPassword}
              onChange={(e) => setConfirmNewPassword(e.target.value)}
              onKeyDown={handleKeyDown}
              className="w-full p-2 bg-gray-700 text-white rounded mb-2"
              placeholder="Confirm new password"
              autoComplete="off"
            />
            {(error || localError) && <p className="text-red-400 text-sm mb-2">{error || localError}</p>}
            <button
              type="submit"
              disabled={!newPassword.trim() || !confirmNewPassword.trim() || newPassword !== confirmNewPassword || newPassword.length < 8}
              className="btn btn-primary w-full mb-2"
            >
              Change Password
            </button>
            <button type="button" onClick={onClose} className="btn btn-secondary w-full">Cancel</button>
          </form>
        </div>
      </div>
    </div>
  );
};

const SettingsPage: React.FC = () => {
  const { token, logout } = useAuth();
  const { user: apiUser, refetch } = useUser(token);
  const [expandedSection, setExpandedSection] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Profile Form State
  const [profileData, setProfileData] = useState<UserWithProfile | null>(null);
  const [otpRequested, setOtpRequested] = useState(false);
  const [otpError, setOtpError] = useState<string | null>(null);
  const [showOTPModal, setShowOTPModal] = useState(false);

  // Password Change Modal State
  const [showPasswordChangeModal, setShowPasswordChangeModal] = useState(false);
  const [passwordChangeError, setPasswordChangeError] = useState<string | null>(null);
  const [verifiedOtp, setVerifiedOtp] = useState("");

  // Delete State
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  // Fetch profile
  useEffect(() => {
    const fetchProfile = async () => {
      if (token && apiUser) {
        try {
          const profileResponse = await userService.getProfile();
          const fetchedProfile: Profile = {
            full_name: profileResponse.profile?.full_name || apiUser.username,
            organization: profileResponse.profile?.organization || "",
            address: profileResponse.profile?.address || "",
            profile_picture: profileResponse.profile?.profile_picture || undefined,
          };
          setProfileData({ ...(apiUser as User), profile: fetchedProfile } as UserWithProfile);
        } catch (err) {
          console.error("Failed to fetch profile:", err);
          const fallbackProfile: Profile = {
            full_name: apiUser.username,
            organization: "",
            address: "",
            profile_picture: undefined,
          };
          setProfileData({ ...(apiUser as User), profile: fallbackProfile } as UserWithProfile);
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

  // Request fresh OTP
  const requestSecurityOTP = async () => {
    if (!apiUser?.email) {
      setOtpError("Email not available.");
      return;
    }
    try {
      setLoading(true);
      await requestOTPPasswordReset(apiUser.email);
      setOtpRequested(true);
      setOtpError(null);
    } catch (err: any) {
      setOtpError(err.response?.data?.email?.[0] || "Failed to send OTP.");
    } finally {
      setLoading(false);
    }
  };

  // Proceed after OTP entry
  const handleVerifyOTP = (enteredOtp: string) => {
    if (enteredOtp.length !== 6 || !/^\d{6}$/.test(enteredOtp)) {
      setOtpError("Enter a valid 6-digit OTP.");
      return;
    }
    setOtpError(null);
    setVerifiedOtp(enteredOtp);
    setOtpRequested(false);
    setShowOTPModal(false);
    setShowPasswordChangeModal(true);
  };

  // Handle Password Change (using OTP)
  const handlePasswordChange = async (newPassword: string) => {
    if (!apiUser?.email || !verifiedOtp) {
      setPasswordChangeError("Missing data.");
      return;
    }
    try {
      setLoading(true);
      setPasswordChangeError(null);
      await verifyOTPPasswordReset(apiUser.email, verifiedOtp, newPassword);
      setShowPasswordChangeModal(false);
      setSuccess("Password changed! Logging out...");
      setTimeout(() => logout(), 1500);
    } catch (err: any) {
      console.error("Password change error:", err);
      setPasswordChangeError(
        err.response?.data?.otp?.[0] ||
        err.response?.data?.password?.[0] ||
        err.response?.data?.non_field_errors?.[0] ||
        "Failed to change password."
      );
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateProfile = async () => {
    if (!profileData || !apiUser?.id) {
      setError("No user ID available.");
      return;
    }
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
    if (p?.organization?.trim()) changes.organization = p.organization.trim();
    if (p?.address?.trim()) changes.address = p.address.trim();

    if (Object.keys(changes).length === 0 && !p?.profile_picture) {
      setSuccess("No changes needed.");
      return;
    }

    try {
      setLoading(true);
      setError(null);
      let updateData: Partial<User & Profile> | FormData = changes;
      if (p?.profile_picture instanceof File) {
        const formData = new FormData();
        Object.entries(changes).forEach(([key, value]) => {
          if (value !== undefined && value !== null && value !== "") {
            formData.append(key, value as string);
          }
        });
        formData.append("profile_picture", p.profile_picture);
        updateData = formData;
      }
      await userService.updateProfile(updateData);
      await refetch();
      setSuccess("Profile updated successfully!");
    } catch (err: any) {
      console.error("Update profile error:", err);
      const errorMsg =
        err.response?.data?.non_field_errors?.[0] ||
        err.response?.data?.username?.[0] ||
        err.response?.data?.full_name?.[0] ||
        "Failed to update profile. Please try again.";
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  // New: delete without password — calls userService.remove(apiUser.id)
  const handleDeleteAccount = async () => {
    if (!apiUser?.id) {
      setDeleteError("User not found. Please re-login and try again.");
      return;
    }
    try {
      setLoading(true);
      setDeleteError(null);
      await userService.remove(apiUser.id);
      setSuccess("Account deleted! Logging out...");
      setShowDeleteModal(false);
      setTimeout(() => logout(), 1500);
    } catch (err: any) {
      console.error("Delete error:", err);
      const msg =
        err?.response?.data?.detail ||
        err?.response?.data?.error ||
        "Failed to delete account. Please try again.";
      setDeleteError(msg);
    } finally {
      setLoading(false);
    }
  };

  if (!profileData) return (
    <PageLayout initialSection={{ parent: "Settings" }}>
      <div className="flex items-center justify-center min-h-screen">
        <div className="loading-throbber"></div>
      </div>
    </PageLayout>
  );

  const p: Profile = profileData.profile!;

  return (
    <PageLayout initialSection={{ parent: "Settings" }}>
      <div className="settings-container">
        <h2 className="settings-title">Settings</h2>
        {error && <p className="error-message">{error}</p>}
        {success && <p className="success-message">{success}</p>}

        {/* Profile Section */}
        <div className="settings-section">
          <button type="button" className="section-toggle" onClick={() => toggleSection("profile")}>
            <span className="toggle-icon">👤</span>
            <span className="toggle-label">Profile</span>
            <span className="toggle-arrow">{expandedSection === "profile" ? "▲" : "▼"}</span>
          </button>
          {expandedSection === "profile" && (
            <div className="profile-form-card">
              {/* Profile Picture */}
              <div className="profile-picture-section">
                <div className="avatar-container">
                  {p.profile_picture ? (
                    typeof p.profile_picture === "string" ? (
                      <img src={p.profile_picture} alt="Profile picture" className="avatar-image" />
                    ) : (
                      <img src={URL.createObjectURL(p.profile_picture as File)} alt="Profile picture preview" className="avatar-image" />
                    )
                  ) : (
                    <div className="avatar-placeholder">
                      <span className="placeholder-icon">👤</span>
                      <p className="placeholder-text">No image</p>
                    </div>
                  )}
                </div>

                <br></br>
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      setProfileData({ ...profileData, profile: { ...p, profile_picture: file } });
                    }
                  }}
                  className="file-input"
                  id="profile-picture-input"
                />
                <label htmlFor="profile-picture-input" className="file-input-label">
                  Choose File {p.profile_picture ? (typeof p.profile_picture === "string" ? "" : `(${(p.profile_picture as File).name})`) : "No file chosen"}
                </label>
              </div>

              {/* Form Fields */}
              <div className="form-fields">
                <div className="form-group">
                  <label className="form-label">Username:</label>
                  <input
                    type="text"
                    value={profileData.username || ""}
                    onChange={(e) => setProfileData({ ...profileData, username: e.target.value })}
                    className="form-input"
                    placeholder="Enter username"
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Email:</label>
                  <input
                    type="email"
                    value={profileData.email || ""}
                    onChange={(e) => setProfileData({ ...profileData, email: e.target.value })}
                    className="form-input"
                    placeholder="Enter email"
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Full Name:</label>
                  <input
                    type="text"
                    value={p.full_name || profileData.username || ""}
                    onChange={(e) => setProfileData({ ...profileData, profile: { ...p, full_name: e.target.value } })}
                    className="form-input"
                    placeholder="Enter full name"
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Role:</label>
                  <select
                    value={profileData.role || "client"} // Assuming role from apiUser or profile; adjust if needed
                    onChange={(e) => setProfileData({ ...profileData, role: e.target.value })}
                    className="form-input form-select"
                  >
                    <option value="client">Client</option>
                    <option value="admin">Admin</option>
                    {/* Add more roles as needed */}
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label">Organization:</label>
                  <input
                    type="text"
                    value={p.organization || ""}
                    onChange={(e) => setProfileData({ ...profileData, profile: { ...p, organization: e.target.value } })}
                    className="form-input"
                    placeholder="Enter organization"
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Address:</label>
                  <input
                    type="text"
                    value={p.address || ""}
                    onChange={(e) => setProfileData({ ...profileData, profile: { ...p, address: e.target.value } })}
                    className="form-input"
                    placeholder="Enter address"
                  />
                </div>
              </div>

              {/* Buttons */}
              <div className="form-actions">
                <button
                  type="button"
                  onClick={() => {
                    // Reset to original data on cancel
                    setProfileData({ ...(apiUser as User), profile: p } as UserWithProfile);
                    setExpandedSection(null);
                  }}
                  disabled={loading}
                  className="action-btn cancel-btn"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleUpdateProfile}
                  disabled={loading}
                  className="action-btn save-btn"
                >
                  {loading ? "Saving..." : "Save Changes"}
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Security Section */}
        <div className="settings-section">
          <button type="button" className="section-toggle" onClick={() => toggleSection("security")}>
            <span className="toggle-icon">🔒</span>
            <span className="toggle-label">Security</span>
            <span className="toggle-arrow">{expandedSection === "security" ? "▲" : "▼"}</span>
          </button>
          {expandedSection === "security" && (
            <div className="settings-form mt-3 p-3 bg-gray-800 rounded-lg">
              <div className="password-section mb-4 border-b border-gray-600 pb-4">
                <h4 className="text-white mb-2">Change Password</h4>
                <p className="text-gray-400 text-sm mb-2">Start with OTP verification, then enter your new password.</p>
                <button
                  type="button"
                  onClick={() => setShowOTPModal(true)}
                  disabled={loading}
                  className="btn btn-primary w-full"
                >
                  Initiate Password Change
                </button>
              </div>

              <div className="delete-trigger border-t border-gray-600 pt-4 mt-4">
                <button
                  type="button"
                  onClick={() => setShowDeleteModal(true)}
                  disabled={loading}
                  className="w-full p-2 bg-red-600 hover:bg-red-700 text-white rounded"
                >
                  Delete Account
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Modals */}
        <OTPModal
          isOpen={showOTPModal}
          onClose={() => { setShowOTPModal(false); setOtpError(null); }}
          onRequest={requestSecurityOTP}
          onVerify={handleVerifyOTP}
          otpRequested={otpRequested}
          error={otpError ?? undefined}
        />

        <PasswordChangeModal
          isOpen={showPasswordChangeModal}
          onClose={() => { setShowPasswordChangeModal(false); setPasswordChangeError(null); }}
          onConfirm={handlePasswordChange}
          error={passwordChangeError ?? undefined}
        />

        <DeleteModal
          isOpen={showDeleteModal}
          onClose={() => { setShowDeleteModal(false); setShowDeleteConfirm(false); setDeleteError(null); }}
          onConfirm={handleDeleteAccount}
          showConfirm={showDeleteConfirm}
          onSetShowConfirm={setShowDeleteConfirm}
          error={deleteError ?? null}
        />
      </div>
    </PageLayout>
  );
};

export default SettingsPage;