// ProfilePage.tsx - Refactored to use useUser hook
import React, { useState } from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css";
import { useNavigate } from "react-router-dom";
import ModalLogout from "../components/ModalLogout";
import { useAuth } from "../context/AuthContext"; // Adjust path
import { useUser } from "../hooks/useUser"; // Adjust path
import type { User } from "../types/dashboardTypes";

type ProfilePageProps = {
  handleLogout: () => void;
};

const ProfilePage: React.FC<ProfilePageProps> = ({ handleLogout }) => {
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  const navigate = useNavigate();
  const { token } = useAuth();
  const { user, loading, error } = useUser(token); // Use hook for latest user data

  const getInitial = (name: string) => name.charAt(0).toUpperCase();

  const handleConfirmLogout = () => {
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

  return (
    <>
      <PageLayout initialSection={{ parent: "Profile" }}>
        <div className="profile-page-container">
          {/* Profile Header */}
          <div className="profile-header">
            <div className="profile-avatar-circle">
              <span className="avatar-icon">{getInitial(user.username)}</span>
            </div>
            <div className="profile-info">
              <h2>{user.username}</h2>
              <p>Role: {user.role_display} | ID: {user.id}</p>
              <p className="profile-email">Email: {user.email}</p>
              <p className="profile-last-login">Last Login: {user.last_login || "Never"}</p>
            </div>
          </div>

          {/* Profile Options */}
          <div className="profile-options">
            <button className="profile-option" onClick={() => navigate("/settings")}>
              <span className="option-icon">⚙️</span>
              <span className="option-label">Settings</span>
            </button>
            <button className="profile-option" onClick={() => navigate("/about")}>
              <span className="option-icon">ℹ️</span>
              <span className="option-label">About Us</span>
            </button>
            <button className="profile-option" onClick={() => navigate("/help-support")}>
              <span className="option-icon">❓</span>
              <span className="option-label">Help & Support</span>
            </button>
            <button className="profile-option" onClick={() => navigate("/policy")}>
              <span className="option-icon">📜</span>
              <span className="option-label">Privacy Policy</span>
            </button>
          </div>

          {/* Logout Button */}
          <div className="logout-container">
            <button className="logout-button" onClick={() => setLogoutModalOpen(true)}>
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