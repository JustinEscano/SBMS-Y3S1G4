// UserDetailsModal.tsx
import React, { useState, useEffect } from "react";
import type { User, Profile } from "../types/dashboardTypes";
import "./UserDetailsModal.css"; // Specific CSS for this modal

interface UserDetailsModalProps {
  user: User | null;
  isOpen: boolean;
  onClose: () => void;
  onUpdate?: (data: Partial<User & Profile>) => Promise<void>;
  onDelete?: (id: string) => Promise<void>;
  mode?: "view" | "edit" | "delete";
}

interface FormData {
  username?: string;
  email?: string;
  role?: string;
  full_name?: string;
  organization?: string;
  address?: string;
  profile_picture?: string | File;
}

const UserDetailsModal: React.FC<UserDetailsModalProps> = ({
  user,
  isOpen,
  onClose,
  onUpdate,
  onDelete,
  mode = "view",
}) => {
  const [currentMode, setCurrentMode] = useState<"view" | "edit" | "delete">(mode);
  const [formData, setFormData] = useState<FormData>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(() => setCurrentMode(mode), [mode]);

  // Pre-fill form data including profile
  useEffect(() => {
    if ((currentMode === "edit" || currentMode === "view") && user) {
      const newFormData = {
        username: user.username || "",
        email: user.email || "",
        role: user.role || "",
        full_name: user.profile?.full_name || "",
        organization: user.profile?.organization || "",
        address: user.profile?.address || "",
        profile_picture: user.profile?.profile_picture,
      };
      setFormData(newFormData);

      // Set preview for existing image
      if (user.profile?.profile_picture && typeof user.profile.profile_picture === "string") {
        setPreviewUrl(user.profile.profile_picture);
      }
    }
  }, [currentMode, user]);

  // Cleanup preview URL on unmount or file change
  useEffect(() => {
    return () => {
      if (previewUrl && previewUrl.startsWith("blob:")) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    setError(null); // Clear error on input
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const url = URL.createObjectURL(file);
      setPreviewUrl(url);
      setFormData((prev) => ({ ...prev, profile_picture: file }));
    }
    setError(null);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!onUpdate || !user) return;
    try {
      setLoading(true);
      setError(null);
      const payload: Partial<User & Profile> = {
        id: user.id,
        username: formData.username,
        email: formData.email,
        role: formData.role,
        full_name: formData.full_name,
        organization: formData.organization,
        address: formData.address,
        ...(typeof formData.profile_picture === "string" ? { profile_picture: formData.profile_picture } : {}),
      };
      await onUpdate(payload);
      onClose();
    } catch (err: any) {
      setError(err.message || "Failed to save user. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!user || !onDelete) return;
    try {
      setLoading(true);
      setError(null);
      await onDelete(user.id);
      onClose();
    } catch (err: any) {
      setError(err.message || "Failed to delete user. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleCancel = () => {
    setError(null);
    onClose();
  };

  const isViewMode = currentMode === "view";
  const isEditMode = currentMode === "edit";
  const isDeleteMode = currentMode === "delete";

  return (
    <div className="user-modal-backdrop" onClick={handleCancel}>
      <div className="user-modal" onClick={(e) => e.stopPropagation()}>
        <div className="user-modal-header">
          <h2>
            {isEditMode ? "Edit User" : isDeleteMode ? "Delete User" : "User Details"}
          </h2>
          <button className="user-modal-close" onClick={handleCancel} aria-label="Close modal">
            &times;
          </button>
        </div>

        <div className="user-modal-content">
          {isDeleteMode && user && (
            <div className="user-delete-content">
              <p className="user-delete-text">
                Are you sure you want to delete user <strong>{user.username}</strong> ({user.email})? This action cannot be undone.
              </p>
            </div>
          )}

          {(isEditMode || isViewMode) && user && (
            <form onSubmit={handleSave} className="user-form">
              <div className="user-form-section user-form-section-profile">
                <div className="user-profile-preview">
                  {previewUrl ? (
                    <img
                      src={previewUrl}
                      alt="Profile Preview"
                      className="user-profile-img"
                    />
                  ) : (
                    <div className="user-profile-placeholder">
                      <span className="user-profile-placeholder-icon">👤</span>
                      <span className="user-profile-placeholder-text">No Image</span>
                    </div>
                  )}
                </div>
                {isEditMode && (
                  <div className="user-file-input-wrapper">
                    <input
                      id="profile_picture"
                      type="file"
                      accept="image/*"
                      onChange={handleFileChange}
                      className="user-file-input"
                    />
                    <label htmlFor="profile_picture" className="user-file-label">
                      Choose File {formData.profile_picture ? `(1 file chosen)` : `No file chosen`}
                    </label>
                  </div>
                )}
              </div>

              <div className="user-form-grid">
                <div className="user-form-group">
                  <label htmlFor="username">Username:</label>
                  <input
                    id="username"
                    type="text"
                    name="username"
                    value={formData.username || ""}
                    onChange={handleChange}
                    disabled={isViewMode}
                    required={!isViewMode}
                    aria-required={!isViewMode}
                  />
                </div>

                <div className="user-form-group">
                  <label htmlFor="email">Email:</label>
                  <input
                    id="email"
                    type="email"
                    name="email"
                    value={formData.email || ""}
                    onChange={handleChange}
                    disabled={isViewMode}
                    required={!isViewMode}
                    aria-required={!isViewMode}
                  />
                </div>

                <div className="user-form-group">
                  <label htmlFor="role">Role:</label>
                  <select
                    id="role"
                    name="role"
                    value={formData.role || ""}
                    onChange={handleChange}
                    disabled={isViewMode}
                    required={!isViewMode}
                    aria-required={!isViewMode}
                  >
                    <option value="">Select role</option>
                    <option value="admin">Admin</option>
                    <option value="client">Client</option>
                  </select>
                </div>

                <div className="user-form-group">
                  <label htmlFor="organization">Organization:</label>
                  <input
                    id="organization"
                    type="text"
                    name="organization"
                    value={formData.organization || ""}
                    onChange={handleChange}
                    disabled={isViewMode}
                  />
                </div>

                <div className="user-form-group">
                  <label htmlFor="address">Address:</label>
                  <input
                    id="address"
                    type="text"
                    name="address"
                    value={formData.address || ""}
                    onChange={handleChange}
                    disabled={isViewMode}
                  />
                </div>
              </div>

              {error && <p className="user-form-error" role="alert">{error}</p>}
            </form>
          )}
        </div>

        <div className="user-modal-actions">
          {isEditMode && (
            <>
              <button type="button" onClick={handleCancel} disabled={loading}>
                Cancel
              </button>
              <button type="submit" onClick={handleSave} disabled={loading} className="user-save-btn">
                {loading ? "Saving..." : "Save Changes"}
              </button>
            </>
          )}

          {isDeleteMode && (
            <>
              <button type="button" onClick={handleCancel} disabled={loading}>
                Cancel
              </button>
              <button type="button" onClick={handleDelete} disabled={loading} className="user-delete-btn">
                {loading ? "Deleting..." : "Confirm Delete"}
              </button>
            </>
          )}

          {isViewMode && (
            <button type="button" onClick={handleCancel}>
              Close
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default UserDetailsModal;