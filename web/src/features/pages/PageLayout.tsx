import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import SideBar from "../components/SideBar";
import TopBar from "../components/TopBar";
import { useAuth } from "../context/AuthContext";
import "./PageStyle.css"; // Kept for legacy page content compat

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

  const navigate = useNavigate();
  const { logout } = useAuth();

  function handleLogout(): void {
    logout();
    localStorage.clear();
    navigate("/login");
  }

  useEffect(() => {
    document.body.classList.add("dark"); // Ensure tailwind dark mode if needed
    return () => {
      document.body.classList.remove("dark");
    };
  }, []);

  return (
      <div style={{ display: 'flex', minHeight: '100vh', background: '#080b14', color: '#e2e8f0', overflow: 'hidden' }}>
        <SideBar
          collapsed={collapsed}
          onToggle={() => setCollapsed(!collapsed)}
          handleLogout={handleLogout}
        />
        
        {/* Main Content Wrapper */}
        <div style={{
          display: 'flex',
          flex: 1,
          flexDirection: 'column',
          height: '100vh',
          overflow: 'hidden',
          marginLeft: collapsed ? '80px' : '280px',
          transition: 'margin-left 0.5s ease-in-out'
        }}>
          <TopBar
            handleLogout={handleLogout}
          />
          
          <main style={{ flex: 1, overflowY: 'auto', width: '100%' }}>
             <div style={{ padding: '32px', maxWidth: '1280px', margin: '0 auto', width: '100%' }}>
               {children}
             </div>
          </main>
        </div>
      </div>
  );
};

export default PageLayout;
