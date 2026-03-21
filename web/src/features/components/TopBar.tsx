import { useEffect, useRef, useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { Bell, User, ChevronUp, LogOut, Settings } from "lucide-react";
import ModalLogout from "./ModalLogout";
import { useAuth } from "../context/AuthContext";
import { useUser } from "../hooks/useUser";
import { userService } from "../services/userService";

type TopBarProps = {
    handleLogout: () => void;
};

const getPageTitle = (pathname: string) => {
    if (pathname.includes("dashboard")) return "Dashboard";
    if (pathname.includes("usage")) return "Usage Analytics";
    if (pathname.includes("notifications")) return "Notifications";
    if (pathname.includes("llm")) return "LLM Chat";
    if (pathname.includes("users")) return "User Management";
    if (pathname.includes("about")) return "About Us";
    if (pathname.includes("profile")) return "My Profile";
    if (pathname.includes("settings")) return "Settings";
    return "Admin Panel";
};

export function TopBar({ handleLogout }: TopBarProps) {
    const navigate = useNavigate();
    const location = useLocation();

    const [isProfileOpen, setIsProfileOpen] = useState(false);
    const [isNotifOpen, setIsNotifOpen] = useState(false);
    const [logoutModalOpen, setLogoutModalOpen] = useState(false);

    const { token } = useAuth();
    const { user, loading, clearUser } = useUser(token);
    const [profilePic, setProfilePic] = useState<string | File | undefined>();
    const [profileHover, setProfileHover] = useState(false);
    const [logoutBtnHover, setLogoutBtnHover] = useState(false);

    const profileRef = useRef<HTMLDivElement>(null);
    const notifRef = useRef<HTMLDivElement>(null);
    const BACKEND_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

    const getAvatarSrc = (pic?: string | File | null) => {
        if (!pic) return undefined;
        if (typeof pic === "string") {
            const t = pic.trim();
            if (!t) return undefined;
            return t.startsWith("http") ? t : `${BACKEND_URL}${t}`;
        }
        try { return URL.createObjectURL(pic); } catch { return undefined; }
    };

    useEffect(() => {
        const fetchProfilePic = async () => {
            if (!token || profilePic) return;
            try {
                const res = await userService.getProfile();
                const pic = res.profile?.profile_picture || undefined;
                setProfilePic(pic);
                if (typeof pic === "string") localStorage.setItem("profilePic", pic);
            } catch (err) { console.error("Failed to fetch profile picture:", err); }
        };
        fetchProfilePic();
    }, [token, profilePic]);

    const handleConfirmLogout = () => {
        clearUser();
        localStorage.removeItem("profilePic");
        setLogoutModalOpen(false);
        handleLogout();
    };

    useEffect(() => {
        const handleClickOutside = (e: MouseEvent) => {
            if (profileRef.current && !profileRef.current.contains(e.target as Node)) setIsProfileOpen(false);
            if (notifRef.current && !notifRef.current.contains(e.target as Node)) setIsNotifOpen(false);
        };
        const handleEsc = (e: KeyboardEvent) => {
            if (e.key === "Escape") { setIsProfileOpen(false); setIsNotifOpen(false); }
        };
        document.addEventListener("mousedown", handleClickOutside);
        document.addEventListener("keydown", handleEsc);
        return () => {
            document.removeEventListener("mousedown", handleClickOutside);
            document.removeEventListener("keydown", handleEsc);
        };
    }, []);

    const pageTitle = getPageTitle(location.pathname);
    const displayUserName = user?.username || "Guest";
    const displayRole = user?.role || "User";
    const avatarSrc = getAvatarSrc(profilePic || user?.profile_picture);

    const menuItemStyle: React.CSSProperties = {
        display: 'flex', alignItems: 'center', gap: '8px',
        padding: '10px 16px', cursor: 'pointer', border: 'none',
        background: 'transparent', color: '#e2e8f0', fontSize: '14px',
        fontWeight: 500, width: '100%', textAlign: 'left', transition: 'background 0.15s',
    };

    return (
        <header style={{
            height: '80px', borderBottom: '1px solid #1e293b',
            background: '#080b14', padding: '0 24px',
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            flexShrink: 0, color: '#e2e8f0', position: 'relative', zIndex: 20,
        }}>
            {/* Left: page title */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <h1 style={{ fontSize: '20px', fontWeight: 700, color: '#ffffff', margin: 0, whiteSpace: 'nowrap' }}>
                    {pageTitle}
                </h1>
            </div>

            {/* Right: bell + profile */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>

                {/* Notification Bell */}
                <div style={{ position: 'relative' }} ref={notifRef}>
                    <button
                        onClick={() => setIsNotifOpen(!isNotifOpen)}
                        style={{
                            padding: '8px', borderRadius: '8px', border: 'none', cursor: 'pointer',
                            background: isNotifOpen ? '#1e293b' : 'transparent', color: '#94a3b8',
                            display: 'flex', alignItems: 'center', transition: 'all 0.15s',
                        }}
                    >
                        <Bell size={20} />
                    </button>
                    {isNotifOpen && (
                        <div style={{
                            position: 'absolute', top: '100%', right: 0, marginTop: '8px',
                            width: '320px', background: '#0f172a', borderRadius: '12px',
                            border: '1px solid #1e293b', zIndex: 50, overflow: 'hidden',
                            boxShadow: '0 20px 40px rgba(0,0,0,0.5)',
                        }}>
                            <div style={{ padding: '16px', borderBottom: '1px solid #1e293b' }}>
                                <h4 style={{ margin: 0, fontSize: '15px', fontWeight: 600, color: '#ffffff' }}>Notifications</h4>
                            </div>
                            <div style={{ padding: '16px', borderBottom: '1px solid #1e293b', cursor: 'pointer' }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '4px' }}>
                                    <span style={{ fontSize: '14px', fontWeight: 500, color: '#e2e8f0' }}>System Update</span>
                                    <span style={{ fontSize: '12px', color: '#64748b' }}>1h ago</span>
                                </div>
                                <p style={{ fontSize: '13px', color: '#64748b', margin: 0 }}>System layout migration completed.</p>
                            </div>
                        </div>
                    )}
                </div>

                {/* Profile Dropdown */}
                <div style={{ position: 'relative' }} ref={profileRef}>
                    <button
                        onClick={() => setIsProfileOpen(!isProfileOpen)}
                        onMouseEnter={() => setProfileHover(true)}
                        onMouseLeave={() => setProfileHover(false)}
                        style={{
                            display: 'flex', alignItems: 'center', gap: '10px',
                            padding: '6px 16px 6px 8px',
                            borderRadius: '999px', border: '1px solid #1e293b', cursor: 'pointer',
                            background: isProfileOpen || profileHover ? '#1e293b' : '#0f172a',
                            transition: 'background 0.2s',
                        }}
                    >
                        <div style={{
                            width: '32px', height: '32px', borderRadius: '50%', overflow: 'hidden',
                            background: 'rgba(59,130,246,0.2)', display: 'flex', alignItems: 'center',
                            justifyContent: 'center', color: '#60a5fa', flexShrink: 0,
                        }}>
                            {avatarSrc ? <img src={avatarSrc} alt="Avatar" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                : <User size={16} />}
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: '1px' }}>
                            <span style={{ fontSize: '14px', fontWeight: 600, color: '#e2e8f0', lineHeight: 1 }}>
                                {loading ? 'Loading...' : displayUserName}
                            </span>
                            <span style={{ fontSize: '12px', color: '#64748b', lineHeight: 1 }}>{displayRole}</span>
                        </div>
                        <ChevronUp size={12} color="#64748b" style={{ transform: isProfileOpen ? 'rotate(180deg)' : 'none', transition: 'transform 0.2s' }} />
                    </button>

                    {isProfileOpen && (
                        <div style={{
                            position: 'absolute', top: '100%', right: 0, marginTop: '8px',
                            width: '220px', background: '#0f172a', borderRadius: '12px',
                            border: '1px solid #1e293b', zIndex: 50, overflow: 'hidden',
                            boxShadow: '0 20px 40px rgba(0,0,0,0.5)', padding: '4px 0',
                        }}>
                            <div style={{ padding: '8px 16px 6px', fontSize: '12px', fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                                My Account
                            </div>
                            <div style={{ height: '1px', background: '#1e293b', margin: '4px 0' }} />
                            <button onClick={() => { setIsProfileOpen(false); navigate("/profile"); }}
                                style={{...menuItemStyle}}
                                onMouseEnter={e => (e.currentTarget.style.background = '#1e293b')}
                                onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                            >
                                <User size={16} /> <span>Profile</span>
                            </button>
                            <button onClick={() => { setIsProfileOpen(false); navigate("/settings"); }}
                                style={{...menuItemStyle}}
                                onMouseEnter={e => (e.currentTarget.style.background = '#1e293b')}
                                onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                            >
                                <Settings size={16} /> <span>Settings</span>
                            </button>
                            <div style={{ height: '1px', background: '#1e293b', margin: '4px 0' }} />
                            <button
                                onClick={() => { setIsProfileOpen(false); setLogoutModalOpen(true); }}
                                style={{...menuItemStyle, color: '#f87171'}}
                                onMouseEnter={e => (e.currentTarget.style.background = 'rgba(239,68,68,0.1)')}
                                onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                            >
                                <LogOut size={16} color="#f87171" /> <span>Log out</span>
                            </button>
                        </div>
                    )}
                </div>

                <ModalLogout
                    isOpen={logoutModalOpen}
                    onClose={() => setLogoutModalOpen(false)}
                    onConfirmLogout={handleConfirmLogout}
                />
            </div>
        </header>
    );
}

export default TopBar;
