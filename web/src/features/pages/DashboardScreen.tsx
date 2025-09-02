import React, { useState } from "react";
import SideBar from "../components/SideBar";
import "./PageStyle.css";
import "./DashboardContent.css";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import TopBar from "../components/TopBar";
import { useRooms } from "../hooks/useRooms"; 
import { useEquipment } from "../hooks/useEquipment"; // ✅ import equipment hook
import type { Room } from "../types/roomTypes";
import type { Equipment } from "../types/equipmentTypes";

interface SelectedSection {
  parent: string;
  child?: string;
}

const Dashboard: React.FC = () => {
  const [collapsed, setCollapsed] = useState(false);
  const [selectedSection, setSelectedSection] = useState<SelectedSection>({
    parent: "Dashboard",
  });
  const [darkMode, setDarkMode] = useState(false);

  const navigate = useNavigate();
  const { logout } = useAuth();
  const { rooms, loading: roomsLoading } = useRooms(); 
  const { equipment, loading: equipmentLoading } = useEquipment(); // ✅ get equipment

  function handleLogout(): void {
    logout();
    navigate("/login");
  }

  // ✅ map equipment to room counts
  const equipmentByRoom: Record<string, Equipment[]> = equipment.reduce((acc, eq) => {
    if (!acc[eq.room]) acc[eq.room] = [];
    acc[eq.room].push(eq);
    return acc;
  }, {} as Record<string, Equipment[]>);

  return (
    <div className="dashboard-container">
      <SideBar
        collapsed={collapsed}
        onToggle={() => setCollapsed(!collapsed)}
        selectedSection={selectedSection}
        onSelectSection={setSelectedSection}
      />

      <TopBar
        collapsed={collapsed}
        darkMode={darkMode}
        setDarkMode={setDarkMode}
        handleLogout={handleLogout}
        user={{ initial: "G", name: "Geremald De Guzman", id: "97129", roleLabel: "Admin" }}
      />

      <div className={`dashboard-content ${collapsed ? "expanded" : ""}`}>
        <h1>Dashboard</h1>
        <div className="content-container">
          {/* Stat boxes */}
          <div className="stats-boxes">
            <div className="stat-box">
              <div className="stat-icon">🏢</div>
              <div className="stat-info">
                <p className="stat-number">{rooms.length}</p>
                <p className="stat-label">Total Rooms</p>
              </div>
            </div>

            <div className="stat-box">
              <div className="stat-icon">🔌</div>
              <div className="stat-info">
                <p className="stat-number">
                  {rooms.filter(r => (equipmentByRoom[r.id]?.length ?? 0) > 0).length}
                </p>
                <p className="stat-label">Rooms with Equipment</p>
              </div>
            </div>

            <div className="stat-box">
              <div className="stat-icon">❌</div>
              <div className="stat-info">
                <p className="stat-number">
                  {rooms.filter(r => (equipmentByRoom[r.id]?.length ?? 0) === 0).length}
                </p>
                <p className="stat-label">Empty Rooms</p>
              </div>
            </div>
          </div>

          {/* Room Table */}
          <div className="hvac-table">
            <h2>Room Summary</h2>

            {/* Search + Date Filter */}
            <div className="table-controls">
              <input type="text" placeholder="Search for room name" />
              <select>
                <option>Day</option>
                <option>Week</option>
                <option>Month</option>
              </select>
              <button>Search</button>
            </div>

            {/* Room Summary Table */}
            {roomsLoading || equipmentLoading ? (
              <p>Loading data...</p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Room ID</th>
                    <th>Name</th>
                    <th>Floor</th>
                    <th>Capacity</th>
                    <th>Type</th>
                    <th>Equipment Count</th>
                  </tr>
                </thead>
                <tbody>
                  {rooms.map((room: Room) => (
                    <tr key={room.id}>
                      <td>{room.id}</td>
                      <td>{room.name}</td>
                      <td>{room.floor}</td>
                      <td>{room.capacity}</td>
                      <td>{room.type}</td>
                      <td>{equipmentByRoom[room.id]?.length ?? 0}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
