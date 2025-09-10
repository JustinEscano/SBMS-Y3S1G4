import React, { useEffect, useRef, useState } from "react";
import "./TopBar.css";

type TopBarProps = {
  collapsed: boolean;
  darkMode: boolean;
  setDarkMode: (v: boolean) => void;
  handleLogout: () => void;
  user?: { initial?: string; name?: string; id?: string; roleLabel?: string };
};

const TopBar: React.FC<TopBarProps> = ({
  collapsed,
  darkMode,
  setDarkMode,
  handleLogout,
  user = { initial: "G", name: "Geremald De Guzman", id: "97129", roleLabel: "Admin" },
}) => {
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

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
            <div className="avatar-circle">{user.initial}</div>
            <span className="topbar-user">{user.roleLabel} ▾</span>
          </div>

          {dropdownOpen && (
            <div className="dropdown-menu">
              <div className="dropdown-header">
                <div className="avatar-large">{user.initial}</div>
                <div>
                  <h4>{user.name}</h4>
                  <small>ID: {user.id}</small>
                </div>
              </div>

              <div className="dropdown-links">
                <button onClick={() => alert("Go to profile")}>My Profile</button>
                <button onClick={() => alert("Go to settings")}>Settings</button>
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
                <a href="#">Privacy Policy</a> · <a href="#">Terms of Service</a>
                <button className="logout-btn" onClick={handleLogout}>
                  Logout
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};

export default TopBar;
