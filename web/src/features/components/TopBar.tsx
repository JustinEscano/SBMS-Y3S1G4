import React from 'react';
import './TopBar.css';

interface TopBarProps {
  username?: string;
}

const TopBar: React.FC<TopBarProps> = ({ username }) => {
  return (
    <header className="topbar">
      <div className="topbar-left">
        <h1 className="topbar-title">Dashboard</h1>
      </div>
      <div className="topbar-right">
        <span className="topbar-user">Hello, {username || 'Admin'}</span>
      </div>
    </header>
  );
};

export default TopBar;