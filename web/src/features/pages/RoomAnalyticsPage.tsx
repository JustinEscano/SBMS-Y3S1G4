import React, { useEffect, useState } from "react";
import { roomService } from "../services/roomService";
import axiosInstance from "../../service/AppService";
import type { Room } from "../types/dashboardTypes";
import type { RoomAnalytics, EquipmentSummary } from "../types/sensorLogTypes";
import PageLayout from "./PageLayout"; // ✅ import your layout
import "../pages/PageStyle.css";

const RoomAnalyticsPage: React.FC = () => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<string>("");
  const [analytics, setAnalytics] = useState<RoomAnalytics | null>(null);

  // Fetch all rooms
  useEffect(() => {
    roomService.getAll().then(setRooms).catch(console.error);
  }, []);

  // Fetch analytics when a room is selected
  useEffect(() => {
    if (selectedRoom) {
      axiosInstance
        .get<RoomAnalytics>(`/api/analytics/room/${selectedRoom}/`)
        .then((res) => setAnalytics(res.data))
        .catch(console.error);
    } else {
      setAnalytics(null);
    }
  }, [selectedRoom]);

  return (
    <PageLayout initialSection={{ parent: "Analytics" }}>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-semibold text-white">Room Analytics</h2>
      </div>
      <p className="text-gray-400 text-sm mb-4">View detailed status and equipment health for specific rooms</p>

      {/* Room Selector */}
      <div className="flex space-x-4 mb-6">
        <select
          value={selectedRoom}
          onChange={(e) => setSelectedRoom(e.target.value)}
          className="dropdown-styled"
        >
          <option value="">Select a Room</option>
          {rooms.map((room) => (
            <option key={room.id} value={room.id}>
              {room.name}
            </option>
          ))}
        </select>
      </div>

      {/* Analytics Section */}
      {analytics && (
        <div className="space-y-6">
          {/* Overall Room Status */}
          <div className="stat-card">
            <h3 className="stat-card-title">Room Overview: {analytics.room.name}</h3>
            <div className="stat-card-grid">
              <div>
                <p className="stat-item-label">Total Equipment</p>
                <p className="stat-item-value">{analytics.overall_status.equipment_count}</p>
              </div>
              <div>
                <p className="stat-item-label">Online</p>
                <p className="stat-item-value text-green-400">{analytics.overall_status.online}</p>
              </div>
              <div>
                <p className="stat-item-label">Offline</p>
                <p className="stat-item-value text-gray-500">{analytics.overall_status.offline}</p>
              </div>
              <div>
                <p className="stat-item-label">Maintenance</p>
                <p className="stat-item-value text-blue-400">{analytics.overall_status.maintenance}</p>
              </div>
              <div>
                <p className="stat-item-label">Error</p>
                <p className="stat-item-value text-red-500">{analytics.overall_status.error}</p>
              </div>
            </div>
          </div>

          {/* Equipment By Mode */}
          {(["hvac", "lighting", "security"] as const).map((mode) => {
            const modeData: EquipmentSummary[] | undefined =
              analytics.equipment_by_mode[mode];

            if (!modeData || modeData.length === 0) return null;

            return (
              <div key={mode} className="chart-panel">
                <h3 className="chart-panel-title capitalize mb-4">{mode} Equipment</h3>
                <ul className="space-y-3">
                  {modeData.map((eq) => (
                    <li key={eq.id} className="p-4 bg-[#0f172a] rounded-xl border border-gray-700/50 hover:bg-[#1e293b] transition-colors flex flex-col sm:flex-row justify-between sm:items-center gap-3">
                      <div>
                        <span className="text-white font-medium block">
                          {eq.name}
                        </span>
                        <span className={`text-xs px-2 py-0.5 mt-1 inline-block rounded-full ${
                          eq.status.toLowerCase() === 'online' ? 'bg-green-500/20 text-green-400' :
                          eq.status.toLowerCase() === 'offline' ? 'bg-gray-500/20 text-gray-400' :
                          eq.status.toLowerCase() === 'error' ? 'bg-red-500/20 text-red-400' :
                          'bg-blue-500/20 text-blue-400'
                        }`}>
                          {eq.status}
                        </span>
                      </div>
                      
                      {eq.latest_log && (
                        <div className="text-sm text-gray-400 flex flex-wrap gap-x-4 gap-y-1 sm:text-right ml-auto">
                          {eq.latest_log.temperature !== undefined &&
                            <span>Temp: <strong className="text-gray-200">{eq.latest_log.temperature}°C</strong></span>}
                          {eq.latest_log.humidity !== undefined &&
                            <span>Humidity: <strong className="text-gray-200">{eq.latest_log.humidity}%</strong></span>}
                          {eq.latest_log.light_level !== undefined &&
                            <span>Light: <strong className="text-gray-200">{eq.latest_log.light_level} lx</strong></span>}
                          {eq.latest_log.energy_usage !== undefined &&
                            <span>Energy: <strong className="text-gray-200">{eq.latest_log.energy_usage} kWh</strong></span>}
                          {eq.latest_log.motion_detected !== undefined &&
                            <span>Motion: <strong className={eq.latest_log.motion_detected ? "text-red-400" : "text-green-400"}>
                              {eq.latest_log.motion_detected ? "Detected" : "Clear"}
                            </strong></span>}
                        </div>
                      )}
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </div>
      )}
    </PageLayout>
  );
};

export default RoomAnalyticsPage;
