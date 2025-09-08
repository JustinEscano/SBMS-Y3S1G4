import React, { useState, type JSX } from "react";
import "./SideBar.css";
import { Home, Bell, BarChart2, LogOut, ChevronLeft, ChevronRight, Info, Bot } from "lucide-react";
import OrbitLogo from "../../assets/ORBIT.png";
import CompanyNameLogo from "../../assets/Logo-Name.png";
import { useNavigate, useLocation } from "react-router-dom";
import ModalLogout from "./ModalLogout";

interface SideBarProps {
  collapsed: boolean;
  onToggle: () => void;
  selectedSection: { parent: string; child?: string }; // <-- add this
  onSelectSection: (section: { parent: string; child?: string }) => void; // <-- add this
  handleLogout: () => void;
}


interface Section {
  id: string;
  label: string;
  icon: JSX.Element;
  subItems?: { id: string; label: string }[];
}

const sections: Section[] = [
  {
    id: "Dashboard",
    label: "Dashboard",
    icon: <Home size={18} />,
    subItems: [
      { id: "HVAC", label: "HVAC" },
      { id: "Lighting", label: "Lighting" },
      { id: "Security", label: "Security" },
      { id: "Maintenance", label: "Maintenance" },
    ],
  },
  { id: "Usage", label: "Usage Analytics", icon: <BarChart2 size={18} /> },
  { id: "Notification", label: "Notification", icon: <Bell size={18} /> },
  { id: "LLM", label: "LLM Chat", icon: <Bot size={18} /> },
  { id: "About", label: "About Us", icon: <Info size={18} /> },
];

const SideBar: React.FC<SideBarProps> = ({ collapsed, onToggle, handleLogout }) => {
  const navigate = useNavigate();
  const location = useLocation();
const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  

  // Helper: determine active parent/subitem from path
  const getActiveSection = () => {
    const path = location.pathname.toLowerCase();
    for (const section of sections) {
      if (section.subItems) {
        for (const sub of section.subItems) {
          if (path.includes(sub.id.toLowerCase())) return { parent: section.id, child: sub.id };
        }
      }
      if (path.includes(section.id.toLowerCase())) return { parent: section.id };
    }
    return { parent: "" };
  };

  const active = getActiveSection();

  const handleConfirmLogout = () => {
    setLogoutModalOpen(false);
    handleLogout();
  };

  return (
    <>
    <aside className={`sidebar ${collapsed ? "collapsed" : ""}`}>
      <div className="sidebar-top">
        <div className="logo-container">
          <img src={OrbitLogo} alt="Logo" className="logo-icon" />
          {!collapsed && <img src={CompanyNameLogo} alt="Company Name" className="logo-name" />}
        </div>
      </div>

      <ul className="sidebar-list">
        {/* Toggle button */}
        <li className="menu-item toggle-btn">
          <div title="Navigation Menu" className="menu-main" onClick={onToggle}>
            {collapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
            {!collapsed && <span className="label">Navigation Menu</span>}
          </div>
        </li>

        {sections.map((section) => {
          const isParentActive = active.parent === section.id && !active.child;
          const isExpanded = active.parent === section.id;

          return (
            <li key={section.id} className={`menu-item ${isParentActive ? "active" : ""}`}>
              <div
                className="menu-main"
                onClick={() => {
                  if (section.subItems) {
                    navigate("/dashboard"); // parent always goes to dashboard main
                  } else {
                    const routeMap: Record<string, string> = {
                      Usage: "/usage",
                      Notification: "/notifications",
                      LLM: "/llm",
                      About: "/about",
                    };
                    navigate(routeMap[section.id] || "/");
                  }
                }}
              >
                {section.icon}
                {!collapsed && <span className="label">{section.label}</span>}
              </div>

              {section.subItems && isExpanded && !collapsed && (
                <ul className="submenu">
                  {section.subItems.map((sub) => (
                    <li
                      key={sub.id}
                      className={`submenu-item ${active.child === sub.id ? "active" : ""}`}
                      onClick={(e) => {
                        e.stopPropagation();
                        navigate(`/dashboard/${sub.id.toLowerCase()}`);
                      }}
                    >
                      <span>{sub.id === "HVAC" ? sub.label.toUpperCase() : sub.label}</span>
                    </li>
                  ))}
                </ul>
              )}
            </li>
          );
        })}
      </ul>

      {/* Logout */}
      <div className="sidebar-logout" onClick={() => setLogoutModalOpen(true)}>
        <LogOut size={18} />
        {!collapsed && <span>Logout</span>}
      </div>
    </aside>

    <ModalLogout
        isOpen={logoutModalOpen}
        onClose={() => setLogoutModalOpen(false)}
        onConfirmLogout={handleConfirmLogout}
      />
      </>
  );
};

export default SideBar;
