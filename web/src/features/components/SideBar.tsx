import React from 'react';
import { useState } from "react";
import './Sidebar.css';
import {
  Menu,
  X,
  BarChart3,
  Thermometer,
  Lightbulb,
  Shield,
  Wrench,
  TrendingUp,
  Bell,
  MessageCircle,
  Info,
  LogOut,
  ChevronDown,
  ChevronRight,
} from "lucide-react"

interface SideBarProps {
  selectedSection: string;
  onSelectSection: (section: string) => void;  
  onLogout: () => void;
}

const SideBar: React.FC<SideBarProps> = ({ selectedSection, onSelectSection, onLogout }) => {
  const sections = [
    { name: "Rooms", icon: Thermometer },
    { name: "Sensor Logs", icon: Lightbulb },
    { name: "Security", icon: Shield },
    { name: "Maintenance", icon: Wrench },
  ]
  const otherSections = [
    { name: "USAGE ANALYTICS", icon: TrendingUp },
    { name: "NOTIFICATION", icon: Bell },
    { name: "LLM CHAT", icon: MessageCircle },
    { name: "ABOUT US", icon: Info },
  ]
  const logout = [{ name: "Logout", icon: LogOut }]

  const [dropdownOpen, setDropdownOpen] = useState(true)

  const toggleDropdown = () => {
    setDropdownOpen(!dropdownOpen)
  }
  return (
    <div className="dashboard-sidebar">
      <h3>Navigation</h3>
      <ul>
              <button
                className={selectedSection === "DASHBOARD" ? "active" : ""}
                onClick={toggleDropdown}
                aria-label="Dashboard dropdown"
              >
                <BarChart3 size={20} />
                {
                  <>
                    <span className="sidebar__nav-text">DASHBOARD</span>
                    {/* Dropdown arrow */}
                    <div className="sidebar__dropdown-arrow">
                      {dropdownOpen ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                    </div>
                  </>
                }
              </button>

              {/* Dashboard dropdown sub-items */}
              {dropdownOpen && (
                <ul className="sidebar__dropdown">
                  {sections.map((subItem) => {
                    const SubIcon = subItem.icon
                    return (
                      <li key={subItem.name}>
                        <button
                          className={`sidebar__nav-item sidebar__nav-item--sub ${
                            selectedSection === subItem.name
                              ? "sidebar__nav-item--active"
                              : "sidebar__nav-item--inactive"
                          }`}
                          onClick={() => onSelectSection(subItem.name)}
                          aria-label={subItem.name}
                        >
                          <SubIcon size={18} />
                          <span>{subItem.name}</span>
                        </button>
                      </li>
                    )
                  })}
                </ul>
              )}
              {otherSections.map((item) => {
              const Icon = item.icon
              return (
                <li key={item.name}>
                  <button
                    className={`sidebar__nav-item ${
                      selectedSection === item.name ? "sidebar__nav-item--active" : "sidebar__nav-item--inactive"
                    }`}
                    onClick={() => onSelectSection(item.name)}
                    aria-label={item.name}
                  >
                    <Icon size={20} />
                    {/* Navigation text - Only visible when sidebar is open */}
                    {<span>{item.name}</span>}
                  </button>
                </li>
              )
            })}
            {logout.map((item) => {
                  const Icon = item.icon
                  return (
                    <li key={item.name}>
                      <button className="logout-button"
                      onClick={onLogout}>
                        <Icon size={20} />
                        {<span>{item.name}</span>}
                      </button>
                    </li>
                  )})}
      </ul>
    </div>
  );
};

export default SideBar;