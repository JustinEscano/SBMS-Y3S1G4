// SettingsPage.tsx - Security & Danger Zone (Profile moved to ProfilePage)
import React, { useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import "./SettingsPage.css";
import { useAuth } from "../context/AuthContext";
import { userService } from "../services/userService";
import { useUser } from "../hooks/useUser";
import { requestOTPPasswordReset, verifyOTPPasswordReset } from "../services/authService";

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
              <p className="text-gray-400 mb-4">Click to request a 6-digit OTP via email/SMS.</p>
              <button type="button" onClick={onRequest} className="btn-primary w-full">Request OTP</button>
            </>
          ) : (
            <>
              <p className="text-gray-400 mb-4">Enter the 6-digit code sent to your email.</p>
              <input
                type="text"
                inputMode="numeric"
                maxLength={6}
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && otp.length === 6) {
                    e.preventDefault();
                    onVerify(otp);
                    setOtp("");
                  }
                }}
                className="modal-input w-full mb-4"
                placeholder="Enter 6-digit OTP"
              />
              {error && <p className="text-red-400 text-sm mb-4">⚠️ {error}</p>}
              <button
                type="button"
                onClick={() => { onVerify(otp); setOtp(""); }}
                disabled={otp.length !== 6}
                className="btn-primary w-full mb-2"
              >
                Verify & Proceed
              </button>
            </>
          )}
          <button type="button" onClick={onClose} className="btn-secondary w-full mt-2">Cancel</button>
        </div>
      </div>
    </div>
  );
};

// Delete Modal
const DeleteModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
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
              <div className="text-red-400 mb-4">
                This will permanently delete your account and all data. Are you sure?
              </div>
              <button type="button" onClick={() => onSetShowConfirm(true)} className="btn-danger w-full mb-2">Yes, Proceed</button>
            </>
          ) : (
            <>
              <p className="text-gray-400 mb-4 italic">Click confirm to permanently delete your account. This cannot be undone.</p>
              {error && <div className="text-red-400 text-sm mb-4">⚠️ {error}</div>}
              <button
                type="button"
                onClick={() => onConfirm()}
                className="btn-danger w-full mb-2"
              >
                Confirm Delete
              </button>
            </>
          )}
          <button type="button" onClick={onClose} className="btn-secondary w-full mt-2">Cancel</button>
        </div>
      </div>
    </div>
  );
};

// Password Change Modal Component
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
    if (!newPassword.trim()) { setLocalError("Enter new password."); return; }
    if (newPassword !== confirmNewPassword) { setLocalError("New passwords do not match."); return; }
    if (newPassword.length < 8) { setLocalError("New password must be at least 8 characters."); return; }
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
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-slate-400 mb-2">New Password</label>
              <input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                onKeyDown={handleKeyDown}
                className="modal-input w-full"
                placeholder="Enter new password"
                autoComplete="off"
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-400 mb-2">Confirm New Password</label>
              <input
                type="password"
                value={confirmNewPassword}
                onChange={(e) => setConfirmNewPassword(e.target.value)}
                onKeyDown={handleKeyDown}
                className="modal-input w-full"
                placeholder="Confirm new password"
                autoComplete="off"
              />
            </div>
            {(error || localError) && <div className="text-red-400 text-sm mb-4">⚠️ {error || localError}</div>}
            
            <button
              type="submit"
              disabled={!newPassword.trim() || !confirmNewPassword.trim() || newPassword !== confirmNewPassword || newPassword.length < 8}
              className="btn-primary w-full mt-4 mb-2"
            >
              Change Password
            </button>
            <button type="button" onClick={onClose} className="btn-secondary w-full mt-2">Cancel</button>
          </form>
        </div>
      </div>
    </div>
  );
};

const SettingsPage: React.FC = () => {
  const { token, logout } = useAuth();
  const { user: apiUser } = useUser(token);
  
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState<string | null>(null);

  // Profile Data removed -> Editable Profile is now exclusively in ProfilePage.tsx

  const [otpRequested, setOtpRequested] = useState(false);
  const [otpError, setOtpError] = useState<string | null>(null);
  const [showOTPModal, setShowOTPModal] = useState(false);

  const [showPasswordChangeModal, setShowPasswordChangeModal] = useState(false);
  const [passwordChangeError, setPasswordChangeError] = useState<string | null>(null);
  const [verifiedOtp, setVerifiedOtp] = useState("");

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

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
      setSuccess("Password changed successfully! Logging out...");
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

  return (
    <PageLayout initialSection={{ parent: "Settings" }}>
      <div className="settings-page-wrapper">
        <div className="settings-header">
          <h2>Security Settings</h2>
          <p>Manage your password and account status</p>
        </div>

        {success && <div className="settings-alert-success">✅ {success}</div>}

        <div className="settings-cards-grid">
          
          {/* Card: Password Change */}
          <div className="settings-card shadow-card">
            <div className="settings-card-icon text-blue-500">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
            </div>
            <div className="settings-card-content">
              <h3>Change Password</h3>
              <p>Secure your account by updating your password. You will need access to your registered email to receive an OTP verification code.</p>
            </div>
            <button
              onClick={() => setShowOTPModal(true)}
              disabled={loading}
              className="btn-primary"
            >
              Initiate Reset
            </button>
          </div>

          {/* Card: Danger Zone */}
          <div className="settings-card danger-card">
            <div className="settings-card-icon text-red-500">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 6h18"></path><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>
            </div>
            <div className="settings-card-content">
              <h3>Delete Account</h3>
              <p>Permanently remove your account and all associated data from the system. This action is irreversible.</p>
            </div>
            <button
              onClick={() => setShowDeleteModal(true)}
              disabled={loading}
              className="btn-danger"
            >
              Delete Account
            </button>
          </div>

        </div>

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