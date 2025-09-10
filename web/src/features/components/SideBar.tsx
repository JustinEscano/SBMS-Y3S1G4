import React, { type JSX } from "react";
import "./SideBar.css";
import {
  Home,
  Bell,
  BarChart2,
  LogOut,
  ChevronLeft,
  ChevronRight,
  Info,
  Bot,
} from "lucide-react";
import OrbitLogo from "../../assets/ORBIT.png";
import CompanyNameLogo from "../../assets/Logo-Name.png";
import { useNavigate, useLocation } from "react-router-dom";

interface SideBarProps {
  collapsed: boolean;
  onToggle: () => void;
}

interface Section {
  id: string;
  label: string;
  icon: JSX.Element;
  path?: string;
  subItems?: { id: string; label: string; path: string }[];
}

const sections: Section[] = [
  {
    id: "Dashboard",
    label: "Dashboard",
    icon: <Home size={18} />,
    path: "/dashboard",
    subItems: [
      { id: "HVAC", label: "HVAC", path: "/dashboard/hvac" },
      { id: "Lighting", label: "Lighting", path: "/dashboard/lighting" },
      { id: "Security", label: "Security", path: "/dashboard/security" },
      { id: "Maintenance", label: "Maintenance", path: "/dashboard/maintenance" },
    ],
  },
  {
    id: "Usage",
    label: "Usage Analytics",
    icon: <BarChart2 size={18} />,
    path: "/usage",
    subItems: [{ id: "Room", label: "Room Use", path: "/usage/room" }],
  },
  { id: "Notification", label: "Notification", icon: <Bell size={18} />, path: "/notifications" },
  { id: "LLM", label: "LLM Chat", icon: <Bot size={18} />, path: "/llm" },
  { id: "About", label: "About Us", icon: <Info size={18} />, path: "/about" },
];

const SideBar: React.FC<SideBarProps> = ({ collapsed, onToggle }) => {
  const navigate = useNavigate();
  const location = useLocation();

  // Determine active section + subItem
  const getActiveSection = () => {
    const path = location.pathname.toLowerCase();
    for (const section of sections) {
      if (section.subItems) {
        for (const sub of section.subItems) {
          if (path.startsWith(sub.path.toLowerCase())) {
            return { parent: section.id, child: sub.id };
          }
        }
      }
      if (section.path && path.startsWith(section.path.toLowerCase())) {
        return { parent: section.id };
      }
    }
    return { parent: "" };
  };

  const active = getActiveSection();

  return (
    <aside className={`sidebar ${collapsed ? "collapsed" : ""}`}>
      {/* Logo */}
      <div className="sidebar-top">
        <div className="logo-container">
          <img src={OrbitLogo} alt="Logo" className="logo-icon" />
          {!collapsed && (
            <img src={CompanyNameLogo} alt="Company Name" className="logo-name" />
          )}
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

        {/* Sections */}
        {sections.map((section) => {
          const isParentActive = active.parent === section.id && !active.child;
          const isExpanded = active.parent === section.id;

          return (
            <li
              key={section.id}
              className={`menu-item ${isParentActive ? "active" : ""}`}
            >
              <div
                className="menu-main"
                onClick={() => section.path && navigate(section.path)}
              >
                {section.icon}
                {!collapsed && <span className="label">{section.label}</span>}
              </div>

              {/* Submenu */}
              {section.subItems && isExpanded && !collapsed && (
                <ul className="submenu">
                  {section.subItems.map((sub) => (
                    <li
                      key={sub.id}
                      className={`submenu-item ${active.child === sub.id ? "active" : ""}`}
                      onClick={(e) => {
                        e.stopPropagation();
                        navigate(sub.path);
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
      <div className="sidebar-logout" onClick={() => navigate("/logout")}>
        <LogOut size={18} />
        {!collapsed && <span>Logout</span>}
      </div>
    </aside>
  );
};

export default SideBar;
