import React, { type JSX } from "react";
import "./SideBar.css";
import { Home, Bell, BarChart2, LogOut, ChevronLeft, ChevronRight, Info, Bot } from "lucide-react";
import OrbitLogo from "../../assets/ORBIT.png";
import CompanyNameLogo from "../../assets/Logo-Name.png";
import { useNavigate } from "react-router-dom";

interface SideBarProps {
  collapsed: boolean;
  onToggle: () => void;
  selectedSection: { parent: string; child?: string };
  onSelectSection: (section: { parent: string; child?: string }) => void;
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

const SideBar: React.FC<SideBarProps> = ({
  collapsed,
  onToggle,
  selectedSection,
  onSelectSection,
}) => {
  const navigate = useNavigate();

  return (
    <aside className={`sidebar ${collapsed ? "collapsed" : ""}`}>
      <div className="sidebar-top">
        <div className="logo-container">
          <img src={OrbitLogo} alt="Logo" className="logo-icon" />
          {!collapsed && <img src={CompanyNameLogo} alt="Company Name" className="logo-name" />}
        </div>
      </div>

      <ul className="sidebar-list">
        <li className="menu-item toggle-btn">
          <div title="Navigation Menu" className="menu-main" onClick={onToggle}>
            {collapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
            {!collapsed && <span className="label">Navigation Menu</span>}
          </div>
        </li>

        {sections.map((section) => {
          const isActive =
            selectedSection.parent === section.id ||
            section.subItems?.some((item) => item.id === selectedSection.child);

          return (
            <li key={section.id} className={`menu-item ${isActive ? "active" : ""}`}>
              <div
                className="menu-main"
                onClick={() => {
                  onSelectSection({ parent: section.id });
                  // Navigate to parent page
                  if (section.id === "Dashboard") navigate("/dashboard");
                  else if (section.id === "Usage") navigate("/usage");
                  else if (section.id === "Notification") navigate("/notifications");
                  else if (section.id === "LLM") navigate("/llm");
                  else if (section.id === "About") navigate("/about");
                }}
              >
                {section.icon}
                {!collapsed && <span className="label">{section.label}</span>}
              </div>

              {section.subItems && !collapsed && (
                <ul className="submenu">
                  {section.subItems.map((sub) => (
                    <li
                      key={sub.id}
                      className={`submenu-item ${
                        selectedSection.child === sub.id ? "active" : ""
                      }`}
                      onClick={(e) => {
                        e.stopPropagation();
                        onSelectSection({ parent: section.id, child: sub.id });
                        navigate(`/dashboard/${sub.id.toLowerCase()}`);
                      }}
                    >
                      <span className="dot" />
                      <span>{sub.label}</span>
                    </li>
                  ))}
                </ul>
              )}
            </li>
          );
        })}
      </ul>

      {/* Logout */}
      <div className="sidebar-logout" onClick={() => onSelectSection({ parent: "logout" })}>
        <LogOut size={18} />
        {!collapsed && <span>Logout</span>}
      </div>
    </aside>
  );
};

export default SideBar;
