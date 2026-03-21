import { useState } from "react";
import "./SideBar.css"; // just for no-scrollbar
import { Link, useLocation } from "react-router-dom";
import {
    Home, Bell, BarChart2, LogOut, ChevronLeft, ChevronRight, Info, Bot, Users
} from "lucide-react";
import OrbitLogo from "../../assets/ORBIT.png";
import CompanyNameLogo from "../../assets/Logo-Name.png";
import ModalLogout from "./ModalLogout";
import { useNotifications } from "../hooks/useNotification";

interface SideBarProps {
    collapsed: boolean;
    onToggle: () => void;
    handleLogout: () => void;
}

const navLinks = [
    { href: "/dashboard", label: "Dashboard", icon: Home, isGroup: true, subItems: [
        { href: "/dashboard/hvac", label: "HVAC" },
        { href: "/dashboard/maintenance", label: "Maintenance" },
    ] },
    { href: "/usage", label: "Usage", icon: BarChart2 },
    { href: "/notifications", label: "Notification", icon: Bell, isNotif: true },
    { href: "/llm", label: "LLM Chat", icon: Bot },
    { href: "/users", label: "Users", icon: Users },
    { href: "/about", label: "About Us", icon: Info },
];

export function SideBar({ collapsed, onToggle, handleLogout }: SideBarProps) {
    const location = useLocation();
    const [logoutModalOpen, setLogoutModalOpen] = useState(false);
    const [dashExpanded, setDashExpanded] = useState(location.pathname.startsWith('/dashboard'));

    const userId = localStorage.getItem("user_id");
    const { notifications } = useNotifications(userId || undefined);
    const unreadCount = notifications.filter(n => !n.read).length;

    const handleConfirmLogout = () => {
        setLogoutModalOpen(false);
        handleLogout();
    };

    return (
        <>
            {/* Mobile Overlay */}
            {!collapsed && (
                <div
                    style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', zIndex: 20, display: 'none' }} // hidden on desktop
                    onClick={onToggle}
                    aria-hidden="true"
                />
            )}

            <aside style={{
                display: 'flex',
                flexDirection: 'column',
                height: '100vh',
                position: 'fixed',
                top: 0,
                left: 0,
                zIndex: 30,
                width: collapsed ? '80px' : '280px',
                background: '#0f172a',
                borderRight: '1px solid #1e293b',
                transition: 'width 0.5s ease-in-out',
                overflow: 'hidden',
                color: '#e2e8f0',
                boxShadow: '4px 0 20px rgba(0,0,0,0.4)',
            }}>
                {/* Header / Logo Area */}
                <div style={{
                    height: '80px',
                    display: 'flex',
                    alignItems: 'center',
                    padding: collapsed ? 0 : '0 16px 0 20px',
                    boxSizing: 'border-box',
                    borderBottom: '1px solid #1e293b',
                    position: 'relative',
                    flexShrink: 0,
                    background: '#0f172a',
                }}>
                    <div style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        width: '100%',
                        paddingRight: '32px', // Offset for the arrow button to remain centered visually
                        opacity: collapsed ? 0 : 1,
                        pointerEvents: collapsed ? 'none' : 'auto',
                        transition: 'opacity 0.5s ease',
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                    }}>
                        <img src={OrbitLogo} alt="Orbit Logo" style={{ height: '36px', width: 'auto', objectFit: 'contain' }} />
                        <div style={{ overflow: 'hidden', marginLeft: '12px', whiteSpace: 'nowrap' }}>
                            <img src={CompanyNameLogo} alt="ORBIT" style={{ height: '20px', width: 'auto', objectFit: 'contain', marginTop: '4px' }} />
                        </div>
                    </div>

                    {/* Toggle Button */}
                    <button
                        onClick={onToggle}
                        style={{
                            position: 'absolute',
                            left: collapsed ? '50%' : 'auto',
                            right: collapsed ? 'auto' : '12px',
                            transform: collapsed ? 'translate(-50%, -50%)' : 'translate(0, -50%)',
                            top: '50%',
                            padding: '6px',
                            borderRadius: '50%',
                            background: '#0f172a',
                            border: '1px solid #1e293b',
                            color: '#94a3b8',
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            transition: 'all 0.5s ease',
                        }}
                    >
                        {collapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
                    </button>
                </div>

                {/* Navigation Links */}
                <nav className="no-scrollbar" style={{ flex: 1, padding: '24px 16px', overflowY: 'auto', boxSizing: 'border-box' }}>
                    {navLinks.map((link) => {
                        const isActive = link.isGroup
                            ? location.pathname === link.href || location.pathname === link.href + "/"
                            : location.pathname.startsWith(link.href);
                        const isChildActive = link.isGroup && location.pathname.startsWith(link.href) && !isActive;

                        const linkStyle: React.CSSProperties = {
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: collapsed ? 'center' : 'flex-start',
                            gap: collapsed ? 0 : '14px',
                            padding: collapsed ? '12px 0' : '12px 12px 12px 16px',
                            width: '100%',
                            boxSizing: 'border-box',
                            borderRadius: '12px',
                            textDecoration: 'none',
                            fontSize: '14px',
                            fontWeight: 600,
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            marginBottom: '4px',
                            transition: 'background 0.2s ease, color 0.2s ease, padding 0.5s ease',
                            cursor: 'pointer',
                            background: (isActive || (collapsed && isChildActive)) ? '#1e293b' : 'transparent',
                            color: (isActive || isChildActive) ? '#60a5fa' : '#cbd5e1',
                        };

                        return (
                            <div key={link.href}>
                                <Link
                                    to={link.href}
                                    style={linkStyle}
                                    onClick={() => {
                                        if (link.isGroup && !collapsed) setDashExpanded(!dashExpanded);
                                    }}
                                    title={collapsed ? link.label : undefined}
                                    onMouseEnter={e => {
                                        if (!isActive && !isChildActive) (e.currentTarget as HTMLAnchorElement).style.background = 'rgba(30,41,59,0.7)';
                                    }}
                                    onMouseLeave={e => {
                                        if (!isActive && !isChildActive) (e.currentTarget as HTMLAnchorElement).style.background = 'transparent';
                                    }}
                                >
                                    <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, width: '20px' }}>
                                        <link.icon
                                            size={20}
                                            color={(isActive || isChildActive) ? '#60a5fa' : '#94a3b8'}
                                            strokeWidth={2.5}
                                        />
                                        {link.isNotif && unreadCount > 0 && (
                                            <span style={{
                                                position: 'absolute', top: 0, right: 0,
                                                width: '8px', height: '8px', background: '#ef4444',
                                                borderRadius: '50%', border: '2px solid #0f172a',
                                                transform: 'translate(40%, -40%)',
                                            }} />
                                        )}
                                    </div>
                                     <span style={{
                                        opacity: collapsed ? 0 : 1,
                                        width: collapsed ? 0 : '120px',
                                        overflow: 'hidden',
                                        transition: 'opacity 0.2s ease, width 0.3s ease',
                                    }}>
                                        {link.label}
                                    </span>
                                </Link>

                                {/* Subitems */}
                                {link.subItems && (dashExpanded || isChildActive) && !collapsed && (
                                    <div style={{ marginLeft: '24px', paddingLeft: '16px', borderLeft: '1px solid #334155', marginBottom: '4px' }}>
                                        {link.subItems.map(sub => {
                                            const isSubActive = location.pathname.startsWith(sub.href);
                                            return (
                                                <Link
                                                    key={sub.href}
                                                    to={sub.href}
                                                    style={{
                                                        display: 'block',
                                                        padding: '10px 16px',
                                                        borderRadius: '8px',
                                                        textDecoration: 'none',
                                                        fontSize: '13px',
                                                        fontWeight: isSubActive ? 600 : 400,
                                                        color: isSubActive ? '#60a5fa' : '#94a3b8',
                                                        background: isSubActive ? 'rgba(30,41,59,0.6)' : 'transparent',
                                                        marginBottom: '2px',
                                                        transition: 'all 0.15s ease',
                                                    }}
                                                >
                                                    {sub.label}
                                                </Link>
                                            );
                                        })}
                                    </div>
                                )}
                            </div>
                        );
                    })}
                </nav>

                {/* Footer Sign Out */}
                <div style={{ padding: '16px', borderTop: '1px solid #1e293b', background: '#0f172a', flexShrink: 0 }}>
                    <button
                        onClick={() => setLogoutModalOpen(true)}
                        style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: '14px',
                            width: '100%',
                            padding: '12px 12px 12px 16px',
                            borderRadius: '12px',
                            background: 'transparent',
                            border: 'none',
                            color: '#cbd5e1',
                            fontSize: '14px',
                            fontWeight: 600,
                            cursor: 'pointer',
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            transition: 'all 0.2s ease',
                        }}
                        onMouseEnter={e => { e.currentTarget.style.background = 'rgba(239,68,68,0.1)'; e.currentTarget.style.color = '#f87171'; }}
                        onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = '#cbd5e1'; }}
                    >
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, width: '20px' }}>
                            <LogOut size={20} strokeWidth={2.5} />
                        </div>
                        <span style={{ opacity: collapsed ? 0 : 1, transition: 'opacity 0.3s ease' }}>
                            Sign out
                        </span>
                    </button>
                </div>
            </aside>

            <ModalLogout
                isOpen={logoutModalOpen}
                onClose={() => setLogoutModalOpen(false)}
                onConfirmLogout={handleConfirmLogout}
            />
        </>
    );
}

export default SideBar;