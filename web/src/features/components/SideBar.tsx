import React from 'react';

interface SideBarProps {
  selectedSection: string;
  onSelectSection: (section: string) => void;
}

const SideBar: React.FC<SideBarProps> = ({ selectedSection, onSelectSection }) => {
  const sections = ['Rooms', 'Sensor Logs', 'Maintenance'];

  return (
    <div className="dashboard-sidebar">
      <h3>Navigation</h3>
      <ul>
        {sections.map((section) => (
          <li
            key={section}
            className={selectedSection === section ? 'active' : ''}
            onClick={() => onSelectSection(section)}
          >
            {section}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default SideBar;