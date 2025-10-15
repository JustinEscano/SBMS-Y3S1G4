import React, { useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css";
import { useNavigate } from "react-router-dom";
import ModalLogout from "../components/ModalLogout";
import { useAuth } from "../context/AuthContext";
import { useUser } from "../hooks/useUser";
import { userService } from "../services/userService"; // Add import for fetching profile
import type { Profile } from "../types/dashboardTypes"; // Import Profile type

type ProfilePageProps = {
  handleLogout: () => void;
};

const ProfilePage: React.FC<ProfilePageProps> = ({ handleLogout }) => {
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  const [profile, setProfile] = useState<Profile | null>(null); // State for fetched profile data
  const navigate = useNavigate();
  const { token } = useAuth();
  const { user, loading, error, clearUser } = useUser(token);

  const BACKEND_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

  const getAvatarSrc = (profilePic?: string | File | null) => {
    if (!profilePic) return undefined;

    // If string (likely path or absolute URL) - based on TopBar/Settings logic
    if (typeof profilePic === "string") {
      const s = profilePic.trim();
      if (!s) return undefined;
      return s.startsWith("http") ? s : `${BACKEND_URL}${s}`;
    }

    // If File -> create blob URL
    try {
      return URL.createObjectURL(profilePic);
    } catch (err) {
      console.error("Failed to create object URL for profile file", err);
      return undefined;
    }
  };

  // Fetch profile data on mount/token change (based on SettingsPage fetch logic)
  useEffect(() => {
    const fetchProfile = async () => {
      if (token) {
        try {
          const profileResponse = await userService.getProfile();
          setProfile(profileResponse.profile || null);
        } catch (err) {
          console.error("Failed to fetch profile:", err);
          setProfile(null);
        }
      }
    };

    fetchProfile();
  }, [token]);

  const getInitial = (name: string) => name.charAt(0).toUpperCase();

  const handleConfirmLogout = () => {
    clearUser();
    setLogoutModalOpen(false);
    handleLogout();
  };

  if (loading) {
    return (
      <PageLayout initialSection={{ parent: "Profile" }}>
        <div className="profile-page-container">
          <p>Loading profile...</p>
        </div>
      </PageLayout>
    );
  }

  if (error || !user) {
    return (
      <PageLayout initialSection={{ parent: "Profile" }}>
        <div className="profile-page-container">
          <p>Failed to load profile. Please log in again.</p>
        </div>
      </PageLayout>
    );
  }

  const avatarSrc = getAvatarSrc(profile?.profile_picture || user?.profile_picture);

  return (
    <>
      <PageLayout initialSection={{ parent: "Profile" }}>
        <div className="profile-page-container">
          {/* Profile Header */}
          <div className="profile-header">
            {avatarSrc ? (
              <img
                src={avatarSrc}
                alt="Profile"
                className="profile-avatar-circle"
              />
            ) : (
              <div className="profile-avatar-circle">
                <span className="avatar-icon">{getInitial(user.username)}</span>
              </div>
            )}

            <div className="profile-info">
              <h2>{user.username}</h2>
              <p>
                Role: {user.role_display ?? "User"} | ID: {user.id}
              </p>
              <p className="profile-email">
                Email: {user.email ?? "Not available"}
              </p>
              <p className="profile-last-login">
                Last Login: {user.last_login || "Never"}
              </p>
            </div>
          </div>

          {/* Profile Options */}
          <div className="profile-options">
            <button
              className="profile-option"
              onClick={() => navigate("/settings")}
            >
              ⚙️ Settings
            </button>
            <button
              className="profile-option"
              onClick={() => navigate("/about")}
            >
              ℹ️ About Us
            </button>
            <button
              className="profile-option"
              onClick={() => navigate("/help-support")}
            >
              ❓ Help & Support
            </button>
            <button
              className="profile-option"
              onClick={() => navigate("/policy")}
            >
              📜 Privacy Policy
            </button>
          </div>

          {/* Logout */}
          <div className="logout-container">
            <button
              className="logout-button"
              onClick={() => setLogoutModalOpen(true)}
            >
              LOG OUT
            </button>
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