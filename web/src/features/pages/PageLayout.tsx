import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import SideBar from "../components/SideBar";
import TopBar from "../components/TopBar";
import { useAuth } from "../context/authContext";
import "./PageStyle.css";

interface SelectedSection {
  parent: string;
  child?: string;
}

interface PageLayoutProps {
  initialSection?: SelectedSection;
  children: React.ReactNode;
}

const PageLayout: React.FC<PageLayoutProps> = ({ initialSection, children }) => {
  const [collapsed, setCollapsed] = useState(false);
  const [selectedSection, setSelectedSection] = useState<SelectedSection>(
    initialSection ?? { parent: "Dashboard" }
  );
  const [darkMode, setDarkMode] = useState(false);

  const navigate = useNavigate();
  const { logout } = useAuth();

  function handleLogout(): void {
    logout();
    navigate("/login");
  }

  return (
    <div className="dashboard-container">
      <SideBar
        collapsed={collapsed}
        onToggle={() => setCollapsed(!collapsed)}
        selectedSection={selectedSection}
        onSelectSection={setSelectedSection}
        handleLogout={handleLogout}
      />

      <TopBar
        collapsed={collapsed}
        darkMode={darkMode}
        setDarkMode={setDarkMode}
        handleLogout={handleLogout}
        user={{ initial: "G", name: "Gemerald De Guzman", id: "97129", roleLabel: "Admin" }}
      />

      <div className={`dashboard-content ${collapsed ? "expanded" : ""}`}>
        {children}
      </div>
    </div>
  );
};

export default PageLayout;
