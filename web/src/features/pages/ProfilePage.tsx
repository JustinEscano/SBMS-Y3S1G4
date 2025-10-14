import React, { useState } from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css";
import { useNavigate} from "react-router-dom";
import ModalLogout from "../components/ModalLogout";

type ProfilePageProps = {
  handleLogout: () => void;
  user?: { initial?: string; name?: string; id?: string; roleLabel?: string };
};

const ProfilePage: React.FC<ProfilePageProps> = ({
  handleLogout,
  user = { initial: "G", name: "Gemerald De Guzman", id: "97129", roleLabel: "Admin" },
}) => {
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  const navigate = useNavigate();
  const handleConfirmLogout = () => {
    setLogoutModalOpen(false);
    handleLogout();
  };
  return (
    <>
    <PageLayout initialSection={{ parent: "Profile" }}>
      <div className="profile-page-container">
        {/* Profile Header */}
        <div className="profile-header">
          <div className="profile-avatar-circle">
            <span className="avatar-icon">👤</span>
          </div>
          <div className="profile-info">
            <h2>{user.name}</h2>
            <p>Role: {user.roleLabel} | ID: {user.id}</p>
          </div>
        </div>

        {/* Profile Options */}
        <div className="profile-options">
          <button className="profile-option" onClick={() => alert("Go to /settings")}>
            <span className="option-icon">⚙️</span>
            <span className="option-label">Settings</span>
          </button>
          <button className="profile-option" onClick={() => navigate("/about")}>
            <span className="option-icon">ℹ️</span>
            <span className="option-label">About Us</span>
          </button>
          <button className="profile-option" onClick={() => alert("Go to /help-support")}>
            <span className="option-icon">❓</span>
            <span className="option-label">Help & Support</span>
          </button>
          <button className="profile-option" onClick={() => alert("Go to /policy")}>
            <span className="option-icon">📜</span>
            <span className="option-label">Privacy Policy</span>
          </button>
        </div>

        {/* Logout Button */}
        <div className="logout-container">
          <button className="logout-button" onClick={() => setLogoutModalOpen(true)}>LOG OUT</button>
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