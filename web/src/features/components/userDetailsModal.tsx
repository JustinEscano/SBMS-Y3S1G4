// UserDetailsModal.tsx
import React, { useState, useEffect } from "react";
import type { User, Profile } from "../types/dashboardTypes";

interface UserDetailsModalProps {
  user: User | null;
  isOpen: boolean;
  onClose: () => void;
  onUpdate?: (data: Partial<User & Profile>) => Promise<void>;
  onDelete?: (id: string) => Promise<void>;
  mode?: "view" | "edit" | "delete" | "add";
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

/* ── shared style tokens ── */
const S = {
  backdrop: {
    position: 'fixed' as const, inset: 0, background: 'rgba(0,0,0,0.65)',
    backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center',
    justifyContent: 'center', zIndex: 9999, padding: '20px',
  },
  card: {
    background: '#141828', border: '1px solid #1d2540', borderRadius: '20px',
    width: '100%', maxWidth: '560px', overflow: 'hidden',
    boxShadow: '0 24px 64px rgba(0,0,0,0.5)',
  },
  header: {
    background: '#0d1022', borderBottom: '1px solid #1d2540',
    padding: '20px 24px', display: 'flex', alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: { fontSize: '16px', fontWeight: 700, color: '#f8fafc', margin: 0 },
  closeBtn: {
    background: 'transparent', border: 'none', color: '#64748b',
    fontSize: '20px', cursor: 'pointer', lineHeight: 1, padding: '2px 6px', borderRadius: '6px',
  },
  body: { padding: '24px' },
  grid2: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' },
  fieldWrap: { display: 'flex', flexDirection: 'column' as const, gap: '6px' },
  label: { fontSize: '11px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase' as const, letterSpacing: '0.06em' },
  input: {
    padding: '10px 14px', borderRadius: '10px', border: '1px solid #1d2540',
    background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none',
    width: '100%', boxSizing: 'border-box' as const,
  },
  inputDisabled: {
    padding: '10px 14px', borderRadius: '10px', border: '1px solid #1d2540',
    background: 'rgba(8,12,20,0.4)', color: '#64748b', fontSize: '14px', outline: 'none',
    width: '100%', boxSizing: 'border-box' as const, cursor: 'default',
  },
  select: {
    padding: '10px 14px', borderRadius: '10px', border: '1px solid #1d2540',
    background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none',
    width: '100%', boxSizing: 'border-box' as const, cursor: 'pointer',
  },
  footer: {
    padding: '16px 24px', borderTop: '1px solid #1d2540',
    display: 'flex', gap: '10px', justifyContent: 'flex-end',
  },
  btnPrimary: {
    padding: '10px 22px', borderRadius: '10px', border: 'none',
    background: '#5b81fb', color: '#fff', fontSize: '14px', fontWeight: 600, cursor: 'pointer',
  },
  btnCancel: {
    padding: '10px 22px', borderRadius: '10px', border: '1px solid #334155',
    background: '#1e293b', color: '#e2e8f0', fontSize: '14px', fontWeight: 600, cursor: 'pointer',
  },
  btnDanger: {
    padding: '10px 22px', borderRadius: '10px', border: '1px solid rgba(239,68,68,0.35)',
    background: 'rgba(239,68,68,0.12)', color: '#f87171', fontSize: '14px', fontWeight: 600, cursor: 'pointer',
  },
};

const UserDetailsModal: React.FC<UserDetailsModalProps> = ({ user, isOpen, onClose, onUpdate, onDelete, mode = "view" }) => {
  const [currentMode, setCurrentMode] = useState<"view" | "edit" | "delete" | "add">(mode);
  const [formData, setFormData] = useState<FormData>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(() => setCurrentMode(mode), [mode]);

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
      if (user.profile?.profile_picture && typeof user.profile.profile_picture === "string") {
        setPreviewUrl(user.profile.profile_picture);
      }
    } else if (currentMode === "add") {
      setFormData({ username: "", email: "", role: "user", full_name: "", organization: "", address: "" });
      setPreviewUrl(null);
    }
  }, [currentMode, user]);

  useEffect(() => {
    return () => { if (previewUrl && previewUrl.startsWith("blob:")) URL.revokeObjectURL(previewUrl); };
  }, [previewUrl]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    setError(null);
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const url = URL.createObjectURL(file);
      setPreviewUrl(url);
      setFormData(prev => ({ ...prev, profile_picture: file }));
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
        id: user?.id, username: formData.username, email: formData.email, role: formData.role,
        full_name: formData.full_name, organization: formData.organization, address: formData.address,
        ...(typeof formData.profile_picture === "string" ? { profile_picture: formData.profile_picture } : {}),
      };
      if (currentMode === "add") delete payload.id;
      await onUpdate(payload);
      onClose();
    } catch (err: any) {
      setError(err.message || "Failed to save user. Please try again.");
    } finally { setLoading(false); }
  };

  const handleDelete = async () => {
    if (!user || !onDelete) return;
    try {
      setLoading(true); setError(null);
      await onDelete(user.id);
      onClose();
    } catch (err: any) {
      setError(err.message || "Failed to delete user.");
    } finally { setLoading(false); }
  };

  const isView = currentMode === "view";
  const isEdit = currentMode === "edit";
  const isDelete = currentMode === "delete";
  const isAdd = currentMode === "add";
  const title = isAdd ? "Add User" : isEdit ? "Edit User" : isDelete ? "Delete User" : "User Details";
  const inputStyle = (isView || isDelete) ? S.inputDisabled : S.input;

  // Avatar initials
  const initial = (formData.username || user?.username || 'U').charAt(0).toUpperCase();

  return (
    <div style={S.backdrop} onClick={onClose}>
      <div style={S.card} onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div style={S.header}>
          <h2 style={S.title}>{title}</h2>
          <button style={S.closeBtn} onClick={onClose}>×</button>
        </div>

        {/* Delete */}
        {isDelete && user ? (
          <>
            <div style={{ padding: '32px 24px', textAlign: 'center' }}>
              <div style={{ width: '64px', height: '64px', borderRadius: '50%', background: 'rgba(239,68,68,0.15)', border: '1px solid rgba(239,68,68,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', fontSize: '28px' }}>
                🗑
              </div>
              <p style={{ color: '#e2e8f0', fontSize: '15px', marginBottom: '6px', fontWeight: 600 }}>
                Delete <span style={{ color: '#f87171' }}>{user.username}</span>?
              </p>
              <p style={{ color: '#64748b', fontSize: '13px', margin: 0 }}>
                {user.email} — this action cannot be undone.
              </p>
              {error && <p style={{ color: '#f87171', fontSize: '13px', marginTop: '12px' }}>{error}</p>}
            </div>
            <div style={S.footer}>
              <button style={S.btnCancel} onClick={onClose} disabled={loading}>Cancel</button>
              <button style={S.btnDanger} onClick={handleDelete} disabled={loading}>
                {loading ? "Deleting..." : "Confirm Delete"}
              </button>
            </div>
          </>
        ) : (
          <form onSubmit={handleSave}>
            <div style={S.body}>
              {/* Avatar + file upload */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '24px' }}>
                <div style={{ width: '64px', height: '64px', borderRadius: '50%', background: 'rgba(59,130,246,0.2)', border: '2px solid rgba(59,130,246,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, overflow: 'hidden' }}>
                  {previewUrl
                    ? <img src={previewUrl} alt="Avatar" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    : <span style={{ fontSize: '22px', fontWeight: 700, color: '#60a5fa' }}>{initial}</span>
                  }
                </div>
                {(isEdit || isAdd) && (
                  <div>
                    <label htmlFor="profile_picture" style={{ ...S.btnCancel, display: 'inline-block', cursor: 'pointer', fontSize: '13px', padding: '7px 16px' }}>
                      {formData.profile_picture instanceof File ? '1 file chosen' : 'Upload Photo'}
                    </label>
                    <input id="profile_picture" type="file" accept="image/*" onChange={handleFileChange} style={{ display: 'none' }} />
                    <p style={{ color: '#64748b', fontSize: '12px', marginTop: '4px' }}>JPG, PNG, GIF up to 5MB</p>
                  </div>
                )}
              </div>

              {/* Fields */}
              <div style={{ ...S.grid2, marginBottom: '16px' }}>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Username</label>
                  <input style={inputStyle} type="text" name="username" value={formData.username || ""} onChange={handleChange} disabled={isView || isDelete} required={!isView} />
                </div>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Email</label>
                  <input style={inputStyle} type="email" name="email" value={formData.email || ""} onChange={handleChange} disabled={isView || isDelete} required={!isView} />
                </div>
              </div>
              <div style={{ ...S.grid2, marginBottom: '16px' }}>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Role</label>
                  {isView || isDelete
                    ? <input style={inputStyle} type="text" value={(formData.role || '').toUpperCase()} disabled />
                    : <select style={S.select} name="role" value={formData.role || ""} onChange={handleChange} required>
                        <option value="">Select role</option>
                        <option value="admin">Admin</option>
                        <option value="client">Client</option>
                        <option value="user">User</option>
                      </select>
                  }
                </div>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Full Name</label>
                  <input style={inputStyle} type="text" name="full_name" value={formData.full_name || ""} onChange={handleChange} disabled={isView || isDelete} />
                </div>
              </div>
              <div style={{ ...S.grid2, marginBottom: error ? '16px' : '0' }}>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Organization</label>
                  <input style={inputStyle} type="text" name="organization" value={formData.organization || ""} onChange={handleChange} disabled={isView || isDelete} />
                </div>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Address</label>
                  <input style={inputStyle} type="text" name="address" value={formData.address || ""} onChange={handleChange} disabled={isView || isDelete} />
                </div>
              </div>
              {error && <p style={{ color: '#f87171', fontSize: '13px', marginTop: '12px' }}>{error}</p>}
            </div>
            <div style={S.footer}>
              {isView
                ? <button type="button" style={S.btnCancel} onClick={onClose}>Close</button>
                : <>
                    <button type="button" style={S.btnCancel} onClick={onClose} disabled={loading}>Cancel</button>
                    <button type="submit" style={S.btnPrimary} disabled={loading}>
                      {loading ? "Saving..." : isAdd ? "Add User" : "Save Changes"}
                    </button>
                  </>
              }
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default UserDetailsModal;