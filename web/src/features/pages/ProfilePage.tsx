import React, { useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css";
import { useNavigate } from "react-router-dom";
import ModalLogout from "../components/ModalLogout";
import { useAuth } from "../context/AuthContext";
import { useUser } from "../hooks/useUser";
import { userService } from "../services/userService";
import type { User, Profile, UserWithProfile } from "../types/dashboardTypes";

type ProfilePageProps = {
  handleLogout: () => void;
};

const ProfilePage: React.FC<ProfilePageProps> = ({ handleLogout }) => {
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  const navigate = useNavigate();
  const { token } = useAuth();
  const { user: apiUser, loading: userLoading, error: userError, clearUser, refetch } = useUser(token);

  // Profile Form State
  const [profileData, setProfileData] = useState<UserWithProfile | null>(null);
  const [isUpdating, setIsUpdating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const BACKEND_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

  // Fetch full profile data
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

  const handleUpdateProfile = async () => {
    if (!profileData || !apiUser?.id) return;

    setError(null);
    setSuccess(null);
    setIsUpdating(true);

    const changes: Partial<User & Profile> = {};
    if (profileData.username?.trim() && profileData.username.trim() !== apiUser.username) {
      changes.username = profileData.username.trim();
    }
    if (profileData.email?.trim() && profileData.email.trim() !== apiUser.email) {
      changes.email = profileData.email.trim();
    }

    const p = profileData.profile!;
    if (p.full_name?.trim() && p.full_name.trim() !== apiUser.username) {
      changes.full_name = p.full_name.trim();
    }
    if (p.organization?.trim()) changes.organization = p.organization.trim();
    if (p.address?.trim()) changes.address = p.address.trim();

    if (Object.keys(changes).length === 0 && !(p.profile_picture instanceof File)) {
      setSuccess("No changes needed.");
      setIsUpdating(false);
      return;
    }

    try {
      let updateData: Partial<User & Profile> | FormData = changes;
      if (p.profile_picture instanceof File) {
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
      setTimeout(() => setSuccess(null), 3000);
    } catch (err: any) {
      console.error("Update profile error:", err);
      const errorMsg =
        err.response?.data?.non_field_errors?.[0] ||
        err.response?.data?.username?.[0] ||
        err.response?.data?.full_name?.[0] ||
        "Failed to update profile. Please try again.";
      setError(errorMsg);
    } finally {
      setIsUpdating(false);
    }
  };

  const getAvatarSrc = (profilePic?: string | File | null) => {
    if (!profilePic) return undefined;
    if (typeof profilePic === "string") {
      const s = profilePic.trim();
      if (!s) return undefined;
      return s.startsWith("http") ? s : `${BACKEND_URL}${s}`;
    }
    try {
      return URL.createObjectURL(profilePic);
    } catch (err) {
      return undefined;
    }
  };

  const handleConfirmLogout = () => {
    clearUser();
    setLogoutModalOpen(false);
    handleLogout();
  };

  if (userLoading || !profileData) {
    return (
      <PageLayout initialSection={{ parent: "Profile" }}>
        <div className="flex items-center justify-center min-h-[50vh]">
          <p className="text-gray-400">Loading profile...</p>
        </div>
      </PageLayout>
    );
  }

  if (userError || !apiUser) {
    return (
      <PageLayout initialSection={{ parent: "Profile" }}>
        <div className="flex items-center justify-center min-h-[50vh]">
          <p className="text-red-400">Failed to load profile. Please log in again.</p>
        </div>
      </PageLayout>
    );
  }

  const p = profileData.profile!;
  const avatarSrc = getAvatarSrc(p.profile_picture || apiUser.profile_picture);
  const initial = (apiUser.username || "U").charAt(0).toUpperCase();

  return (
    <>
      <PageLayout initialSection={{ parent: "Profile" }}>
        {/* Page Header */}
        <div style={{ marginBottom: '32px' }}>
          <h1 style={{ fontSize: '28px', fontWeight: 800, color: '#ffffff', margin: 0, letterSpacing: '-0.02em' }}>My Profile</h1>
          <p style={{ fontSize: '14px', color: '#64748b', margin: '4px 0 0' }}>Manage your account settings and preferences</p>
        </div>

        <div style={{ display: 'flex', gap: '24px', alignItems: 'flex-start', flexWrap: 'wrap' }}>

          {/* LEFT COLUMN: Identity & Quick Nav */}
          <div style={{ flex: '1 1 300px', minWidth: '300px', maxWidth: '380px', background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px', display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: -30, right: -30, width: '150px', height: '150px', borderRadius: '50%', background: '#3b82f6', opacity: 0.05, filter: 'blur(30px)', pointerEvents: 'none' }} />

            <div style={{ position: 'relative', marginBottom: '16px' }}>
              <div style={{ width: '120px', height: '120px', borderRadius: '50%', overflow: 'hidden', border: '4px solid #1e293b', background: '#080b14', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {avatarSrc ? (
                  <img src={avatarSrc} alt="Avatar" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : (
                  <span style={{ fontSize: '48px', fontWeight: 700, color: '#3b82f6' }}>{initial}</span>
                )}
              </div>
              <label htmlFor="avatar-upload" title="Upload Picture" style={{ position: 'absolute', bottom: 0, right: 0, width: '36px', height: '36px', borderRadius: '50%', background: '#3b82f6', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', border: '3px solid #0f172a', transition: 'transform 0.2s', zIndex: 2 }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                  <polyline points="17 8 12 3 7 8"></polyline>
                  <line x1="12" y1="3" x2="12" y2="15"></line>
                </svg>
              </label>
              <input
                id="avatar-upload"
                type="file"
                accept="image/*"
                style={{ display: 'none' }}
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) setProfileData({ ...profileData, profile: { ...p, profile_picture: file } });
                }}
              />
            </div>

            <div style={{ textAlign: 'center', width: '100%', marginBottom: '24px' }}>
              <h2 style={{ fontSize: '20px', fontWeight: 700, color: '#ffffff', margin: '0 0 8px' }}>{apiUser.username}</h2>
              <div style={{ display: 'inline-block', padding: '4px 12px', background: 'rgba(59,130,246,0.1)', color: '#60a5fa', borderRadius: '999px', fontSize: '12px', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                {apiUser.role_display || "User"}
              </div>
            </div>

            <div style={{ width: '100%', borderTop: '1px solid #1e293b', borderBottom: '1px solid #1e293b', padding: '16px 0', marginBottom: '24px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '13px', color: '#64748b' }}>User ID</span>
                <span style={{ fontSize: '13px', fontWeight: 500, color: '#cbd5e1', fontFamily: 'monospace' }}>#{apiUser.id.toString().slice(0, 8)}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '13px', color: '#64748b' }}>System Role</span>
                <span style={{ fontSize: '13px', fontWeight: 500, color: '#cbd5e1' }}>{apiUser.role_display}</span>
              </div>
            </div>

            <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <button onClick={() => navigate("/settings")} style={{ display: 'flex', alignItems: 'center', gap: '12px', width: '100%', padding: '12px 16px', borderRadius: '10px', background: 'transparent', border: '1px solid transparent', color: '#94a3b8', fontSize: '14px', fontWeight: 500, cursor: 'pointer', textAlign: 'left', transition: 'all 0.2s', ':hover': { background: 'rgba(30,41,59,0.5)', color: '#e2e8f0' } } as React.CSSProperties}>
                <span style={{ fontSize: '16px' }}>⚙️</span> Settings
              </button>
              <button onClick={() => navigate("/policy")} style={{ display: 'flex', alignItems: 'center', gap: '12px', width: '100%', padding: '12px 16px', borderRadius: '10px', background: 'transparent', border: '1px solid transparent', color: '#94a3b8', fontSize: '14px', fontWeight: 500, cursor: 'pointer', textAlign: 'left', transition: 'all 0.2s', ':hover': { background: 'rgba(30,41,59,0.5)', color: '#e2e8f0' } } as React.CSSProperties}>
                <span style={{ fontSize: '16px' }}>📜</span> Privacy Policy
              </button>
            </div>

            <button style={{ width: '100%', marginTop: 'auto', padding: '12px 16px', borderRadius: '10px', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.2)', color: '#f87171', fontSize: '14px', fontWeight: 600, cursor: 'pointer', transition: 'all 0.2s' }} onClick={() => setLogoutModalOpen(true)}>
              Sign Out
            </button>
          </div>

          {/* RIGHT COLUMN: Edit Profile Form */}
          <div style={{ flex: '2 1 500px', background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '32px', position: 'relative', overflow: 'hidden' }}>
            <h3 style={{ fontSize: '20px', fontWeight: 700, color: '#ffffff', margin: '0 0 24px' }}>Personal Information</h3>

            {error && <div style={{ padding: '12px 16px', borderRadius: '8px', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', color: '#f87171', fontSize: '14px', marginBottom: '24px' }}>⚠️ {error}</div>}
            {success && <div style={{ padding: '12px 16px', borderRadius: '8px', background: 'rgba(52,211,153,0.1)', border: '1px solid rgba(52,211,153,0.3)', color: '#34d399', fontSize: '14px', marginBottom: '24px' }}>✅ {success}</div>}

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '20px' }}>

              {/* Username Input */}
              <div>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, color: '#94a3b8', marginBottom: '8px' }}>Username</label>
                <div style={{ position: 'relative' }}>
                  <span style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: '#64748b', pointerEvents: 'none', display: 'flex' }}>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
                  </span>
                  <input
                    type="text"
                    value={profileData.username || ""}
                    onChange={(e) => setProfileData({ ...profileData, username: e.target.value })}
                    style={{ width: '100%', padding: '12px 16px 12px 42px', borderRadius: '10px', background: '#080b14', border: '1px solid #1e293b', color: '#e2e8f0', fontSize: '14px', outline: 'none', transition: 'border-color 0.2s, box-shadow 0.2s', boxSizing: 'border-box' }}
                    placeholder="Username"
                  />
                </div>
              </div>

              {/* Email Input */}
              <div>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, color: '#94a3b8', marginBottom: '8px' }}>Email Address</label>
                <div style={{ position: 'relative' }}>
                  <span style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: '#64748b', pointerEvents: 'none', display: 'flex' }}>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"></path><polyline points="22,6 12,13 2,6"></polyline></svg>
                  </span>
                  <input
                    type="email"
                    value={profileData.email || ""}
                    onChange={(e) => setProfileData({ ...profileData, email: e.target.value })}
                    style={{ width: '100%', padding: '12px 16px 12px 42px', borderRadius: '10px', background: '#080b14', border: '1px solid #1e293b', color: '#e2e8f0', fontSize: '14px', outline: 'none', transition: 'border-color 0.2s, box-shadow 0.2s', boxSizing: 'border-box' }}
                    placeholder="Enter email"
                  />
                </div>
              </div>

              {/* Full Name Input */}
              <div style={{ gridColumn: '1 / -1' }}>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, color: '#94a3b8', marginBottom: '8px' }}>Full Name</label>
                <div style={{ position: 'relative' }}>
                  <span style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: '#64748b', pointerEvents: 'none', display: 'flex' }}>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
                  </span>
                  <input
                    type="text"
                    value={p.full_name || ""}
                    onChange={(e) => setProfileData({ ...profileData, profile: { ...p, full_name: e.target.value } })}
                    style={{ width: '100%', padding: '12px 16px 12px 42px', borderRadius: '10px', background: '#080b14', border: '1px solid #1e293b', color: '#e2e8f0', fontSize: '14px', outline: 'none', transition: 'border-color 0.2s, box-shadow 0.2s', boxSizing: 'border-box' }}
                    placeholder="Full legal name"
                  />
                </div>
              </div>

              {/* Organization Input */}
              <div style={{ gridColumn: '1 / -1' }}>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, color: '#94a3b8', marginBottom: '8px' }}>Organization</label>
                <div style={{ position: 'relative' }}>
                  <span style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: '#64748b', pointerEvents: 'none', display: 'flex' }}>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="2" width="16" height="20" rx="2" ry="2"></rect><line x1="9" y1="22" x2="15" y2="22"></line><line x1="9" y1="6" x2="9" y2="6.01"></line><line x1="15" y1="6" x2="15" y2="6.01"></line><line x1="9" y1="10" x2="9" y2="10.01"></line><line x1="15" y1="10" x2="15" y2="10.01"></line><line x1="9" y1="14" x2="9" y2="14.01"></line><line x1="15" y1="14" x2="15" y2="14.01"></line><line x1="9" y1="18" x2="9" y2="18.01"></line><line x1="15" y1="18" x2="15" y2="18.01"></line></svg>
                  </span>
                  <input
                    type="text"
                    value={p.organization || ""}
                    onChange={(e) => setProfileData({ ...profileData, profile: { ...p, organization: e.target.value } })}
                    style={{ width: '100%', padding: '12px 16px 12px 42px', borderRadius: '10px', background: '#080b14', border: '1px solid #1e293b', color: '#e2e8f0', fontSize: '14px', outline: 'none', transition: 'border-color 0.2s, box-shadow 0.2s', boxSizing: 'border-box' }}
                    placeholder="Company or Group"
                  />
                </div>
              </div>

              {/* Physical Address Input */}
              <div style={{ gridColumn: '1 / -1' }}>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, color: '#94a3b8', marginBottom: '8px' }}>Physical Address</label>
                <div style={{ position: 'relative' }}>
                  <span style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: '#64748b', pointerEvents: 'none', display: 'flex' }}>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
                  </span>
                  <input
                    type="text"
                    value={p.address || ""}
                    onChange={(e) => setProfileData({ ...profileData, profile: { ...p, address: e.target.value } })}
                    style={{ width: '100%', padding: '12px 16px 12px 42px', borderRadius: '10px', background: '#080b14', border: '1px solid #1e293b', color: '#e2e8f0', fontSize: '14px', outline: 'none', transition: 'border-color 0.2s, box-shadow 0.2s', boxSizing: 'border-box' }}
                    placeholder="Street, City, Zip"
                  />
                </div>
              </div>

            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '32px', paddingTop: '24px', borderTop: '1px solid #1e293b' }}>
              <button
                type="button"
                disabled={isUpdating}
                style={{ padding: '10px 20px', borderRadius: '10px', background: 'transparent', border: '1px solid #334155', color: '#cbd5e1', fontSize: '14px', fontWeight: 600, cursor: 'pointer', opacity: isUpdating ? 0.5 : 1 }}
                onClick={() => setProfileData({ ...(apiUser as User), profile: p } as UserWithProfile)}
              >
                Reset Changes
              </button>
              <button
                type="button"
                disabled={isUpdating}
                style={{ padding: '10px 20px', borderRadius: '10px', background: '#3b82f6', border: 'none', color: '#ffffff', fontSize: '14px', fontWeight: 600, cursor: 'pointer', opacity: isUpdating ? 0.7 : 1, display: 'flex', alignItems: 'center', gap: '8px', boxShadow: '0 4px 12px rgba(59,130,246,0.3)' }}
                onClick={handleUpdateProfile}
              >
                {isUpdating ? "Saving..." : "Save Profile"}
              </button>
            </div>

          </div>
        </div>
      </PageLayout>

      <ModalLogout
        isOpen={logoutModalOpen}
        onClose={() => setLogoutModalOpen(false)}
        onConfirmLogout={handleConfirmLogout}
      />
    </>
  );
};

export default ProfilePage;