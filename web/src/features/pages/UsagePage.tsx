import React, { useEffect, useState, useMemo } from "react";
import PageLayout from "./PageLayout";
import { roomService } from "../services/roomService";
import { equipmentService } from "../services/equipmentService";
import { componentService } from "../services/componentService";
import { sensorService } from "../services/sensorService";
import type { Room, Equipment } from "../types/dashboardTypes";
import type { Component } from "../types/componentTypes";
import type { SensorData } from "../types/sensorLogTypes";
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

export interface RoomAnalyticsItem {
  period_start: string;
  period_end: string;
  period_type: string;
  total_energy: number;
  avg_power: number;
  peak_power: number;
  reading_count: number;
  anomaly_count: number;
  total_cost: number;
  currency?: string;
}

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

  // --- Fetch Components & Sensor Logs ---
  useEffect(() => {
    if (!selectedEquipment) {
      setComponents([]);
      setSensorLogs([]);
      setSelectedComponent("");
      return;
    }
    const fetchLogs = async () => {
      setLoading(true);
      try {
        const comps = await componentService.fetchByEquipment(selectedEquipment);
        const logs: SensorData[] = (
          await Promise.all(
            comps.map(async (comp) => {
              const reading = await sensorService.fetchLatestReading(comp.id);
              if (!reading) return null;
              return {
                device_id: comp.id,
                equipment_id: comp.equipment || selectedEquipment,
                equipment_name: reading.equipment_name || "Unknown Equipment",
                component_type: comp.component_type,
                status: reading.status,
                temperature: reading.temperature,
                humidity: reading.humidity,
                light_level: reading.light_level,
                energy_usage: reading.energy_usage,
                recorded_at: reading.recorded_at ?? null,
                component_name: comp.identifier || comp.component_type, // ✅ Name for HVAC logs
              } as SensorData;
            })
          )
        ).filter((l): l is SensorData => l !== null);

        setComponents(comps);
        setSensorLogs(logs);
        setSelectedComponent("");
      } catch (err) {
        console.error("❌ Failed to load sensor logs:", err);
        setComponents([]);
        setSensorLogs([]);
        setSelectedComponent("");
      } finally {
        setLoading(false);
      }
    };
    fetchLogs();
  }, [selectedEquipment]);

  // --- Fetch Analytics (Equipment Energy Summaries) ---
  useEffect(() => {
    setAnalytics([]);
    setAvailablePeriods([]);
    setSelectedPeriodIndex(null);
    if (!selectedRoom) return;

    roomService
      .getEnergySummary(selectedRoom, periodType)
      .then((data) => {
        if (data.length) {
          setAvailablePeriods(data);
          setSelectedPeriodIndex(0);
        }
      })
      .catch(console.error);
  }, [selectedRoom, periodType]);

  useEffect(() => {
    if (!selectedRoom || selectedPeriodIndex === null || !availablePeriods[selectedPeriodIndex]) {
      setAnalytics([]);
      return;
    }

    const period = availablePeriods[selectedPeriodIndex];
    const periodString = `${period.period_start} → ${period.period_end}`;

    setLoading(true);
    roomService
      .getEnergySummary(selectedRoom, periodType, periodString)
      .then((res: RoomAnalyticsItem[]) => {
        const sorted = res
          .sort((a, b) => new Date(a.period_start).getTime() - new Date(b.period_start).getTime())
          .filter((i) => i.reading_count > 0 || i.total_energy > 0 || i.total_cost > 0);
        setAnalytics(sorted);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [selectedRoom, periodType, selectedPeriodIndex, availablePeriods]);

  // --- Equipment Chart (from analytics) ---
  const equipmentChartData = useMemo(() => {
    if (!analytics.length) return null;
    const labels: string[] = [];
    const dataPoints: number[] = [];

    analytics.forEach((item) => {
      const totalEnergy = item.total_energy || 0;
      switch (periodType) {
        case "daily":
          const per2Hour = totalEnergy / 12;
          for (let h = 0; h < 24; h += 2) {
            labels.push(`${h}:00`);
            dataPoints.push(per2Hour);
          }
          break;
        case "weekly":
          const perDay = totalEnergy / 7;
          for (let d = 0; d < 7; d++) {
            const date = new Date(item.period_start);
            date.setDate(date.getDate() + d);
            labels.push(`${date.getDate()}/${date.getMonth() + 1}`);
            dataPoints.push(perDay);
          }
          break;
        case "monthly":
          const perWeek = totalEnergy / 4;
          for (let w = 0; w < 4; w++) {
            const date = new Date(item.period_start);
            date.setDate(date.getDate() + w * 7);
            labels.push(`Week ${w + 1}: ${date.getDate()}/${date.getMonth() + 1}`);
            dataPoints.push(perWeek);
          }
          break;
      }
    });

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

  // --- Component Chart (from sensorLogs) ---
  const componentChartData = useMemo(() => {
    if (!sensorLogs.length || !selectedComponent) return null;

    const filtered = sensorLogs.filter((l) => l.device_id === selectedComponent);
    if (!filtered.length) return null;

    const now = new Date();
    let start = new Date();
    switch (periodType) {
      case "daily":
        start.setHours(now.getHours() - 24);
        break;
      case "weekly":
        start.setDate(now.getDate() - 7);
        break;
      case "monthly":
        start.setDate(now.getDate() - 30);
        break;
    }

    const startMs = start.getTime();
    const endMs = now.getTime();
    const binSizeMs =
      periodType === "daily"
        ? 2 * 60 * 60 * 1000
        : periodType === "weekly"
        ? 24 * 60 * 60 * 1000
        : 7 * 24 * 60 * 60 * 1000;

    const totalBins = Math.ceil((endMs - startMs) / binSizeMs);
    const bins: Record<number, number[]> = {};
    for (let i = 0; i < totalBins; i++) bins[startMs + i * binSizeMs] = [];

    filtered.forEach((log) => {
      if (!log.recorded_at) return;
      const t = new Date(log.recorded_at).getTime();
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
        const maxEnergy = values.length ? Math.max(...values) : 0;
        const mid = k + binSizeMs / 2;
        const label =
          periodType === "daily"
            ? new Date(mid).getHours() + ":00"
            : periodType === "weekly"
            ? `${new Date(mid).getDate()}/${new Date(mid).getMonth() + 1}`
            : `Week ${Math.floor((mid - startMs) / binSizeMs) + 1}`;
        labels.push(label);
        dataPoints.push(Number(maxEnergy.toFixed(2)));
      });

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
  }, [sensorLogs, selectedComponent, periodType]);

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: true, position: "top" as const, labels: { color: "#fff" } } },
    scales: { x: { ticks: { color: "#ccc" } }, y: { ticks: { color: "#ccc" }, beginAtZero: true } },
  };

  return (
    <PageLayout initialSection={{ parent: "Analytics" }}>
      {/* Filters */}
      <div className="usage-header flex justify-between items-center mb-6 gap-2">
        <div>
          <h2 className="text-xl font-semibold">Room Analytics</h2>
          <p className="text-gray-400 text-sm">Monitor room energy usage and HVAC data</p>
        </div>
        <div className="flex items-center gap-2">
          <select value={selectedRoom} onChange={(e) => setSelectedRoom(e.target.value)} className="bg-gray-800 text-white border border-gray-600 rounded-md px-3 py-1 text-sm">
            <option value="">Select Room</option>
            {rooms.map((r) => (<option key={r.id} value={r.id}>{r.name}</option>))}
          </select>

          <select value={selectedEquipment} onChange={(e) => setSelectedEquipment(e.target.value)} disabled={!equipments.length} className="bg-gray-800 text-white border border-gray-600 rounded-md px-3 py-1 text-sm">
            <option value="">Select Equipment</option>
            {equipments.map((eq) => (<option key={eq.id} value={eq.id}>{eq.name}</option>))}
          </select>

          <select value={selectedComponent} onChange={(e) => setSelectedComponent(e.target.value)} disabled={!components.length} className="bg-gray-800 text-white border border-gray-600 rounded-md px-3 py-1 text-sm">
            <option value="">Select Component</option>
            {components.map((c) => (<option key={c.id} value={c.id}>{c.identifier || c.component_type}</option>))}
          </select>

          <select value={periodType} onChange={(e) => setPeriodType(e.target.value as any)} className="bg-gray-800 text-white border border-gray-600 rounded-md px-3 py-1 text-sm">
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
          </select>
        </div>
      </div>

      {/* Equipment Chart */}
      {selectedEquipment && equipmentChartData && (
        <div className="usage-chart-container mb-6">
          <h3 className="text-lg font-semibold mb-2">Equipment Energy</h3>
          <Line data={equipmentChartData} options={chartOptions} />
        </div>
      )}

      {/* Component Chart */}
      {componentChartData && (
        <div className="usage-chart-container mb-6">
          <h3 className="text-lg font-semibold mb-2">Component Energy</h3>
          <Line data={componentChartData} options={chartOptions} />
        </div>
      )}

      {/* HVAC Logs */}
      {selectedComponent && sensorLogs.length > 0 && (
        <div className="hvac-logs">
          <h2>HVAC Sensor Logs</h2>
          <div className="hvac-logs-grid">
            {sensorLogs.filter((l) => l.device_id === selectedComponent).map((log) => (
              <div key={log.device_id + log.recorded_at} className="hvac-card">
                <p><strong>Status:</strong> {log.status}</p>
                <p><strong>Temperature:</strong> {log.temperature ?? "N/A"} °C</p>
                <p><strong>Humidity:</strong> {log.humidity ?? "N/A"} %</p>
                <p><strong>Light Level:</strong> {log.light_level ?? "N/A"}</p>
                <p><strong>Energy Usage:</strong> {log.energy_usage ?? "N/A"} kWh</p>
                <p><strong>Recorded At:</strong> {log.recorded_at ? new Date(log.recorded_at).toLocaleString() : "N/A"}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </PageLayout>
  );
};

export default UsagePage;
