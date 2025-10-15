import React, { useEffect, useState, useMemo } from "react";
import PageLayout from "./PageLayout";
import { roomService } from "../services/roomService";
import { equipmentService } from "../services/equipmentService";
import { componentService } from "../services/componentService";
import { sensorService } from "../services/sensorService";
import type { Room, Equipment } from "../types/dashboardTypes";
import type { Component } from "../types/componentTypes";
import type { SensorData } from "../types/sensorLogTypes";
import type { RoomAnalyticsItem } from "../types/usageTypes";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Tooltip,
  Filler,
  Legend,
  Title,
} from "chart.js";
import "../pages/PageStyle.css";

ChartJS.register(LineElement, PointElement, CategoryScale, LinearScale, Tooltip, Filler, Legend, Title);

const UsagePage: React.FC = () => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [equipments, setEquipments] = useState<Equipment[]>([]);
  const [components, setComponents] = useState<Component[]>([]);
  const [sensorLogs, setSensorLogs] = useState<SensorData[]>([]);
  const [analytics, setAnalytics] = useState<RoomAnalyticsItem[]>([]);
  const [availablePeriods, setAvailablePeriods] = useState<RoomAnalyticsItem[]>([]);
  const [loading, setLoading] = useState(false);

  const [selectedRoom, setSelectedRoom] = useState<string>("");
  const [selectedEquipment, setSelectedEquipment] = useState<string>("");
  const [selectedComponent, setSelectedComponent] = useState<string>("");
  const [periodType, setPeriodType] = useState<"daily" | "weekly" | "monthly">("daily");
  const [selectedPeriodIndex, setSelectedPeriodIndex] = useState<number | null>(null);

  const formatPeriodLabel = (period: RoomAnalyticsItem) => {
    const startDate = new Date(period.period_start);
    const endDate = new Date(period.period_end);

    switch (periodType) {
      case "daily":
        return startDate.toLocaleDateString("en-US", {
          month: "long",
          day: "numeric",
          year: "numeric",
        });
      case "weekly":
        const startStr = startDate.toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
        });
        const endStr = endDate.toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
        });
        return `${startStr} → ${endStr}`;
      case "monthly":
        return startDate.toLocaleDateString("en-US", {
          month: "long",
          year: "numeric",
        });
      default:
        return `${period.period_start} → ${period.period_end}`;
    }
  };

  // --- Fetch Rooms ---
  useEffect(() => {
    roomService.getAll().then(setRooms).catch(console.error);
  }, []);

  // --- Fetch Equipments ---
  useEffect(() => {
    if (!selectedRoom) {
      setEquipments([]);
      setComponents([]);
      setSensorLogs([]);
      setSelectedEquipment("");
      return;
    }
    setLoading(true);
    equipmentService
      .getAll()
      .then((list) => list.filter((eq) => eq.room === selectedRoom))
      .then(setEquipments)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [selectedRoom]);

  // --- Fetch Components ---
  useEffect(() => {
    if (!selectedEquipment) {
      setComponents([]);
      setSensorLogs([]);
      setSelectedComponent("");
      return;
    }
    setLoading(true);
    componentService
      .fetchByEquipment(selectedEquipment)
      .then((comps) => {
        console.log('🔍 Fetched Components for Equipment ID', selectedEquipment, ':', comps);
        setComponents(comps);
        setSelectedComponent("");
      })
      .catch((err) => {
        console.error("❌ Failed to load components:", err);
        setComponents([]);
        setSelectedComponent("");
      })
      .finally(() => setLoading(false));
  }, [selectedEquipment]);

  // --- Fetch Historical Sensor Logs for Selected Component ---
  useEffect(() => {
    if (!selectedComponent || !selectedEquipment) {
      setSensorLogs([]);
      return;
    }
    const fetchComponentLogs = async () => {
      setLoading(true);
      try {
        const comp = components.find((c) => c.id === selectedComponent);
        if (!comp) {
          setSensorLogs([]);
          return;
        }
        const logsForComp = await sensorService.fetchAllLogs(comp.id);
        console.log(`🔍 Historical Logs for Component ID ${comp.id}:`, logsForComp.length, 'entries');
        
        // Filter out logs without recorded_at to avoid sort errors
        const validLogsForComp = logsForComp.filter((log): log is SensorData & { recorded_at: string } => !!log.recorded_at);
        
        // Augment each log with component/equipment info (for consistency)
        const augmentedLogs = validLogsForComp.map((log) => {
          const rawLog = log as any; // Type assertion for backend fields not in SensorData
          const lightDetected = rawLog.light_detected;
          const motionDetected = rawLog.motion_detected;
          return {
            ...log,
            device_id: comp.id,
            equipment_id: comp.equipment || selectedEquipment,
            equipment_name: log.equipment_name || "Unknown Equipment", // Assume service joins this; else fetch separately
            component_type: comp.component_type,
            component_name: comp.identifier || comp.component_type,
            status: rawLog.reset_flag ? "Reset" : ((rawLog.energy_usage ?? 0) > 0 ? "Active" : "Idle"), // Derive status with nullish coalescing
            light_level: lightDetected !== undefined ? !!lightDetected : null,
            motion_detect: motionDetected !== undefined ? !!motionDetected : null,
          } as SensorData;
        });
        
        // Sort all logs chronologically (now safe since filtered)
        const sortedLogs = augmentedLogs.sort((a, b) => new Date(a.recorded_at!).getTime() - new Date(b.recorded_at!).getTime());
        console.log('🔍 Sorted Sensor Logs for Component:', sortedLogs.length, 'entries');
        
        setSensorLogs(sortedLogs);
      } catch (err) {
        console.error("❌ Failed to load historical sensor logs for component:", err);
        setSensorLogs([]);
      } finally {
        setLoading(false);
      }
    };
    fetchComponentLogs();
  }, [selectedComponent]);

  // --- Log Filtered HVAC Logs on Component Change ---
  useEffect(() => {
    if (selectedComponent && sensorLogs.length > 0) {
      const filteredLogs = sensorLogs.filter((l) => l.device_id === selectedComponent);
      console.log('🔍 Filtered HVAC Logs for Selected Component', selectedComponent, ':', filteredLogs.length, 'entries');
    }
  }, [selectedComponent, sensorLogs]);

  // --- Fetch Available Periods (Summaries) ---
  useEffect(() => {
    console.log('🔄 Fetching periods triggered for room:', selectedRoom, 'periodType:', periodType);
    setAnalytics([]);
    setAvailablePeriods([]);
    setSelectedPeriodIndex(null);
    if (!selectedRoom) return;

    roomService
      .getEnergySummary(selectedRoom, periodType)
      .then((data) => {
        console.log('📥 Raw periods data:', data);
        if (data.length) {
          const sortedData = data.sort((a, b) => new Date(a.period_start).getTime() - new Date(b.period_start).getTime());
          console.log('📊 Sorted periods:', sortedData.map(p => ({ start: p.period_start, label: formatPeriodLabel(p) })));
          setAvailablePeriods(sortedData);
          setSelectedPeriodIndex(null); // Default to latest period
          console.log('✅ Set index to latest after fetch');
        } else {
          console.log('⚠️ No periods data returned');
        }
      })
      .catch((err) => {
        console.error('❌ Fetch periods error:', err);
      });
  }, [selectedRoom, periodType]);

  // Log changes to selectedPeriodIndex
  useEffect(() => {
    console.log('📍 Current selectedPeriodIndex:', selectedPeriodIndex);
    console.log('📍 Available periods length:', availablePeriods.length);
    if (selectedPeriodIndex !== null && availablePeriods[selectedPeriodIndex]) {
      console.log('📍 Selected period details:', {
        index: selectedPeriodIndex,
        label: formatPeriodLabel(availablePeriods[selectedPeriodIndex]),
        energy: availablePeriods[selectedPeriodIndex].total_energy
      });
    }
  }, [selectedPeriodIndex, availablePeriods]);

  // --- Set Analytics from Selected Period ---
  useEffect(() => {
    if (selectedPeriodIndex !== null && availablePeriods[selectedPeriodIndex]) {
      setAnalytics([availablePeriods[selectedPeriodIndex]]);
      console.log('🔄 Analytics set from selected period');
    } else {
      setAnalytics([]);
      console.log('🔄 Analytics cleared');
    }
  }, [selectedPeriodIndex, availablePeriods]);

  // Helper: Get start/end dates for period (syncs equipment & component views)
  const getPeriodDates = useMemo(() => {
    if (selectedPeriodIndex !== null && availablePeriods[selectedPeriodIndex]) {
      const period = availablePeriods[selectedPeriodIndex];
      return {
        start: new Date(period.period_start),
        end: new Date(period.period_end),
      };
    }
    // Fallback to recent window based on periodType
    const now = new Date();
    let start = new Date(now);
    switch (periodType) {
      case "daily": start.setHours(now.getHours() - 24); break;
      case "weekly": start.setDate(now.getDate() - 7); break;
      case "monthly": start.setDate(now.getDate() - 30); break;
    }
    return { start, end: now };
  }, [selectedPeriodIndex, availablePeriods, periodType]);

  // --- Equipment Chart (from analytics) ---
  const equipmentChartData = useMemo(() => {
    if (!analytics.length) return null;
    const item = analytics[0];
    const totalEnergy = item.total_energy || 0;
    const periodStart = new Date(item.period_start);
    const labels: string[] = [];
    const dataPoints: number[] = [];
    switch (periodType) {
      case "daily":
        const per2Hour = totalEnergy / 12;
        for (let h = 0; h < 24; h += 2) {
          labels.push(`${h.toString().padStart(2, '0')}:00`);
          dataPoints.push(per2Hour);
        }
        break;
      case "weekly":
        const perDay = totalEnergy / 7;
        for (let d = 0; d < 7; d++) {
          const date = new Date(periodStart);
          date.setDate(date.getDate() + d);
          labels.push(`${date.getDate()}/${date.getMonth() + 1}`);
          dataPoints.push(perDay);
        }
        break;
      case "monthly":
        const perWeek = totalEnergy / 4;
        for (let w = 0; w < 4; w++) {
          const date = new Date(periodStart);
          date.setDate(date.getDate() + w * 7);
          labels.push(`Week ${w + 1}: ${date.getDate()}/${date.getMonth() + 1}`);
          dataPoints.push(perWeek);
        }
        break;
    }
    console.log('📈 Equipment Chart data generated:', { labels: labels.slice(0, 3) + '...', totalPoints: dataPoints.length, totalEnergy });
    return {
      labels,
      datasets: [
        {
          label: "Equipment Energy (kWh)",
          data: dataPoints,
          fill: true,
          borderColor: "#4c6ef5",
          backgroundColor: "rgba(76, 110, 245, 0.15)",
          tension: 0.35,
          pointRadius: 2,
          pointBackgroundColor: "#4c6ef5",
        },
      ],
    };
  }, [analytics, periodType]);

  // --- Component Chart (from historical sensorLogs, synced to period) ---
  const componentChartData = useMemo(() => {
    if (!sensorLogs.length || !selectedComponent) return null;

    const filtered = sensorLogs.filter((l) => l.device_id === selectedComponent && l.recorded_at);
    console.log('📊 Filtered sensor logs for component', selectedComponent, ':', filtered.length, 'entries in period');
    if (!filtered.length) return null;

    const { start, end } = getPeriodDates;
    const startMs = start.getTime();
    const endMs = end.getTime();
    const binSizeMs =
      periodType === "daily"
        ? 2 * 60 * 60 * 1000  // 2h bins
        : periodType === "weekly"
        ? 24 * 60 * 60 * 1000  // Daily bins
        : 7 * 24 * 60 * 60 * 1000;  // Weekly bins

    const totalBins = Math.ceil((endMs - startMs) / binSizeMs);
    const bins: Record<number, number[]> = {};
    for (let i = 0; i < totalBins; i++) bins[startMs + i * binSizeMs] = [];

    filtered.forEach((log) => {
      const t = new Date(log.recorded_at!).getTime();
      if (t < startMs || t > endMs) return;
      const index = Math.floor((t - startMs) / binSizeMs);
      const key = startMs + index * binSizeMs;
      bins[key].push(log.energy_usage ?? 0);
    });

    const labels: string[] = [];
    const dataPoints: number[] = [];

    Object.keys(bins)
      .map(Number)
      .sort((a, b) => a - b)
      .forEach((k) => {
        const values = bins[k];
        // ✅ Sum for total energy per bin (better for usage trends)
        const totalEnergy = values.reduce((sum, val) => sum + val, 0);
        const mid = k + binSizeMs / 2;
        let label: string;
        if (periodType === "daily") {
          label = new Date(mid).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } else if (periodType === "weekly") {
          label = new Date(mid).toLocaleDateString("en-US", { month: "short", day: "numeric" });
        } else {
          label = `Week ${Math.floor((mid - startMs) / binSizeMs) + 1}`;
        }
        labels.push(label);
        dataPoints.push(Number(totalEnergy.toFixed(2)));
      });

    console.log('📈 Component Chart data generated:', { labels: labels.slice(0, 3) + '...', totalPoints: dataPoints.length, totalEnergy: dataPoints.reduce((a, b) => a + b, 0) });
    return {
      labels,
      datasets: [
        {
          label: "Component Energy (kWh)",
          data: dataPoints,
          fill: true,
          borderColor: "#f59f00",
          backgroundColor: "rgba(245, 159, 0, 0.15)",
          tension: 0.35,
          pointRadius: 2,
          pointBackgroundColor: "#f59f00",
        },
      ],
    };
  }, [sensorLogs, selectedComponent, periodType, getPeriodDates]);

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: true, position: "top" as const, labels: { color: "#fff" } } },
    scales: { x: { ticks: { color: "#ccc" } }, y: { ticks: { color: "#ccc" }, beginAtZero: true } },
  };

  // Filter logs for display (in period, most recent, with <3 N/A in relevant fields)
  const displayLogs = useMemo(() => {
    if (!selectedComponent || !sensorLogs.length) return [];
    const { start, end } = getPeriodDates;
    return sensorLogs
      .filter((l) => l.device_id === selectedComponent && l.recorded_at)
      .filter((l) => {
        const date = new Date(l.recorded_at!);
        return date >= start && date <= end;
      })
      .filter((log) => {
        const hasEnv = log.temperature !== null && log.humidity !== null;
        const hasOcc = log.light_level !== null && log.motion_detect !== null;
        let relevantFields: (keyof SensorData)[];
        if (hasEnv) {
          relevantFields = ['temperature', 'humidity', 'energy_usage'];
        } else if (hasOcc) {
          relevantFields = ['light_level', 'motion_detect', 'energy_usage'];
        } else {
          relevantFields = ['temperature', 'humidity', 'light_level', 'motion_detect', 'energy_usage'];
        }
        const naCount = relevantFields.filter((field) => log[field] == null).length;
        return naCount < 3;
      })
      .sort((a, b) => new Date(b.recorded_at!).getTime() - new Date(a.recorded_at!).getTime())
      .slice(0, 4);  // Most recent 4 valid logs
  }, [selectedComponent, sensorLogs, getPeriodDates]);

  return (
    <PageLayout initialSection={{ parent: "Analytics" }}>
      {/* Room Selection - On Top */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold text-white mb-2">Room Analytics</h2>
        <p className="text-gray-400 text-sm mb-4">Monitor room energy usage and HVAC data</p>
        <select 
          value={selectedRoom} 
          onChange={(e) => setSelectedRoom(e.target.value)} 
          className="dropdown-default"
        >
          <option value="">Select Room</option>
          {rooms.map((r) => (<option key={r.id} value={r.id}>{r.name}</option>))}
        </select>
      </div>

      {/* Equipment Section */}
      {selectedRoom && (
        <div className="mb-6">
          <h3 className="text-lg font-semibold text-white mb-2">Equipment Energy</h3>
          <div className="flex items-center gap-2 mb-4">
            <select 
              value={selectedEquipment} 
              onChange={(e) => setSelectedEquipment(e.target.value)} 
              disabled={!equipments.length} 
              className="dropdown-default"
            >
              <option value="">Select Equipment</option>
              {equipments.map((eq) => (<option key={eq.id} value={eq.id}>{eq.name}</option>))}
            </select>

            <select 
              value={periodType} 
              onChange={(e) => setPeriodType(e.target.value as any)} 
              className="dropdown-default"
            >
              <option value="daily">Daily</option>
              <option value="weekly">Weekly</option>
              <option value="monthly">Monthly</option>
            </select>

            <select
              value={selectedPeriodIndex ?? ""}
              onChange={(e) => {
                const val = e.target.value;
                const newIndex = val === "" ? null : Number(val);
                console.log('🎯 Period dropdown changed - raw e.target.value:', val, 'parsed index:', newIndex);
                console.log('🎯 Current availablePeriods before change:', availablePeriods.map((p, i) => ({ i, label: formatPeriodLabel(p) })));
                setSelectedPeriodIndex(newIndex);
              }}
              disabled={!availablePeriods.length}
              className="dropdown-default"
            >
              <option value="">Select Period</option>
              {availablePeriods.map((period, index) => (
                <option key={`period-${index}`} value={index}>
                  {formatPeriodLabel(period)}
                </option>
              ))}
            </select>
          </div>

          {/* Summary Cards for Selected Period */}
          {selectedPeriodIndex !== null && analytics.length > 0 && (
            <div className="summary-grid">
              <div className="summary-card">
                <p>Total Energy</p>
                <p>{analytics[0].total_energy.toFixed(3)} kWh</p>
              </div>
              <div className="summary-card">
                <p>Average Power</p>
                <p>{analytics[0].avg_power.toFixed(2)} kW</p>
              </div>
              <div className="summary-card">
                <p>Bill</p>
                <p>{analytics[0].total_cost.toFixed(3)} {analytics[0].currency || 'USD'}</p>
              </div>
            </div>
          )}

          {/* Equipment Chart */}
          {equipmentChartData ? (
            <div className="usage-chart-container">
              <Line data={equipmentChartData} options={chartOptions} />
            </div>
          ) : (
            <p className="text-gray-400">No equipment data for selected period</p>
          )}
        </div>
      )}

      {/* Component Section */}
      {selectedEquipment && (
        <div>
          <h3 className="text-lg font-semibold text-white mb-2">Component Details</h3>
          <div className="flex items-center gap-2 mb-4">
            <select 
              value={selectedComponent} 
              onChange={(e) => setSelectedComponent(e.target.value)} 
              disabled={!components.length} 
              className="dropdown-default"
            >
              <option value="">Select Component</option>
              {components.map((c) => (<option key={c.id} value={c.id}>{c.identifier || c.component_type}</option>))}
            </select>
          </div>

          {/* Component Chart */}
          {componentChartData ? (
            <div className="usage-chart-container mb-6">
              <h4 className="text-md font-semibold mb-2">Component Energy</h4>
              <Line data={componentChartData} options={chartOptions} />
            </div>
          ) : selectedComponent ? (
            <p className="text-gray-400 mb-6">No component data for selected period</p>
          ) : null}

          <br></br>
          <br></br>

          {/* HVAC Logs */}
          {selectedComponent && (
            <div className="hvac-logs">
              <h2 className="text-lg font-semibold mb-4">HVAC Sensor Logs ({displayLogs.length} recent in period)</h2>
              {displayLogs.length > 0 ? (
                <div className="hvac-logs-grid">
                  {displayLogs.map((log, index) => {
                    const hasEnv = log.temperature !== null && log.humidity !== null;
                    const hasOcc = log.light_level !== null && log.motion_detect !== null;
                    const showEnvFields = hasEnv || !hasOcc;
                    const showOccFields = hasOcc || !hasEnv;
                    return (
                      <div key={log.device_id || `${log.device_id}-${log.recorded_at}-${index}`} className="hvac-card">
                        <p><strong>Name:</strong> {log.component_name}</p>
                        <p><strong>Status:</strong> {log.status ?? "Unknown"}</p>
                        {showEnvFields && log.temperature !== null && <p><strong>Temperature:</strong> {log.temperature} °C</p>}
                        {showEnvFields && log.humidity !== null && <p><strong>Humidity:</strong> {log.humidity} %</p>}
                        {showOccFields && log.light_level !== null && <p><strong>Light Level:</strong> {log.light_level ? 'True' : 'False'}</p>}
                        {showOccFields && log.motion_detect !== null && <p><strong>Motion Detection:</strong> {log.motion_detect ? 'True' : 'False'}</p>}
                        {log.energy_usage !== null && <p><strong>Energy Usage:</strong> {log.energy_usage} kWh</p>}
                        <p><strong>Recorded At:</strong> {log.recorded_at ? new Date(log.recorded_at).toLocaleString() : "N/A"}</p>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <p className="text-gray-400">No logs for this component in the selected period</p>
              )}
            </div>
          )}
        </div>
      )}

      {loading && <p className="text-white">Loading...</p>}
    </PageLayout>
  );
};

export default UsagePage;