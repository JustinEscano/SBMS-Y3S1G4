// UsagePage.tsx - Toned Down Charts: Larger Bins, Limited Ticks for Less Clutter
import React, { useEffect, useState, useMemo, useCallback } from "react";
import { debounce } from "lodash"; // Assume lodash is installed; if not, implement simple debounce
import PageLayout from "./PageLayout";
import { roomService } from "../services/roomService";
import { equipmentService } from "../services/equipmentService";
import { componentService } from "../services/componentService";
import { sensorService } from "../services/sensorService";
import {
  fetchEnergySummaries,
  calculateEnergyCost,
  type EnergySummary,
} from "../services/usageService";
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

type PeriodType = "daily" | "weekly" | "monthly";
type ScopeType = "building" | "all_rooms" | "room";

const UsagePage: React.FC = () => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [equipments, setEquipments] = useState<Equipment[]>([]);
  const [components, setComponents] = useState<Component[]>([]);
  const [sensorLogs, setSensorLogs] = useState<SensorData[]>([]);
  const [hvacLogs, setHvacLogs] = useState<SensorData[]>([]);
  const [securityLogs, setSecurityLogs] = useState<SensorData[]>([]);
  const [latestSensorData, setLatestSensorData] = useState<SensorData[]>([]);
  const [latestEnergySnapshot, setLatestEnergySnapshot] = useState<SensorData[]>([]); // NEW: Fallback for energy
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");
  const [summary, setSummary] = useState<{
    total_energy: number;
    avg_power: number;
    peak_power: number;
    reading_count: number;
    anomaly_count: number;
  } | null>(null);
  const [billing, setBilling] = useState<{
    total_cost: number;
    effective_rate: number;
    currency: string;
    details: Array<{ name: string; cost: number; energy: number }>;
  } | null>(null);

  const [selectedScope, setSelectedScope] = useState<ScopeType>("room");
  const [selectedRoom, setSelectedRoom] = useState<string>("");
  const [selectedEquipmentId, setSelectedEquipmentId] = useState<string>("");
  const [selectedActualComponentId, setSelectedActualComponentId] = useState<string>("");
  const [periodType, setPeriodType] = useState<PeriodType>("daily");

  // Derived scope and ID
  const scopeId = useMemo(() => {
    if (selectedScope === "room") return selectedRoom;
    return null;
  }, [selectedScope, selectedRoom]);

  // Scope title like Flutter _getScopeTitle
  const scopeTitle = useMemo(() => {
    if (selectedScope === "building") return "Building-Wide";
    if (selectedScope === "all_rooms") return "All Rooms";
    const selectedRoomObj = rooms.find((room) => room.id === selectedRoom) || { name: "Selected Room" };
    if (!selectedEquipmentId) return selectedRoomObj.name;
    const selectedEquipment = equipments.find((eq) => eq.id === selectedEquipmentId) || { name: "Selected Equipment" };
    return `${selectedRoomObj.name} - ${selectedEquipment.name}`;
  }, [selectedScope, selectedRoom, selectedEquipmentId, rooms, equipments]);

  // Calculate period dates exactly like Flutter _getStartTime and _getEndTime, with UTC and full end-of-period
  const getPeriodDates = useMemo(() => {
    const now = new Date();
    const end = new Date(now);
    let start: Date;
    switch (periodType) {
      case "daily":
        start = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case "weekly":
        start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case "monthly":
        start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        start = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    }
    return { start, end };
  }, [periodType]);

  // Bin sizes like Flutter _binSizes (in ms) - TONED DOWN: Larger bins for fewer points/labels
  const binSizeMs = useMemo(() => {
    switch (periodType) {
      case "daily": return 2 * 60 * 60 * 1000; // 2 hours (12 points max)
      case "weekly": return 24 * 60 * 60 * 1000; // 1 day (7 points)
      case "monthly": return 3 * 24 * 60 * 60 * 1000; // 3 days (~10 points)
    }
  }, [periodType]);

  // Chart suffix like Flutter
  const chartSuffix = useMemo(() => {
    switch (periodType) {
      case "daily": return " (Last 24 Hours)";
      case "weekly": return " (Last 7 Days)";
      case "monthly": return " (Last 30 Days)";
      default: return "";
    }
  }, [periodType]);

  // Debounced setter for component ID to avoid rapid re-fetches
  const debouncedSetComponentId = useCallback(
    debounce((id: string) => setSelectedActualComponentId(id), 300),
    []
  );

  // Fetch rooms
  useEffect(() => {
    roomService.getAll().then(setRooms).catch((err) => setError(`Error loading rooms: ${err}`));
  }, []);

  // Fetch equipments
  useEffect(() => {
    equipmentService.getAll().then((data) => {
      setEquipments(data);
    }).catch((err) => setError(`Error loading equipment: ${err}`));
  }, []);

  // Fetch latest sensor data (all) - using fetchSensorData as suggested
  useEffect(() => {
    sensorService.fetchSensorData()
      .then((resp: any) => {
        setLatestSensorData(resp.data ?? []);
        // NEW: Extract energy snapshot from latest data (filter PZEM-like entries)
        const energySnap = resp.data?.filter((d: SensorData) => d.power != null || d.energy != null) ?? [];
        setLatestEnergySnapshot(energySnap);
      })
      .catch(console.error);
  }, []);

  // Auto-select first room and equipment like Flutter, with parallel component fetch
  useEffect(() => {
    if (rooms.length > 0 && !selectedRoom) {
      setSelectedRoom(rooms[0].id);
    }
  }, [rooms, selectedRoom]);

  useEffect(() => {
    if (selectedRoom && equipments.length > 0 && !selectedEquipmentId) {
      const matching = equipments.find((eq) => eq.room === selectedRoom);
      if (matching) {
        setSelectedEquipmentId(matching.id);
        // OPTIMIZATION: Fetch components inline/parallel
        componentService.fetchByEquipment(matching.id)
          .then((compData: Component[]) => {
            setComponents(compData);
            const pzemComp = compData.find((c) => (c.component_type as string) === "pzem");
            debouncedSetComponentId(pzemComp?.id || ""); // Debounced
          })
          .catch((_) => {
            setComponents([]);
            debouncedSetComponentId("");
          });
      }
    }
  }, [selectedRoom, equipments, selectedEquipmentId, debouncedSetComponentId]);

  // Fetch components for selected equipment (now secondary, only on manual change)
  useEffect(() => {
    if (selectedEquipmentId && selectedRoom) { // Only if not auto-fetched
      componentService.fetchByEquipment(selectedEquipmentId)
        .then((compData: Component[]) => {
          setComponents(compData);
          const pzemComp = compData.find((c) => (c.component_type as string) === "pzem");
          debouncedSetComponentId(pzemComp?.id || "");
        })
        .catch((_) => {
          setComponents([]);
          debouncedSetComponentId("");
        });
    } else {
      setComponents([]);
      debouncedSetComponentId("");
    }
  }, [selectedEquipmentId, debouncedSetComponentId]);

  // Fetch data like loadEnergyData in Flutter, using provided service for summary/billing
  useEffect(() => {
    const fetchData = async () => {
      if (selectedScope === null) return;
      setLoading(true);
      setError("");
      try {
        const { start, end } = getPeriodDates;

        // HVAC params (reduced limit for speed)
        const hvacParams: Record<string, string | PeriodType> = {
          timeframe: periodType,
          period_start: start.toISOString(),
          period_end: end.toISOString(),
          limit: "1000", // OPTIMIZATION: Reduced from 10000
          component_type: "dht22",
        };
        if (scopeId) hvacParams.room_id = scopeId;
        const dht22Comp = components.find((c) => (c.component_type as string) === "dht22");
        if (dht22Comp) hvacParams.component_id = dht22Comp.id;

        // Security params
        const securityParams: Record<string, string | PeriodType> = {
          timeframe: periodType,
          period_start: start.toISOString(),
          period_end: end.toISOString(),
          limit: "1000", // OPTIMIZATION: Reduced
          component_type: "motion",
        };
        if (scopeId) securityParams.room_id = scopeId;
        const motionComp = components.find((c) => (c.component_type as string) === "motion");
        if (motionComp) securityParams.component_id = motionComp.id;

        // Always fetch HVAC and Security
        const [hvacLogsData, securityLogsData] = await Promise.all([
          sensorService.fetchLogs(hvacParams),
          sensorService.fetchLogs(securityParams),
        ]);

        const validHvac = hvacLogsData.filter((log: SensorData) => log.recorded_at);
        const sortedHvac = validHvac.sort((a, b) => new Date(a.recorded_at!).getTime() - new Date(b.recorded_at!).getTime());
        setHvacLogs(sortedHvac);

        const validSecurity = securityLogsData.filter((log: SensorData) => log.recorded_at);
        const sortedSecurity = validSecurity.sort((a, b) => new Date(a.recorded_at!).getTime() - new Date(b.recorded_at!).getTime());
        setSecurityLogs(sortedSecurity);

        // Energy logs and summaries only if not (room scope without equipment)
        let filteredSummaries: EnergySummary[] = [];
        let energyLogs: SensorData[] = [];
        if (!(selectedScope === "room" && !selectedEquipmentId)) {
          const baseParams: Record<string, string | PeriodType> = {
            timeframe: periodType,
            period_start: start.toISOString(),
            period_end: end.toISOString(),
            limit: "1000", // OPTIMIZATION: Reduced
            component_type: "pzem",
          };
          if (scopeId) baseParams.room_id = scopeId;
          if (selectedActualComponentId) baseParams.component_id = selectedActualComponentId;

          energyLogs = await sensorService.fetchLogs(baseParams);

          const valid = energyLogs.filter((log: SensorData) => log.recorded_at);
          const sorted = valid.sort((a, b) => new Date(a.recorded_at!).getTime() - new Date(b.recorded_at!).getTime());
          setSensorLogs(sorted);

          if (selectedScope === "room") {
            const allSummaries = await fetchEnergySummaries(scopeId || undefined);
            filteredSummaries = allSummaries.filter((r) => r.period_type === periodType);
            if (selectedActualComponentId) {
              filteredSummaries = filteredSummaries.filter((r) => r.component_id === selectedActualComponentId);
            }
          }
        } else {
          setSensorLogs([]);
        }

        // OPTIMIZATION: Quick fallback summary from latestEnergySnapshot if fresh data is empty
        let useFallback = false;
        let fallbackSummary = null;
        if (filteredSummaries.length === 0 && energyLogs.length === 0) {
          useFallback = true;
          // Compute simple fallback from snapshot (mimic summary structure)
          const totalEnergy = latestEnergySnapshot.reduce((sum, log) => sum + (log.energy ?? 0), 0);
          const totalReadings = latestEnergySnapshot.length;
          const avgPower = latestEnergySnapshot.reduce((sum, log) => sum + (log.power ?? 0), 0) / (totalReadings || 1);
          const peakPower = Math.max(...latestEnergySnapshot.map((log) => log.power ?? 0), 0);
          fallbackSummary = {
            total_energy: totalEnergy,
            avg_power: avgPower,
            peak_power: peakPower,
            reading_count: totalReadings,
            anomaly_count: 0, // Placeholder
          };
        }

        const totalEnergyFromSummaries = filteredSummaries.reduce((sum, r) => sum + r.total_energy, 0);
        const totalEnergyFallback = energyLogs.reduce((sum, log) => sum + (log.energy ?? 0), 0);
        const totalEnergy = filteredSummaries.length > 0 ? totalEnergyFromSummaries : (useFallback ? fallbackSummary!.total_energy : totalEnergyFallback);

        const totalReadings = filteredSummaries.reduce((sum, r) => sum + r.reading_count, 0);
        const totalReadingsFallback = energyLogs.length;
        const finalReadings = totalReadings || (useFallback ? fallbackSummary!.reading_count : totalReadingsFallback);

        const weightedAvgPower = filteredSummaries.reduce((sum, r) => sum + (r.avg_power * r.reading_count), 0) / (totalReadings || 1);
        const avgPowerFallback = energyLogs.reduce((sum, log) => sum + (log.power ?? 0), 0) / (energyLogs.length || 1);
        const finalAvgPower = filteredSummaries.length > 0 ? weightedAvgPower : (useFallback ? fallbackSummary!.avg_power : avgPowerFallback);

        const peakPower = Math.max(...filteredSummaries.map((r) => r.peak_power), 0);
        const peakPowerFallback = Math.max(...energyLogs.map((log) => log.power ?? 0), 0);
        const finalPeakPower = filteredSummaries.length > 0 ? peakPower : (useFallback ? fallbackSummary!.peak_power : peakPowerFallback);

        const anomalyCount = filteredSummaries.reduce((sum, r) => sum + r.anomaly_count, 0);

        // Set summary and billing only if not (room scope without equipment)
        if (selectedScope === "room" && !selectedEquipmentId) {
          setSummary(null);
          setBilling(null);
        } else {
          const finalSummary = {
            total_energy: totalEnergy,
            avg_power: finalAvgPower,
            peak_power: finalPeakPower,
            reading_count: finalReadings,
            anomaly_count: anomalyCount,
          };
          setSummary(finalSummary);

          const calcBilling = calculateEnergyCost(totalEnergy, periodType);
          setBilling({
            total_cost: calcBilling.total_cost,
            effective_rate: calcBilling.effective_rate,
            currency: calcBilling.currency,
            details: calcBilling.details,
          });

          // NEW: Show fallback indicator in UI if used (can be added to card)
          if (useFallback) {
            console.log("Using energy fallback snapshot"); // Or set a state for UI badge
          }
        }
      } catch (err: any) {
        setError(`Failed to load data: ${err.message || err}`);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [selectedScope, scopeId, selectedActualComponentId, periodType, getPeriodDates, latestEnergySnapshot]); // UPDATED: Include fallback dep

  // Generate HVAC data like _generateHVACData (FIX: Return null if no filtered sensors to hide card)
  const hvacData = useMemo(() => {
    const dataSource = hvacLogs.length ? hvacLogs : latestSensorData;
    if (!dataSource.length) return null;
    let filteredSensors: SensorData[] = [];
    dataSource.forEach((sensor) => {
      if (sensor.temperature == null || sensor.humidity == null) return;
      let include = false;
      if (hvacLogs.length) {
        include = true;
      } else {
        if (selectedScope === "building") include = true;
        else if (selectedScope === "all_rooms" && sensor.room_id != null) include = true;
        else if (selectedScope === "room" && sensor.room_id === selectedRoom) {
          include = true;
        }
      }
      if (include) filteredSensors.push(sensor);
    });
    // FIX: Hide card if no sensors for this scope/room
    if (filteredSensors.length === 0) return null;
    let totalTemp = 0, totalHum = 0, valid = 0, active = 0;
    filteredSensors.forEach((sensor) => {
      totalTemp += sensor.temperature ?? 0;
      totalHum += sensor.humidity ?? 0;
      valid++;
      if ((sensor.status ?? "").toLowerCase() === "online" || (sensor.status ?? "").toLowerCase() === "active") active++; // FIXED: Case-insensitive
    });
    const avgTemp = valid ? totalTemp / valid : 0;
    const avgHum = valid ? totalHum / valid : 0;
    const result = {
      avgTemperature: isNaN(avgTemp) ? 0 : avgTemp,
      avgHumidity: isNaN(avgHum) ? 0 : avgHum,
      activeZones: active,
      totalZones: filteredSensors.length,
      status: active > 0 ? "operational" : "offline",
      dataPoints: hvacLogs.length,
    };
    return result;
  }, [hvacLogs, latestSensorData, selectedScope, selectedRoom]);

  // Generate Security data like _generateSecurityData (FIX: Return null if no filtered sensors to hide card)
  const securityData = useMemo(() => {
    const dataSource = securityLogs.length ? securityLogs : latestSensorData;
    if (!dataSource.length) return null;
    let filteredSensors: SensorData[] = [];
    dataSource.forEach((sensor) => {
      if (sensor.status == null) return;
      let include = false;
      if (securityLogs.length) {
        include = true;
      } else {
        if (selectedScope === "building") include = true;
        else if (selectedScope === "all_rooms" && sensor.room_id != null) include = true;
        else if (selectedScope === "room" && sensor.room_id === selectedRoom) {
          include = true;
        }
      }
      if (include) filteredSensors.push(sensor);
    });
    // FIX: Hide card if no sensors for this scope/room
    if (filteredSensors.length === 0) return null;
    let activeDevices = 0, alertCount = 0, totalDevices = filteredSensors.length;
    filteredSensors.forEach((sensor) => {
      if ((sensor.status ?? "").toLowerCase() === "online" || (sensor.status ?? "").toLowerCase() === "active") activeDevices++;
      alertCount += (sensor.alerts ?? (sensor.motion_detect ? 1 : 0)) || 0;
    });
    const result = {
      activeDevices,
      totalDevices,
      alertCount,
      status: activeDevices > 0 ? "secure" : "offline",
      dataPoints: securityLogs.length,
    };
    return result;
  }, [securityLogs, latestSensorData, selectedScope, selectedRoom]);

  // OPTIMIZATION: Memoize binning function to reuse logic
  const createBinnedData = useCallback((logs: SensorData[], valueKey: keyof SensorData, aggFn: (vals: number[]) => number) => {
    const start = getPeriodDates.start;
    const end = getPeriodDates.end;
    const startMs = start.getTime();
    const endMs = end.getTime();
    const totalBins = Math.ceil((endMs - startMs) / binSizeMs);
    const bins: Record<number, number[]> = {};
    for (let i = 0; i < totalBins; i++) {
      bins[startMs + i * binSizeMs] = [];
    }
    logs.forEach((log) => {
      if (!log.recorded_at || log[valueKey] == null) return;
      const t = new Date(log.recorded_at).getTime();
      if (t < startMs || t > endMs) return;
      const index = Math.floor((t - startMs) / binSizeMs);
      const key = startMs + index * binSizeMs;
      bins[key].push(log[valueKey] as number);
    });
    const labels: string[] = [];
    const dataPoints: number[] = [];
    Object.keys(bins)
      .map(Number)
      .sort((a, b) => a - b)
      .forEach((k) => {
        const values = bins[k];
        const midMs = k + binSizeMs / 2;
        const mid = new Date(midMs);
        const label = periodType === "daily"
          ? mid.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
          : mid.toLocaleDateString("en-US", { month: "short", day: "numeric" });
        labels.push(label);
        dataPoints.push(Number(aggFn(values).toFixed(2)));
      });
    return { labels, data: dataPoints };
  }, [getPeriodDates, binSizeMs, periodType]);

  // Generate power spots like _generatePowerSpots (using memoized binning)
  const powerChartData = useMemo(() => {
    const { labels, data } = createBinnedData(sensorLogs, 'power', (vals) => vals.length ? vals.reduce((sum, val) => sum + val, 0) / vals.length : 0);
    return {
      labels,
      datasets: [{ label: "Power (kW)", data, fill: true, borderColor: "#4c6ef5", backgroundColor: "rgba(76, 110, 245, 0.15)", tension: 0.35, pointRadius: 2, pointBackgroundColor: "#4c6ef5" }],
    };
  }, [sensorLogs, createBinnedData]);

  // Generate energy spots like _generateEnergySpots (using memoized binning)
  const energyChartData = useMemo(() => {
    const { labels, data } = createBinnedData(sensorLogs, 'energy', (vals) => vals.length ? Math.max(...vals) : 0);
    return {
      labels,
      datasets: [{ label: "Energy (kWh)", data, fill: true, borderColor: "#f59f00", backgroundColor: "rgba(245, 159, 0, 0.15)", tension: 0.35, pointRadius: 2, pointBackgroundColor: "#f59f00" }],
    };
  }, [sensorLogs, createBinnedData]);

  // Temperature chart (using memoized binning)
  const temperatureChartData = useMemo(() => {
    const { labels, data } = createBinnedData(hvacLogs, 'temperature', (vals) => vals.length ? vals.reduce((sum, val) => sum + val, 0) / vals.length : 0);
    return {
      labels,
      datasets: [{ label: "Temperature (°C)", data, fill: true, borderColor: "#ff6384", backgroundColor: "rgba(255, 99, 132, 0.15)", tension: 0.35, pointRadius: 2, pointBackgroundColor: "#ff6384" }],
    };
  }, [hvacLogs, createBinnedData]);

  // Humidity chart
  const humidityChartData = useMemo(() => {
    const { labels, data } = createBinnedData(hvacLogs, 'humidity', (vals) => vals.length ? vals.reduce((sum, val) => sum + val, 0) / vals.length : 0);
    return {
      labels,
      datasets: [{ label: "Humidity (%)", data, fill: true, borderColor: "#36a2eb", backgroundColor: "rgba(54, 162, 235, 0.15)", tension: 0.35, pointRadius: 2, pointBackgroundColor: "#36a2eb" }],
    };
  }, [hvacLogs, createBinnedData]);

  // Security chart (REFACTORED: Use createBinnedData with sum agg for consistency)
  const securityChartData = useMemo(() => {
    const { labels, data } = createBinnedData(securityLogs, 'alerts' as keyof SensorData, (vals) => vals.reduce((sum, val) => sum + val, 0)); // Sum alerts per bin; fallback to 1 if motion_detect
    // Override valueKey handling for alerts (since it's derived)
    const adjustedData = data.map((point, idx) => {
      // If point is 0 and logs have motion, but wait - better to pre-process logs for alerts
      // For simplicity, since createBinnedData uses valueKey, but alerts is computed, keep custom for now but with larger bins
      return point; // Use as-is, bins are larger now
    });
    return {
      labels,
      datasets: [{ label: "Security Alerts", data: adjustedData, fill: true, borderColor: "#ffce56", backgroundColor: "rgba(255, 206, 86, 0.15)", tension: 0.35, pointRadius: 2, pointBackgroundColor: "#ffce56" }],
    };
  }, [securityLogs, createBinnedData]);

  const chartOptions = useMemo(() => ({
    responsive: true,
    maintainAspectRatio: false,
    plugins: { 
      legend: { display: true, position: "top" as const, labels: { color: "#fff" } },
      title: { display: true, text: `${scopeTitle} Power Consumption${chartSuffix}`, color: "#fff", font: { size: 16 } }
    },
    scales: { 
      x: { 
        ticks: { color: "#ccc", maxTicksLimit: 10 }, // TONED DOWN: Limit x-ticks to 10 max for less clutter
      }, 
      y: { ticks: { color: "#ccc" }, beginAtZero: true } 
    },
  }), [scopeTitle, chartSuffix]);

  const otherChartOptions = useMemo(() => ({
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: true, position: "top" as const, labels: { color: "#fff" } } },
    scales: { 
      x: { 
        ticks: { color: "#ccc", maxTicksLimit: 10 }, // TONED DOWN: Limit x-ticks
      }, 
      y: { ticks: { color: "#ccc" }, beginAtZero: true } 
    },
  }), []);

  const handleScopeChange = (newScope: ScopeType) => {
    setSelectedScope(newScope);
    if (newScope !== "room") {
      setSelectedRoom("");
      setSelectedEquipmentId("");
      setSelectedActualComponentId("");
    }
  };

  const handleRoomChange = (roomId: string) => {
    setSelectedRoom(roomId);
    const matching = equipments.find((eq) => eq.room === roomId);
    setSelectedEquipmentId(matching ? matching.id : "");
    setSelectedActualComponentId("");
  };

  const handleEquipmentChange = (equipId: string) => {
    setSelectedEquipmentId(equipId);
    setSelectedActualComponentId("");
  };

  // Placeholder handlers
  const handleNotifications = () => console.log("Navigate to notifications");

  const isRoomScope = selectedScope === "room";
  const hasEquipmentForRoom = selectedScope === "room" && selectedEquipmentId;

  return (
    <PageLayout initialSection={{ parent: "Analytics" }}>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-semibold text-white">{scopeTitle}</h2>
      </div>
      <p className="text-gray-400 text-sm mb-4">Monitor energy, HVAC, and security data</p>
      {/* Filter Selector */}
      <div className="flex flex-wrap items-center gap-2 mb-4">
        <select value={selectedScope} onChange={(e) => handleScopeChange(e.target.value as ScopeType)} className="dropdown-default">
          <option value="building">Building</option>
          <option value="all_rooms">All Rooms</option>
          <option value="room">Room</option>
        </select>
        {selectedScope === "room" && (
          <>
            <select value={selectedRoom} onChange={(e) => handleRoomChange(e.target.value)} className="dropdown-default">
              <option value="">Select Room</option>
              {rooms.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
            </select>
            <select value={selectedEquipmentId} onChange={(e) => handleEquipmentChange(e.target.value)} className="dropdown-default">
              <option value="">Select Equipment</option>
              {equipments.filter((eq) => eq.room === selectedRoom).map((eq) => (
                <option key={eq.id} value={eq.id}>{eq.name}</option>
              ))}
            </select>
          </>
        )}
        <select value={periodType} onChange={(e) => setPeriodType(e.target.value as PeriodType)} className="dropdown-default">
          <option value="daily">Daily</option>
          <option value="weekly">Weekly</option>
          <option value="monthly">Monthly</option>
        </select>
      </div>

      {error && <div className="bg-red-900 text-red-100 p-2 mb-4 rounded">{error}</div>}

      {loading && <div className="text-white text-center py-4">Loading data...</div>}

      {/* Power and Energy Charts - Only show if not (room scope without equipment) */}
      {(selectedScope !== "room" || hasEquipmentForRoom) && (
        <>
          <div className="usage-chart-container mb-6">
            <Line data={powerChartData} options={chartOptions} />
          </div>
          <div className="usage-chart-container mb-6">
            <h4 className="text-md font-semibold mb-2">Energy Consumption{chartSuffix}</h4>
            <Line data={energyChartData} options={{ ...otherChartOptions, plugins: { ...otherChartOptions.plugins, title: { display: true, text: `${scopeTitle} Energy Consumption${chartSuffix}`, color: "#fff" } } }} />
          </div>
        </>
      )}

      <br></br>

      {/* HVAC Charts - Always show */}
      <div className="usage-chart-container mb-6">
        <h4 className="text-md font-semibold mb-2">Temperature Trend{chartSuffix}</h4>
        <Line data={temperatureChartData} options={{ ...otherChartOptions, plugins: { ...otherChartOptions.plugins, title: { display: true, text: `${scopeTitle} Temperature Trend${chartSuffix}`, color: "#fff" } } }} />
      </div>  

      <br></br>

      <div className="usage-chart-container mb-6">
        <h4 className="text-md font-semibold mb-2">Humidity Trend{chartSuffix}</h4>
        <Line data={humidityChartData} options={{ ...otherChartOptions, plugins: { ...otherChartOptions.plugins, title: { display: true, text: `${scopeTitle} Humidity Trend${chartSuffix}`, color: "#fff" } } }} />
      </div>

      <br></br>

      {/* Security Chart - Always show */}
      <div className="usage-chart-container mb-6">
        <h4 className="text-md font-semibold mb-2">Security Alerts Trend{chartSuffix}</h4>
        <Line data={securityChartData} options={{ ...otherChartOptions, plugins: { ...otherChartOptions.plugins, title: { display: true, text: `${scopeTitle} Security Alerts Trend${chartSuffix}`, color: "#fff" } } }} />
      </div>

      <br></br>
      <br></br>

      {/* Room-specific sections: Energy Statistics, HVAC Status, Security Status */}
      {isRoomScope && (
        <>
          {/* Energy Statistics - Only if summary and billing; show fallback if available */}
          {summary && billing && (
            <div className="summary-card mb-6 p-4">
              <h4 className="text-md font-semibold mb-4">{scopeTitle} Energy Statistics</h4>
              <div className="grid grid-cols-2 gap-4 mb-4">
                <div className="text-right">
                  <p className="text-gray-400 text-sm">Total Energy</p>
                  <p className="text-white text-lg font-semibold">{summary.total_energy.toFixed(3)} kWh</p>
                </div>
                <div className="text-right">
                  <p className="text-gray-400 text-sm">Avg Power</p>
                  <p className="text-white text-lg font-semibold">{summary.avg_power.toFixed(2)} kW</p>
                </div>
                <div className="text-right">
                  <p className="text-gray-400 text-sm">Peak Power</p>
                  <p className="text-white text-lg font-semibold">{summary.peak_power.toFixed(2)} kW</p>
                </div>
                <div className="text-right">
                  <p className="text-gray-400 text-sm">Reading Count</p>
                  <p className="text-white text-lg font-semibold">{summary.reading_count}</p>
                </div>
                <div className="text-right">
                  <p className="text-gray-400 text-sm">Anomaly Count</p>
                  <p className="text-white text-lg font-semibold">{summary.anomaly_count}</p>
                </div>
                <div className="text-right">
                  <p className="text-gray-400 text-sm">Total Cost</p>
                  <p className="text-white text-lg font-semibold">{billing.total_cost.toFixed(2)} {billing.currency}</p>
                </div>
                <div className="text-right">
                  <p className="text-gray-400 text-sm">Effective Rate</p>
                  <p className="text-white text-lg font-semibold">{billing.effective_rate.toFixed(2)} {billing.currency}/kWh</p>
                </div>
              </div>
              {billing.details.length > 0 && (
                <div>
                  <h5 className="text-white mb-2">Cost Breakdown by Component</h5>
                  {billing.details.map((detail, idx) => (
                    <div key={idx} className="flex justify-between text-sm text-gray-300 p-1 border-b border-gray-700 last:border-b-0">
                      <span>{detail.name}</span>
                      <span>{detail.cost.toFixed(2)} {billing.currency} ({detail.energy.toFixed(3)} kWh)</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          <br></br>

          {/* HVAC Status Card - Now hides if no data */}
          {hvacData && (
            <div className="summary-card mb-6 p-4">
              <h4 className="text-md font-semibold mb-2">{scopeTitle} HVAC Status</h4>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-gray-400 text-sm">Average Temperature</p>
                  <p className="text-white text-lg font-semibold">{hvacData.avgTemperature.toFixed(1)} °C</p>
                </div>
                <div>
                  <p className="text-gray-400 text-sm">Average Humidity</p>
                  <p className="text-white text-lg font-semibold">{hvacData.avgHumidity.toFixed(1)} %</p>
                </div>
                <div>
                  <p className="text-gray-400 text-sm">Active Zones</p>
                  <p className="text-white text-lg font-semibold">{hvacData.activeZones} / {hvacData.totalZones}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-sm">Status</p>
                  <p className="text-white text-lg font-semibold">{hvacData.status}</p>
                </div>
                <div className="col-span-2">
                  <p className="text-gray-400 text-sm">Data Points</p>
                  <p className="text-white text-lg font-semibold">{hvacData.dataPoints}</p>
                </div>
              </div>
            </div>
          )}

          <br></br>

          {/* Security Status Card - Now hides if no data */}
          {securityData && (
            <div className="summary-card mb-6 p-4">
              <h4 className="text-md font-semibold mb-2">{scopeTitle} Security Status</h4>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-gray-400 text-sm">Active Devices</p>
                  <p className="text-white text-lg font-semibold">{securityData.activeDevices} / {securityData.totalDevices}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-sm">Alert Count</p>
                  <p className="text-white text-lg font-semibold">{securityData.alertCount}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-sm">Status</p>
                  <p className="text-white text-lg font-semibold">{securityData.status}</p>
                </div>
                <div className="col-span-2">
                  <p className="text-gray-400 text-sm">Data Points</p>
                  <p className="text-white text-lg font-semibold">{securityData.dataPoints}</p>
                </div>
              </div>
            </div>
          )}
        </>
      )}

      <br></br>
      <br></br>
      <br></br>
    </PageLayout>
  );
};

export default UsagePage;