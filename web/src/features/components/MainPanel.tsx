import React, { useState } from 'react';
import './MainPanel.css'
import type { Room } from '../types/roomTypes';
import type { Equipment } from '../types/equipmentTypes';

interface MainPanelProps {
  selectedSection: string;
  rooms: Room[];
  equipment: Equipment[];
}

const MainPanel: React.FC<MainPanelProps> = ({
  selectedSection,
  rooms,
  equipment,
}) => {
  const [expandedRoomId, setExpandedRoomId] = useState<string | null>(null);

  const toggleEquipment = (roomId: string) => {
  setExpandedRoomId((prev: string | null) => (prev === roomId ? null : roomId));
  };

  if (selectedSection === 'Rooms') {
    return (
      <div className="dashboard-main">
        <h2>Room Overview</h2>
        <div className="room-grid">
          {rooms.map((room) => {
            const roomEquipment = equipment.filter(e => e.room_id === room.id);
            const isExpanded = expandedRoomId === room.id;

            return (
              <div key={room.id} className="room-card">
                <h3>{room.name}</h3>
                <p><strong>Floor:</strong> {room.floor}</p>
                <p><strong>Capacity:</strong> {room.capacity}</p>
                <p><strong>Type:</strong> {room.type}</p>

                <button className="toggle-button" onClick={() => toggleEquipment(room.id)}>
                  {isExpanded ? 'Hide Equipment' : 'Show Equipment'}
                </button>

                {isExpanded && (
                  <div className="equipment-section">
                    <h4>Equipment</h4>
                    {roomEquipment.length > 0 ? (
                      <ul>
                        {roomEquipment.map(eq => (
                          <li key={eq.id}>{eq.name}</li>
                        ))}
                      </ul>
                    ) : (
                      <p>No equipment found.</p>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  return (
    <div className="dashboard-main">
      <h2>{selectedSection}</h2>
      <p>This section is under construction.</p>
    </div>
  );
};

export default MainPanel;