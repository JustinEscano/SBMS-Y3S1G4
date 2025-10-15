// UserDetailsModal.tsx
import React, { useState, useEffect } from "react";
import type { User, Profile } from "../types/dashboardTypes";
import "./Modal.css";

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

  useEffect(() => setCurrentMode(mode), [mode]);

  // Pre-fill form data including profile
  useEffect(() => {
    if ((currentMode === "edit" || currentMode === "view") && user) {
      setFormData({
        username: user.username || "",
        email: user.email || "",
        role: user.role || "",
        full_name: user.profile?.full_name || "",
        organization: user.profile?.organization || "",
        address: user.profile?.address || "",
        profile_picture: user.profile?.profile_picture,
      });
    }
  }, [currentMode, user]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) setFormData((prev) => ({ ...prev, profile_picture: file }));
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
    } catch {
      setError("Failed to save user. Please try again.");
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
    } catch {
      setError("Failed to delete user. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleCancel = () => {
    if (currentMode === "edit" && user) {
      onClose()
      setError(null);
    } else {
      onClose();
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>
            {currentMode === "edit"
              ? "Edit User"
              : currentMode === "delete"
              ? "Delete User"
              : "User Details"}
          </h2>
          <button className="modal-close" onClick={onClose}>&times;</button>
        </div>

        <div className="modal-content">

          {currentMode === "edit" && (
            <form onSubmit={handleSave}>
              <label>Username:
                <input type="text" name="username" value={formData.username || ""} onChange={handleChange} required />
              </label>
              <label>Email:
                <input type="email" name="email" value={formData.email || ""} onChange={handleChange} required />
              </label>
              <label>Role:
                <select name="role" value={formData.role || ""} onChange={handleChange} required>
                  <option value="">Select role</option>
                  <option value="admin">Admin</option>
                  <option value="client">Client</option>
                </select>
              </label>
              <label>Full Name:
                <input type="text" name="full_name" value={formData.full_name || ""} onChange={handleChange} />
              </label>
              <label>Organization:
                <input type="text" name="organization" value={formData.organization || ""} onChange={handleChange} />
              </label>
              <label>Address:
                <input type="text" name="address" value={formData.address || ""} onChange={handleChange} />
              </label>
              <label>Profile Picture:</label>
              {formData.profile_picture && (
                <img
                  src={
                    typeof formData.profile_picture === "string"
                      ? formData.profile_picture
                      : URL.createObjectURL(formData.profile_picture)
                  }
                  alt="Profile Preview"
                  style={{ maxWidth: "100px", borderRadius: "50%", marginBottom: "10px" }}
                />
              )}
              <input type="file" accept="image/*" onChange={handleFileChange} />
              {error && <p className="field-error">{error}</p>}
            </form>
          )}

          {currentMode === "delete" && user && (
            <p>
              Are you sure you want to delete user <strong>{user.username}</strong> ({user.email})?
            </p>
          )}

          <div className="modal-actions">

          {currentMode === "edit" && (
            <>
              <button type="button" onClick={handleCancel}>Cancel</button>
              <button type="submit" onClick={handleSave} disabled={loading} className="add-btn">
                {loading ? "Saving..." : "Save"}
              </button>
            </>
          )}

          {currentMode === "delete" && user && (
            <>
              <button type="button" onClick={handleCancel}>Cancel</button>
              <button type="button" onClick={handleDelete} disabled={loading} className="delete-btn">
                {loading ? "Deleting..." : "Confirm Delete"}
              </button>
            </>
          )}
        </div>
        </div>
      </div>
    </div>
  );
};

export default UserDetailsModal;