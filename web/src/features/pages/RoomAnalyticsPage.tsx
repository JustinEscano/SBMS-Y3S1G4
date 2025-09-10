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
      <div className="p-6 space-y-6">
        {/* Room Selector */}
        <div className="flex space-x-4">
          <select
            value={selectedRoom}
            onChange={(e) => setSelectedRoom(e.target.value)}
            className="border rounded p-2"
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
            <div className="p-4 bg-gray-100 rounded shadow">
              <h2 className="text-lg font-bold">Room: {analytics.room.name}</h2>
              <p>Total equipment: {analytics.overall_status.equipment_count}</p>
              <p>Online: {analytics.overall_status.online}</p>
              <p>Offline: {analytics.overall_status.offline}</p>
              <p>Maintenance: {analytics.overall_status.maintenance}</p>
              <p>Error: {analytics.overall_status.error}</p>
            </div>

            {/* Equipment By Mode */}
            {(["hvac", "lighting", "security"] as const).map((mode) => {
              const modeData: EquipmentSummary[] | undefined =
                analytics.equipment_by_mode[mode];

              if (!modeData || modeData.length === 0) return null;

              return (
                <div key={mode} className="p-4 bg-white rounded shadow">
                  <h3 className="text-md font-semibold capitalize">{mode}</h3>
                  <ul className="space-y-2">
                    {modeData.map((eq) => (
                      <li key={eq.id} className="p-2 border rounded">
                        <div className="flex justify-between">
                          <span>
                            {eq.name} ({eq.status})
                          </span>
                          {eq.latest_log && (
                            <span className="text-sm text-gray-600">
                              {eq.latest_log.temperature !== undefined &&
                                `Temp: ${eq.latest_log.temperature}°C | `}
                              {eq.latest_log.humidity !== undefined &&
                                `Humidity: ${eq.latest_log.humidity}% | `}
                              {eq.latest_log.light_level !== undefined &&
                                `Light: ${eq.latest_log.light_level} lx | `}
                              {eq.latest_log.energy_usage !== undefined &&
                                `Energy: ${eq.latest_log.energy_usage} kWh | `}
                              {eq.latest_log.motion_detected !== undefined &&
                                `Motion: ${
                                  eq.latest_log.motion_detected ? "Yes" : "No"
                                }`}
                            </span>
                          )}
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </PageLayout>
  );
};

export default RoomAnalyticsPage;
