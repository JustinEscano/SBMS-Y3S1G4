// TopBar.tsx - Refactored to use useUser hook
import React, { useEffect, useRef, useState } from "react";
import "./TopBar.css";
import { useNavigate } from "react-router-dom";
import ModalLogout from "./ModalLogout";
import { useAuth } from "../context/AuthContext"; // Adjust path
import { useUser } from "../hooks/useUser"; // Adjust path

type TopBarProps = {
  collapsed: boolean;
  darkMode: boolean;
  setDarkMode: (v: boolean) => void;
  handleLogout: () => void;
};

const TopBar: React.FC<TopBarProps> = ({
  collapsed,
  darkMode,
  setDarkMode,
  handleLogout,
}) => {
  const navigate = useNavigate();
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  const { token } = useAuth();
  const { user, loading } = useUser(token); // Use hook for latest user data

  const menuRef = useRef<HTMLDivElement>(null);

  const handleConfirmLogout = () => {
    setLogoutModalOpen(false);
    handleLogout();
  };

  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    const onEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape") setDropdownOpen(false);
    };
    document.addEventListener("mousedown", onDocClick);
    document.addEventListener("keydown", onEsc);
    return () => {
      document.removeEventListener("mousedown", onDocClick);
      document.removeEventListener("keydown", onEsc);
    };
  }, []);

  const getInitial = (name: string) => name.charAt(0).toUpperCase();

  return (
    <header className={`topbar ${collapsed ? "collapsed" : ""}`}>
      <div className="topbar-left">
        <h1 className="topbar-title">Admin Panel</h1>
      </div>

      <div className="topbar-right">
        <div className="profile-dropdown" ref={menuRef}>
          <div
            className="profile-button"
            onClick={() => setDropdownOpen(!dropdownOpen)}
          >
            <div className="avatar-circle">
              {loading ? "?" : getInitial(user?.username || "Guest")}
            </div>
            <span className="topbar-user">
              {loading ? "Loading..." : (user?.username ?? "Guest")} ▾
            </span>
          </div>

          {dropdownOpen && (
            <div className="dropdown-menu">
              <div className="dropdown-header">
                <div className="avatar-large">
                  {loading ? "?" : getInitial(user?.username || "Guest")}
                </div>
                <div>
                  <h4>{loading ? "Loading..." : (user?.username ?? "Guest")}</h4>
                  <small>ID: {user?.id ?? "N/A"}</small>
                </div>
              </div>

              <div className="dropdown-links">
                <button onClick={() => navigate("/profile")}>My Profile</button>
                <button onClick={() => navigate("/settings")}>Settings</button>
              </div>

              <div className="dropdown-footer">
                <button
                  className="logout-btn"
                  onClick={() => setLogoutModalOpen(true)}
                >
                  Logout
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      <ModalLogout
        isOpen={logoutModalOpen}
        onClose={() => setLogoutModalOpen(false)}
        onConfirmLogout={handleConfirmLogout}
      />
    </header>
  );
};

export default TopBar;