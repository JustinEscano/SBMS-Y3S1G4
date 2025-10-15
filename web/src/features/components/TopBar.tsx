import React, { useEffect, useRef, useState, useMemo } from "react";
import "./TopBar.css";
import { useNavigate } from "react-router-dom";
import ModalLogout from "./ModalLogout";
import { useAuth } from "../context/AuthContext";
import { useUser } from "../hooks/useUser";
import { userService } from "../services/userService";

type TopBarProps = {
  collapsed: boolean;
  darkMode: boolean;
  setDarkMode: (v: boolean) => void;
  handleLogout: () => void;
};

const TopBar: React.FC<TopBarProps> = ({
  collapsed,
  handleLogout,
}) => {
  const navigate = useNavigate();
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  const { token } = useAuth();
  const { user, loading, clearUser } = useUser(token);
  const [profilePic, setProfilePic] = useState<string | File | undefined>();

  const menuRef = useRef<HTMLDivElement>(null);
  const BACKEND_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

  // ✅ Convert different picture formats into usable src
  const getAvatarSrc = (profilePic?: string | File | null) => {
    if (!profilePic) return undefined;

    if (typeof profilePic === "string") {
      const trimmed = profilePic.trim();
      if (!trimmed) return undefined;
      return trimmed.startsWith("http") ? trimmed : `${BACKEND_URL}${trimmed}`;
    }

    try {
      return URL.createObjectURL(profilePic);
    } catch (err) {
      console.error("Failed to create object URL for profile file", err);
      return undefined;
    }
  };

  // ✅ Fetch user profile picture once (if not already cached)
  useEffect(() => {
    const fetchProfilePic = async () => {
      if (!token || profilePic) return; // already have it or not logged in

      try {
        const profileResponse = await userService.getProfile();
        const pic = profileResponse.profile?.profile_picture || undefined;
        setProfilePic(pic);
        if (typeof pic === "string") localStorage.setItem("profilePic", pic);
      } catch (err) {
        console.error("Failed to fetch profile picture:", err);
      }
    };

    fetchProfilePic();
  }, [token, profilePic]);

  const handleConfirmLogout = () => {
    clearUser();
    localStorage.removeItem("profilePic");
    setLogoutModalOpen(false);
    handleLogout();
  };

  // ✅ Close dropdown on outside click or ESC
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape") setDropdownOpen(false);
    };
    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("keydown", handleEsc);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("keydown", handleEsc);
    };
  }, []);

  const getInitial = (name: string) => name.charAt(0).toUpperCase();

  // ✅ Memoize avatar to prevent re-render flicker
  const avatarContent = useMemo(() => {
    if (loading) return <div className="avatar-circle">?</div>;
    const src = getAvatarSrc(profilePic || user?.profile_picture);
    if (src) return <img src={src} alt="Profile" className="avatar-circle" />;
    return <div className="avatar-circle">{getInitial(user?.username ?? "G")}</div>;
  }, [loading, profilePic, user?.username, user?.profile_picture]);

  return (
    <header className={`topbar ${collapsed ? "collapsed" : ""}`}>
      <div className="topbar-left">
        <h1 className="topbar-title">Admin Panel</h1>
      </div>

      <div className="topbar-right">
        <div className="profile-dropdown" ref={menuRef}>
          <div
            className="profile-button"
            onClick={() => setDropdownOpen((prev) => !prev)}
          >
            {avatarContent}
            <span className="topbar-user">
              {loading ? "Loading..." : user?.username ?? "Guest"} ▾
            </span>
          </div>

          {dropdownOpen && (
            <div className="dropdown-menu">
              <div className="dropdown-header">
                {avatarContent}
                <div>
                  <h4>{user?.username ?? "Guest"}</h4>
                  <small>{user?.email ?? "No email"}</small>
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
