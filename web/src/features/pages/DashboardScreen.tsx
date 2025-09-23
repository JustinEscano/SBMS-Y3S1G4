import React, { useState, useEffect, useMemo, useRef } from "react";
import type { Room, Equipment } from "../types/dashboardTypes";
import RoomModal from "../components/roomModal";
import { roomService } from "../services/roomService";
import { equipmentService } from "../services/equipmentService";
import PageLayout from "../pages/PageLayout";
import Pagination from "../components/Pagination";
import "../pages/PageStyle.css";

type RoomModalMode = "add" | "edit" | "delete";
<<<<<<< HEAD

interface SensorData {
  equipment_id: string;
  equipment_name: string;
  device_id: string;
  temperature: number;
  humidity: number;
  light_level: number;
  motion_detected: boolean;
  energy_usage: number;
  recorded_at: string;
  status: string;
}

interface ESP32Response {
  success: boolean;
  data: SensorData[];
  count: number;
}

interface SystemData {
  avgTemperature?: number;
  avgHumidity?: number;
  activeZones?: number;
  totalZones?: number;
  status?: string;
  energyEfficiency?: number;
  totalDevices?: number;
  activeDevices?: number;
  avgLightLevel?: number;
  energySaving?: number;
  motionDetections?: number;
  alertsToday?: number;
  lastIncident?: string;
}

=======
>>>>>>> web-only
const ITEMS_PER_PAGE = 5;
const SENSOR_REFRESH_INTERVAL = 10000; // 10 seconds

const DashboardScreen: React.FC = () => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [search, setSearch] = useState("");
  const [modalMode, setModalMode] = useState<RoomModalMode | null>(null);
<<<<<<< HEAD
  const [selectedRoom, setSelectedRoom] = useState<Room | undefined>(undefined);
  const [currentPage, setCurrentPage] = useState(1);

  // ESP32 Sensor Data State
  const [sensorData, setSensorData] = useState<SensorData[]>([]);
  const [isAutoRefresh, setIsAutoRefresh] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null);
  const [sensorError, setSensorError] = useState<string>("");
  const [isLoadingSensors, setIsLoadingSensors] = useState(false);

  // System Data State
  const [hvacData, setHvacData] = useState<SystemData>({});
  const [lightingData, setLightingData] = useState<SystemData>({});
  const [securityData, setSecurityData] = useState<SystemData>({});

  // Fetch rooms
  useEffect(() => {
    const fetchRooms = async () => {
      try {
        const data = await roomService.getAll();
        setRooms(data);
      } catch (error) {
        console.error('Error fetching rooms:', error);
      }
    };
    fetchRooms();
  }, []);

  // Fetch ESP32 sensor data
  const fetchSensorData = async () => {
    if (isLoadingSensors) return; // Prevent multiple simultaneous requests
    
    setIsLoadingSensors(true);
    try {
      const response = await fetch('/api/esp32/latest/');
      if (response.ok) {
        const data: ESP32Response = await response.json();
        if (data.success) {
          setSensorData(data.data || []);
          setLastUpdate(new Date());
          setSensorError("");
          generateSystemData(data.data || []);
        }
      } else {
        setSensorError("Failed to fetch sensor data");
      }
    } catch (error) {
      setSensorError("Error connecting to sensor API");
      console.error('Error fetching sensor data:', error);
    } finally {
      setIsLoadingSensors(false);
    }
  };

  // Generate system data based on sensor readings
  const generateSystemData = (sensors: SensorData[]) => {
    if (sensors.length === 0) return;

    // HVAC Data
    const validSensors = sensors.filter(s => s.temperature != null && s.humidity != null);
    const avgTemp = validSensors.reduce((sum, s) => sum + s.temperature, 0) / validSensors.length;
    const avgHumidity = validSensors.reduce((sum, s) => sum + s.humidity, 0) / validSensors.length;
    const activeZones = sensors.filter(s => s.status === 'online').length;

    setHvacData({
      avgTemperature: avgTemp || 0,
      avgHumidity: avgHumidity || 0,
      activeZones,
      totalZones: sensors.length,
      status: activeZones > 0 ? 'operational' : 'offline',
      energyEfficiency: activeZones > 0 ? 85 + (activeZones * 2) : 0,
    });

    // Lighting Data
    const avgLightLevel = sensors.reduce((sum, s) => sum + (s.light_level || 0), 0) / sensors.length;
    setLightingData({
      totalDevices: Math.max(sensors.length, rooms.length),
      activeDevices: Math.max(activeZones, Math.round(rooms.length * 0.7)),
      avgLightLevel: avgLightLevel || 450,
      energySaving: activeZones > 0 ? 15 : 25,
      status: activeZones > 0 ? 'optimal' : 'normal',
    });

    // Security Data
    const motionDetections = sensors.filter(s => s.motion_detected).length;
    setSecurityData({
      totalDevices: Math.round(rooms.length * 0.5),
      activeDevices: Math.round(rooms.length * 0.4),
      motionDetections,
      alertsToday: motionDetections > 2 ? motionDetections - 2 : 0,
      status: motionDetections > 5 ? 'alert' : 'secure',
      lastIncident: motionDetections > 0 ? '2 hours ago' : 'None today',
    });
  };

  // Initial sensor data fetch
  useEffect(() => {
    fetchSensorData();
  }, []);

  // Auto-refresh sensor data
  useEffect(() => {
    if (!isAutoRefresh) return;

    const interval = setInterval(() => {
      fetchSensorData();
    }, SENSOR_REFRESH_INTERVAL);

    return () => clearInterval(interval);
  }, [isAutoRefresh]);

  // Reset pagination on new search
