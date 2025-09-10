import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import SideBar from "../components/SideBar";
import TopBar from "../components/topBar";
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

const PageLayout: React.FC<PageLayoutProps> = ({ children }) => {
  const [collapsed, setCollapsed] = useState(false);
  const [darkMode, setDarkMode] = useState(false);

  const navigate = useNavigate();
  const { logout } = useAuth();

  function handleLogout(): void {
    logout();
    navigate("/login");
  }

  useEffect(() => {
    document.body.classList.add("dashboard");
    return () => {
      document.body.classList.remove("dashboard");
    };
  }, []);

  return (
      <div className="dashboard-container">
        <SideBar
          collapsed={collapsed}
          onToggle={() => setCollapsed(!collapsed)}
        />

        <TopBar
          collapsed={collapsed}
          darkMode={darkMode}
          setDarkMode={setDarkMode}
          handleLogout={handleLogout}
          user={{ initial: "G", name: "Geremald De Guzman", id: "97129", roleLabel: "Admin" }}
        />

        <div className={`dashboard-content ${collapsed ? "expanded" : ""}`}>
          {children}
        </div>
      </div>
  );
};

export default PageLayout;
