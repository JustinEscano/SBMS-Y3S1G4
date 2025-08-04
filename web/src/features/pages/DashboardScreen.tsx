import './DashboardScreen.css'; // External CSS for styling
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import TopBar from '../components/TopBar';
import SideBar from '../components/SideBar';
import { useRooms } from '../hooks/useRooms';
import { useEquipment } from '../hooks/useEquipment';
import { useState } from 'react';
import MainPanel from '../components/MainPanel';

const Dashboard: React.FC = () => {
  const navigate = useNavigate();
  const { logout } = useAuth();

  const { rooms: roomList = [] } = useRooms();
  const { equipment: equipmentList = [] } = useEquipment();

  const [selectedSection, setSelectedSection] = useState('Rooms');

  function handleLogout(): void {
    logout();
    navigate('/login');
  }

  return (
    <div className="dashboard-wrapper">
      <TopBar onLogout={handleLogout} username="Admin" />
      <div className="dashboard-content">
        <SideBar
          selectedSection={selectedSection}
          onSelectSection={setSelectedSection}
        />
        <MainPanel
          selectedSection={selectedSection}
          rooms={roomList}
          equipment={equipmentList}
        />
      </div>
    </div>
  );
};

export default Dashboard;
