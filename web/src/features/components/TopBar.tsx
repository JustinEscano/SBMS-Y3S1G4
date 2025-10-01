import React, { useEffect, useRef, useState } from "react";
import "./TopBar.css";
import { useNavigate } from "react-router-dom";
import ModalLogout from "./ModalLogout";
import { jwtDecode } from "jwt-decode";

type TopBarProps = {
  collapsed: boolean;
  darkMode: boolean;
  setDarkMode: (v: boolean) => void;
  handleLogout: () => void;
};

type TokenPayload = {
  user_id: string;
  username?: string;
  email?: string;
  role?: string;
  role_display?: string;
  exp: number;
  token_type: string;
};

type User = {
  id: string;
  username?: string;
  email?: string;
  role?: string;
  role_display?: string;
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
  const [user, setUser] = useState<User | null>(null);

  const menuRef = useRef<HTMLDivElement>(null);

  const handleConfirmLogout = () => {
    setLogoutModalOpen(false);
    handleLogout();
  };

  useEffect(() => {
    try {
      const token = localStorage.getItem("access_token");
      if (!token) return;

      const decoded = jwtDecode<TokenPayload>(token);

      // we only *guarantee* user_id, but keep other fields if your backend puts them
      setUser({
        id: decoded.user_id,
        username: decoded.username ?? undefined,
        email: decoded.email ?? undefined,
        role: decoded.role ?? undefined,
        role_display: decoded.role_display ?? decoded.role ?? "Client",
      });
    } catch (err) {
      console.error("Failed to decode JWT:", err);
    }
  }, []);

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
              {user?.username?.charAt(0).toUpperCase() ?? "?"}
            </div>
            <span className="topbar-user">
              {user?.role_display ?? "Guest"} ▾
            </span>
          </div>

          {dropdownOpen && (
            <div className="dropdown-menu">
              <div className="dropdown-header">
                <div className="avatar-large">
                  {user?.username?.charAt(0).toUpperCase() ?? "?"}
                </div>
                <div>
                  <h4>{user?.username ?? "Guest"}</h4>
                  <small>ID: {user?.id ?? "N/A"}</small>
                </div>
              </div>

              <div className="dropdown-links">
                <button onClick={() => navigate("/profile")}>My Profile</button>
                <button onClick={() => alert("Go to settings")}>
                  Settings
                </button>
                <label className="switch">
                  <input
                    type="checkbox"
                    checked={darkMode}
                    onChange={() => setDarkMode(!darkMode)}
                  />
                  <span className="slider"></span>
                  <span className="switch-label">
                    {darkMode ? "Dark Mode" : "Light Mode"}
                  </span>
                </label>
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