=======
  const [selectedRoom, setSelectedRoom] = useState<Room | undefined>();
  const [currentPage, setCurrentPage] = useState(1);

  const [showRequests, setShowRequests] = useState(false);
  const [equipments, setEquipments] = useState<Equipment[]>([]);

  const popupRef = useRef<HTMLDivElement>(null);

  /** Fetch Rooms */
  useEffect(() => {
    roomService.getAll().then(setRooms).catch(console.error);
  }, []);

  /** Fetch Equipments */
>>>>>>> web-only
  useEffect(() => {
    equipmentService.getAll().then(setEquipments).catch(console.error);
  }, []);

  /** Reset pagination on search change */
  useEffect(() => setCurrentPage(1), [search]);

  /** Close popup when clicking outside */
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (popupRef.current && !popupRef.current.contains(e.target as Node)) {
        setShowRequests(false);
      }
    };
    if (showRequests) document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [showRequests]);

  /** Filter + Paginate Rooms */
  const filteredRooms = useMemo(
    () => rooms.filter((r) => r.name.toLowerCase().includes(search.toLowerCase())),
    [rooms, search]
  );
  const totalPages = Math.ceil(filteredRooms.length / ITEMS_PER_PAGE);
  const paginatedRooms = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredRooms.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredRooms, currentPage]);

  /** CRUD Handlers */
  const handleSubmit = async (data: Partial<Room>) => {
    try {
      if (modalMode === "add") {
        const newRoom = await roomService.create(data);
        setRooms((prev) => [...prev, newRoom]);
      } else if (modalMode === "edit" && data.id) {
        const updated = await roomService.update(data.id, data);
        setRooms((prev) =>
          prev.map((r) => (r.id === data.id ? { ...r, ...updated } : r))
        );
      } else if (modalMode === "delete" && data.id) {
        await roomService.remove(data.id);
        setRooms((prev) => prev.filter((r) => r.id !== data.id));
      }
    } catch (err) {
      console.error("Room operation failed:", err);
    } finally {
      setModalMode(null);
      setSelectedRoom(undefined);
    }
  };

  // Helper functions
  const getStatusColor = (status: string): string => {
    switch (status?.toLowerCase()) {
      case 'online':
        return '#4CAF50';
      case 'offline':
        return '#f44336';
      case 'maintenance':
        return '#ff9800';
      case 'error':
        return '#f44336';
      default:
        return '#9e9e9e';
    }
  };

  const getSystemStatusColor = (status: string): string => {
    switch (status?.toLowerCase()) {
      case 'operational':
      case 'optimal':
      case 'secure':
      case 'normal':
        return '#4CAF50';
      case 'alert':
      case 'attention':
        return '#f44336';
      case 'offline':
        return '#9e9e9e';
      default:
        return '#ff9800';
    }
  };

  const formatDateTime = (dateTimeString: string): string => {
    try {
      const dateTime = new Date(dateTimeString);
      const now = new Date();
      const difference = now.getTime() - dateTime.getTime();
      const minutes = Math.floor(difference / (1000 * 60));
      const hours = Math.floor(difference / (1000 * 60 * 60));
      const days = Math.floor(difference / (1000 * 60 * 60 * 24));

      if (minutes < 1) {
        return 'Just now';
      } else if (minutes < 60) {
        return `${minutes}m ago`;
      } else if (hours < 24) {
        return `${hours}h ago`;
      } else {
        return `${days}d ago`;
      }
    } catch (error) {
      return 'Unknown';
    }
  };

  const toggleAutoRefresh = () => {
    setIsAutoRefresh(!isAutoRefresh);
  };

  const onlineEquipment = sensorData.filter(s => s.status === 'online').length;

  return (
    <PageLayout initialSection={{ parent: "Dashboard" }}>
<<<<<<< HEAD
      <div className="dashboard-content">
        <h1>Smart Building Dashboard</h1>

        <div className="content-container">
          {/* Welcome Section */}
          <div className="welcome-section">
            <div className="welcome-card">
              <div className="welcome-header">
                <span className="dashboard-icon">📊</span>
                <div>
                  <h2>Welcome to Smart Building</h2>
                  <p>Monitor and manage your building's systems, equipment, and sensors</p>
                </div>
              </div>
            </div>
          </div>

          {/* Sensor Controls */}
          <div className="sensor-controls">
            <button 
              className={`refresh-toggle ${isAutoRefresh ? 'active' : ''}`}
              onClick={toggleAutoRefresh}
              disabled={isLoadingSensors}
            >
              {isAutoRefresh ? '⏸️ Pause Auto Refresh' : '▶️ Start Auto Refresh'}
            </button>
            <button 
              className="manual-refresh" 
              onClick={fetchSensorData}
              disabled={isLoadingSensors}
            >
              {isLoadingSensors ? '🔄 Loading...' : '🔄 Refresh Now'}
            </button>
            {lastUpdate && (
              <span className="last-update">
                Last updated: {lastUpdate.toLocaleTimeString()}
              </span>
=======
      <div className="page-header">
        <h1>Dashboard &gt; Rooms</h1>
      </div>

      <div className="content-container">
        <div className="stats-boxes">
          <div className="stats-box">
            <div className="stat-icon">🏫</div>
            <div className="stat-info">
              <p className="stat-number">{rooms.length}</p>
              <p className="stat-label">Total Rooms</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">👔</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "office").length}
              </p>
              <p className="stat-label">Offices</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">🔬</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "lab").length}
              </p>
              <p className="stat-label">Laboratory</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">📢</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "meeting").length}
              </p>
              <p className="stat-label">Meeting Room</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">📦</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "storage").length}
              </p>
              <p className="stat-label">Storage</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">🚪</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "corridor").length}
              </p>
              <p className="stat-label">Corridor</p>
            </div>
          </div>
        </div>

        <div className="table-controls">
          <input
            type="text"
            placeholder="Search rooms..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Floor</th>
              <th>Capacity</th>
              <th>Type</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginatedRooms.length > 0 ? (
              paginatedRooms.map((room) => (
                <tr key={room.id}>
                  <td>{room.name}</td>
                  <td>{room.floor}</td>
                  <td>{room.capacity}</td>
                  <td><span className={`type-color type-color-${room.type.toLowerCase()}`}>{room.type.toUpperCase()}</span></td>
                  <td>
                    <button
                      className="edt-btn"
                      onClick={() => {
                        setModalMode("edit");
                        setSelectedRoom(room);
                      }}
                    >
                      Edit
                    </button>
                    <button
                      className="dlt-btn"
                      onClick={() => {
                        setModalMode("delete");
                        setSelectedRoom(room);
                      }}
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={6}>No rooms found</td>
              </tr>
>>>>>>> web-only
            )}
          </div>

<<<<<<< HEAD
          {/* Building Systems Overview */}
          <div className="systems-section">
            <h2>Building Systems</h2>
            <div className="systems-grid">
              <div className="system-card" style={{ borderColor: getSystemStatusColor(hvacData.status || 'offline') }}>
                <div className="system-header">
                  <span className="system-icon">🌡️</span>
                  <div className="system-info">
                    <h3>HVAC</h3>
                    <p>{hvacData.activeZones || 0}/{hvacData.totalZones || 0} Active Zones</p>
                  </div>
                  <span className="system-status" style={{ color: getSystemStatusColor(hvacData.status || 'offline') }}>
                    {(hvacData.status || 'offline').toUpperCase()}
                  </span>
                </div>
                <div className="system-details">
                  <span>Avg Temp: {hvacData.avgTemperature?.toFixed(1) || 'N/A'}°C</span>
                  <span>Efficiency: {hvacData.energyEfficiency || 0}%</span>
                </div>
              </div>

              <div className="system-card" style={{ borderColor: getSystemStatusColor(lightingData.status || 'normal') }}>
                <div className="system-header">
                  <span className="system-icon">💡</span>
                  <div className="system-info">
                    <h3>Lighting</h3>
                    <p>{lightingData.activeDevices || 0}/{lightingData.totalDevices || 0} Active Lights</p>
                  </div>
                  <span className="system-status" style={{ color: getSystemStatusColor(lightingData.status || 'normal') }}>
                    {(lightingData.status || 'normal').toUpperCase()}
                  </span>
                </div>
                <div className="system-details">
                  <span>Avg Light: {lightingData.avgLightLevel?.toFixed(0) || 'N/A'} lux</span>
                  <span>Saving: {lightingData.energySaving || 0}%</span>
                </div>
              </div>

              <div className="system-card" style={{ borderColor: getSystemStatusColor(securityData.status || 'secure') }}>
                <div className="system-header">
                  <span className="system-icon">🔒</span>
                  <div className="system-info">
                    <h3>Security</h3>
                    <p>{securityData.activeDevices || 0} Active Devices</p>
                  </div>
                  <span className="system-status" style={{ color: getSystemStatusColor(securityData.status || 'secure') }}>
                    {(securityData.status || 'secure').toUpperCase()}
                  </span>
                </div>
                <div className="system-details">
                  <span>Motion: {securityData.motionDetections || 0}</span>
                  <span>Alerts: {securityData.alertsToday || 0}</span>
                </div>
              </div>
            </div>
          </div>

          {/* Live ESP32 Sensor Data Section */}
          {sensorData.length > 0 && (
            <div className="sensor-section">
              <div className="section-header">
                <h2>
                  <span className="sensor-icon">📡</span>
                  Live ESP32 Sensor Data
                  <span className="live-badge">LIVE</span>
                </h2>
                {isAutoRefresh && (
                  <div className="auto-refresh-indicator">
                    <span className="refresh-dot"></span>
                    Auto-refresh ON (10s)
                  </div>
                )}
              </div>

              {sensorError && (
                <div className="error-message">
                  ⚠️ {sensorError}
                </div>
              )}

              <div className="sensor-cards">
                {sensorData.map((sensor) => (
                  <div key={sensor.equipment_id} className="sensor-card">
                    <div className="sensor-header">
                      <div className="sensor-info">
                        <div className="sensor-icon-container" style={{ backgroundColor: `${getStatusColor(sensor.status)}20` }}>
                          <span className="sensor-chip-icon" style={{ color: getStatusColor(sensor.status) }}>🔧</span>
                        </div>
                        <div>
                          <h3>{sensor.equipment_name || 'Unknown Device'}</h3>
                          <p className="device-id">Device: {sensor.device_id || 'N/A'}</p>
                        </div>
                      </div>
                      <div className="status-badge" style={{ 
                        backgroundColor: `${getStatusColor(sensor.status)}20`,
                        color: getStatusColor(sensor.status)
                      }}>
                        {sensor.status?.toUpperCase() || 'UNKNOWN'}
                      </div>
                    </div>

                    <div className="sensor-readings">
                      <div className="reading-row">
                        <div className="sensor-value">
                          <span className="value-icon" style={{ color: '#f44336' }}>🌡️</span>
                          <div>
                            <div className="value">{sensor.temperature?.toFixed(1) || 'N/A'}°C</div>
                            <div className="label">Temperature</div>
                          </div>
                        </div>
                        <div className="sensor-value">
                          <span className="value-icon" style={{ color: '#2196F3' }}>💧</span>
                          <div>
                            <div className="value">{sensor.humidity?.toFixed(1) || 'N/A'}%</div>
                            <div className="label">Humidity</div>
                          </div>
                        </div>
                      </div>

                      <div className="reading-row">
                        <div className="sensor-value">
                          <span className="value-icon" style={{ color: '#FFC107' }}>💡</span>
                          <div>
                            <div className="value">{sensor.light_level?.toFixed(0) || 'N/A'} lux</div>
                            <div className="label">Light</div>
                          </div>
                        </div>
                        <div className="sensor-value">
                          <span className="value-icon" style={{ color: sensor.motion_detected ? '#FF9800' : '#9E9E9E' }}>🚶</span>
                          <div>
                            <div className="value">{sensor.motion_detected ? 'Detected' : 'None'}</div>
                            <div className="label">Motion</div>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="sensor-footer">
                      <span className="last-reading">
                        Last Update: {formatDateTime(sensor.recorded_at)}
                      </span>
                      {sensor.energy_usage && (
                        <span className="energy-usage">
                          ⚡ {sensor.energy_usage.toFixed(1)}W
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Enhanced Stats Boxes */}
          <div className="stats-section">
            <h2>Infrastructure Overview</h2>
            <div className="stats-boxes">
              <div className="stat-box">
                <div className="stat-icon">🏫</div>
                <div className="stat-info">
                  <p className="stat-number">{rooms.length}</p>
                  <p className="stat-label">Total Rooms</p>
                </div>
              </div>
              <div className="stat-box">
                <div className="stat-icon">📚</div>
                <div className="stat-info">
                  <p className="stat-number">
                    {rooms.filter((r) => r.type === "Classroom").length}
                  </p>
                  <p className="stat-label">Classrooms</p>
                </div>
              </div>
              <div className="stat-box">
                <div className="stat-icon">👔</div>
                <div className="stat-info">
                  <p className="stat-number">
                    {rooms.filter((r) => r.type === "Office").length}
                  </p>
                  <p className="stat-label">Offices</p>
                </div>
              </div>
              <div className="stat-box">
                <div className="stat-icon">🔬</div>
                <div className="stat-info">
                  <p className="stat-number">
                    {rooms.filter((r) => r.type === "Lab").length}
                  </p>
                  <p className="stat-label">Labs</p>
                </div>
              </div>
              <div className="stat-box">
                <div className="stat-icon">📡</div>
                <div className="stat-info">
                  <p className="stat-number">{sensorData.length}</p>
                  <p className="stat-label">ESP32 Devices</p>
                </div>
              </div>
              <div className="stat-box">
                <div className="stat-icon">🟢</div>
                <div className="stat-info">
                  <p className="stat-number">{onlineEquipment}</p>
                  <p className="stat-label">Online Sensors</p>
                </div>
              </div>
            </div>
          </div>

          {/* Rooms Management Section */}
          <div className="rooms-section">
            <h2>Room Management</h2>
            
            {/* Table Controls */}
            <div className="table-controls">
              <input
                type="text"
                placeholder="Search rooms..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            {/* Rooms Table */}
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Floor</th>
                  <th>Capacity</th>
                  <th>Type</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedRooms.map((room) => (
                  <tr key={room.id}>
                    <td>{room.name}</td>
                    <td>{room.floor}</td>
                    <td>{room.capacity}</td>
                    <td>{room.type}</td>
                    <td>
                      <button
                        className="edt-btn"
                        onClick={() => {
                          setModalMode("edit");
                          setSelectedRoom(room);
                        }}
                      >
                        Edit
                      </button>
                      <button
                        className="dlt-btn"
                        onClick={() => {
                          setModalMode("delete");
                          setSelectedRoom(room);
                        }}
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
                {paginatedRooms.length === 0 && (
                  <tr>
                    <td colSpan={5}>No rooms found</td>
                  </tr>
                )}
              </tbody>
            </table>

            {/* Add Room Button */}
            <button
              className="add-btn-main"
              onClick={() => {
                setModalMode("add");
                setSelectedRoom(undefined);
              }}
            >
              + Add Room
            </button>

            {/* Pagination */}
            <Pagination
              currentPage={currentPage}
              totalPages={totalPages}
              onPageChange={setCurrentPage}
              showRange
            />
          </div>

          {/* Room Modal */}
          {modalMode && (
            <RoomModal
              mode={modalMode}
              room={selectedRoom}
              onClose={() => {
                setModalMode(null);
                setSelectedRoom(undefined);
              }}
              onSubmit={handleSubmit}
            />
          )}
        </div>
=======
        <button
          className="add-btn-main"
          onClick={() => {
            setModalMode("add");
            setSelectedRoom(undefined);
          }}
        >
          + Add Room
        </button>

        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          onPageChange={setCurrentPage}
          showRange
        />

        {modalMode && (
          <RoomModal
            mode={modalMode}
            room={selectedRoom}
            onClose={() => {
              setModalMode(null);
              setSelectedRoom(undefined);
            }}
            onSubmit={handleSubmit}
          />
        )}
>>>>>>> web-only
      </div>
    </PageLayout>
  );
};

export default DashboardScreen;