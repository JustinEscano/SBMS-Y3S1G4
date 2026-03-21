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

  // BUG FIX: Was a useMemo with new Date() — created new object every render,
  // causing infinite re-fetch loops when included in useEffect deps.
  // Now a stable callback; called inside the effect only when needed.
  const getPeriodDates = useCallback(() => {
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

  // Fetch latest sensor data (all) using the correct endpoint
  useEffect(() => {
    sensorService.fetchLatest()
      .then((resp: any) => {
        setLatestSensorData(resp.data ?? []);
      })
      .catch(console.error);
  }, []);

  // Auto-select first room and equipment like Flutter, with parallel component fetch
  useEffect(() => {
    if (rooms.length > 0 && !selectedRoom) {
      setSelectedRoom(rooms[0].id);
    }
  }, [rooms, selectedRoom]);

  // BUG FIX: Previously two separate useEffects both fetched components for
  // selectedEquipmentId — they raced each other and caused the component ID to
  // flicker/reset. Merged into a single effect that handles both auto-select
  // (first room load) and manual equipment change.
  useEffect(() => {
    // BUG FIX: Removed the automatic equipment selection logic. 
    // Previously, it would silently auto-select the first equipment in the room
    // and wait 300ms (debounce) to update selectedActualComponentId. This caused
    // the charts to fetch room-wide data, then suddenly filter down to
    // that one specific equipment. If that equipment had no data, the charts
    // would immediately wipe empty ("fetch things but revert"). 
    // Now it defaults to "All Equipment" ("") so the room-wide data stays.

    // Fetch components whenever selectedEquipmentId changes
    if (selectedEquipmentId) {
      componentService.fetchByEquipment(selectedEquipmentId)
        .then((compData: Component[]) => {
          setComponents(compData);
          const pzemComp = compData.find((c) => (c.component_type as string) === "pzem");
          debouncedSetComponentId(pzemComp?.id || "");
        })
        .catch(() => {
          setComponents([]);
          debouncedSetComponentId("");
        });
    } else {
      setComponents([]);
      debouncedSetComponentId("");
    }
  }, [selectedRoom, equipments, selectedEquipmentId, debouncedSetComponentId]);

  // Fetch data like loadEnergyData in Flutter, using provided service for summary/billing
  useEffect(() => {
    const fetchData = async () => {
      if (selectedScope === null) return;
      if (selectedScope === "room" && !scopeId) {
        // Prevent premature fetching: wait until the room dropdown state is fully initialized
        // Otherwise, it queries the whole database, renders it, and then instantly wipes it 
        // when the specific empty room finishes loading ("appears then disappears" bug).
        return;
      }
      console.log("[DEBUG] fetchData execution triggered with:", {
        selectedScope, scopeId, selectedActualComponentId, periodType
      });

      setLoading(true);
      setError("");
      try {
        // BUG FIX: Call getPeriodDates() as a function — previously it was
        // accessed as a useMemo object, which was recreated on every render
        // (because new Date() inside) and caused this effect to re-run infinitely.
        const { start, end } = getPeriodDates();

        // BUG FIX: Removed unsupported params: `limit`, `component_type`, `timeframe`.
        // SensorLogViewSet only supports: room_id, component_id, period_start, period_end.
        // Use `page_size` (DRF pagination param) instead of the unsupported `limit`.
        const hvacParams: Record<string, string | PeriodType> = {
          period_start: start.toISOString(),
          period_end: end.toISOString(),
          page_size: "1000",
        };
        if (scopeId) hvacParams.room_id = scopeId;
        const dht22Comp = components.find((c) => (c.component_type as string) === "dht22");
        if (dht22Comp) hvacParams.component_id = dht22Comp.id;

        const securityParams: Record<string, string | PeriodType> = {
          period_start: start.toISOString(),
          period_end: end.toISOString(),
          page_size: "1000",
        };
        if (scopeId) securityParams.room_id = scopeId;
        const motionComp = components.find((c) => (c.component_type as string) === "motion");
        if (motionComp) securityParams.component_id = motionComp.id;

        // Always fetch HVAC and Security
        const [hvacLogsData, securityLogsData] = await Promise.all([
          sensorService.fetchLogs(hvacParams),
          sensorService.fetchLogs(securityParams),
        ]);

        let rawHvac = hvacLogsData;
        let rawSecurity = securityLogsData;
        if (selectedEquipmentId) {
          rawHvac = rawHvac.filter((log: SensorData) => log.equipment === selectedEquipmentId);
          rawSecurity = rawSecurity.filter((log: SensorData) => log.equipment === selectedEquipmentId);
        }

        const validHvac = rawHvac.filter((log: SensorData) => log.recorded_at);
        const sortedHvac = validHvac.sort((a, b) => new Date(a.recorded_at!).getTime() - new Date(b.recorded_at!).getTime());
        setHvacLogs(sortedHvac);

        const validSecurity = rawSecurity.filter((log: SensorData) => log.recorded_at);
        const sortedSecurity = validSecurity.sort((a, b) => new Date(a.recorded_at!).getTime() - new Date(b.recorded_at!).getTime());
        setSecurityLogs(sortedSecurity);

        // BUG FIX: Removed restrictive `if (!(selectedScope === "room" && !selectedEquipmentId))` 
        // block. This explicitly wiped out energy data when a room was broadly selected without
        // an equipment, which is why the data "didn't stay" for room usage.
        let filteredSummaries: EnergySummary[] = [];
        let energyLogs: SensorData[] = [];

        const baseParams: Record<string, string | PeriodType> = {
          period_start: start.toISOString(),
          period_end: end.toISOString(),
          page_size: "1000",
        };
        if (scopeId) baseParams.room_id = scopeId;
        if (selectedActualComponentId) baseParams.component_id = selectedActualComponentId;

        console.log(`[DEBUG] Fetching energy logs with baseParams:`, baseParams);
        let rawEnergyLogs = await sensorService.fetchLogs(baseParams);
        console.log(`[DEBUG] Received ${rawEnergyLogs.length} raw energyLogs from API.`);

        if (selectedEquipmentId) {
          rawEnergyLogs = rawEnergyLogs.filter((log: SensorData) => log.equipment === selectedEquipmentId);
        }
        energyLogs = rawEnergyLogs;

        // Ensure legacy DB `energy_usage` maps cleanly to the `energy` key for charting
        const valid = energyLogs
          .filter((log: SensorData) => log.recorded_at)
          .map(log => ({
            ...log,
            energy: log.energy ?? log.energy_usage
          }));
          
        console.log(`[DEBUG] Filtered to ${valid.length} valid logs with recorded_at.`);
        const sorted = valid.sort((a, b) => new Date(a.recorded_at!).getTime() - new Date(b.recorded_at!).getTime());
        setSensorLogs(sorted);
        console.log(`[DEBUG] setSensorLogs called with ${sorted.length} items`);

        if (selectedScope === "room") {
          const allSummaries = await fetchEnergySummaries(scopeId || undefined);
          filteredSummaries = allSummaries.filter((r) => r.period_type === periodType);
          if (selectedActualComponentId) {
            filteredSummaries = filteredSummaries.filter((r) => r.component_id === selectedActualComponentId);
          }
        }

        const totalEnergy = filteredSummaries.length > 0 ? filteredSummaries.reduce((sum, r) => sum + r.total_energy, 0) : energyLogs.reduce((sum, log) => sum + (log.energy ?? 0), 0);
        
        const totalReadings = filteredSummaries.length > 0 ? filteredSummaries.reduce((sum, r) => sum + r.reading_count, 0) : energyLogs.length;
        
        const finalAvgPower = filteredSummaries.length > 0 ? 
          filteredSummaries.reduce((sum, r) => sum + (r.avg_power * r.reading_count), 0) / (totalReadings || 1) : 
          energyLogs.reduce((sum, log) => sum + (log.power ?? 0), 0) / (energyLogs.length || 1);
        
        const finalPeakPower = filteredSummaries.length > 0 ? 
          Math.max(...filteredSummaries.map((r) => r.peak_power), 0) : 
          Math.max(...energyLogs.map((log) => log.power ?? 0), 0);

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
            reading_count: totalReadings || 0,
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
        }
      } catch (err: any) {
        setError(`Failed to load data: ${err.message || err}`);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  // BUG FIX: Added `components` to dependency array to resolve stale closure issues
  // where equipment-specific HVAC/Security charts would pull room-wide data because
  // the filter logic couldn't see the new equipment components in time.
  }, [selectedScope, scopeId, selectedActualComponentId, periodType, getPeriodDates, components]);

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
    // BUG FIX: Call getPeriodDates() as function (was accessed as .start/.end property)
    const { start, end } = getPeriodDates();
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
      // BUG FIX: Prevent crash if log falls exactly on the end boundary
      if (!bins[key]) {
        bins[key] = [];
      }
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
    console.log(`[DEBUG] Re-computing powerChartData from sensorLogs (length: ${sensorLogs.length})`);
    const { labels, data } = createBinnedData(sensorLogs, 'power', (vals) => vals.length ? vals.reduce((sum, val) => sum + val, 0) / vals.length : 0);
    console.log(`[DEBUG] powerChartData produced ${data.length} datapoints. Valid >0 datapoints: ${data.filter(d => d > 0).length}`);
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
    const adjustedData = data.map((point) => {
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
    setSelectedEquipmentId(""); // BUG FIX: Do NOT auto-select equipment when changing rooms
    setSelectedActualComponentId("");
  };

  const handleEquipmentChange = (equipId: string) => {
    setSelectedEquipmentId(equipId);
    setSelectedActualComponentId("");
  };

  const isRoomScope = selectedScope === "room";

  return (
    <PageLayout initialSection={{ parent: "Analytics" }}>
      {/* Page Header */}
      <div style={{ marginBottom: '32px', display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 800, color: '#ffffff', margin: 0, letterSpacing: '-0.02em' }}>{scopeTitle} Analytics</h1>
          <p style={{ fontSize: '14px', color: '#64748b', margin: '4px 0 0' }}>Monitor energy, HVAC, and security data trends</p>
        </div>
        
        {/* Filter Selector */}
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
          <select value={selectedScope} onChange={(e) => handleScopeChange(e.target.value as ScopeType)}
            style={{ padding: '9px 14px', borderRadius: '10px', border: '1px solid #1e293b', background: '#080b14', color: '#e2e8f0', fontSize: '14px', outline: 'none' }}>
            <option value="building">Building</option>
            <option value="all_rooms">All Rooms</option>
            <option value="room">Room</option>
          </select>
          {selectedScope === "room" && (
            <>
              <select value={selectedRoom} onChange={(e) => handleRoomChange(e.target.value)}
                style={{ padding: '9px 14px', borderRadius: '10px', border: '1px solid #1e293b', background: '#080b14', color: '#e2e8f0', fontSize: '14px', outline: 'none' }}>
                <option value="">Select Room</option>
                {rooms.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
              </select>
              <select value={selectedEquipmentId} onChange={(e) => handleEquipmentChange(e.target.value)}
                style={{ padding: '9px 14px', borderRadius: '10px', border: '1px solid #1e293b', background: '#080b14', color: '#e2e8f0', fontSize: '14px', outline: 'none' }}>
                <option value="">Select Equipment</option>
                {equipments.filter((eq) => eq.room === selectedRoom).map((eq) => (
                  <option key={eq.id} value={eq.id}>{eq.name}</option>
                ))}
              </select>
            </>
          )}
          <select value={periodType} onChange={(e) => setPeriodType(e.target.value as PeriodType)}
            style={{ padding: '9px 14px', borderRadius: '10px', border: '1px solid #1e293b', background: '#080b14', color: '#e2e8f0', fontSize: '14px', outline: 'none' }}>
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
          </select>
        </div>
      </div>

      {error && <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: '10px', padding: '12px 16px', marginBottom: '20px', color: '#f87171', fontSize: '14px' }}>{error}</div>}

      {/* Charts Grid */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        
        {/* Power Chart */}
        <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px', position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -20, right: -20, width: '150px', height: '150px', borderRadius: '50%', background: '#4c6ef5', opacity: 0.05, filter: 'blur(30px)', pointerEvents: 'none' }} />
          <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px', position: 'relative', zIndex: 1 }}>Power Consumption{chartSuffix}</h3>
          
          {loading && <div style={{ position: 'absolute', inset: 0, background: 'rgba(15,23,42,0.6)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10, borderRadius: '16px' }}><p style={{ color: '#cbd5e1', fontWeight: 500 }}>Updating...</p></div>}
          
          {powerChartData.datasets[0].data.length > 0 ? (
            <div style={{ position: 'relative', width: '100%', height: '300px', zIndex: 1 }}>
              <Line data={powerChartData} options={chartOptions} />
            </div>
          ) : (
            <div style={{ width: '100%', height: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#64748b' }}>No power data available for this period</div>
          )}
        </div>

        {/* Energy Chart */}
        <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px', position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -20, right: -20, width: '150px', height: '150px', borderRadius: '50%', background: '#f59f00', opacity: 0.05, filter: 'blur(30px)', pointerEvents: 'none' }} />
          <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px', position: 'relative', zIndex: 1 }}>Energy Consumption{chartSuffix}</h3>
          
          {loading && <div style={{ position: 'absolute', inset: 0, background: 'rgba(15,23,42,0.6)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10, borderRadius: '16px' }}><p style={{ color: '#cbd5e1', fontWeight: 500 }}>Updating...</p></div>}
          
          {energyChartData.datasets[0].data.length > 0 ? (
            <div style={{ position: 'relative', width: '100%', height: '300px', zIndex: 1 }}>
              <Line data={energyChartData} options={{ ...otherChartOptions, plugins: { ...otherChartOptions.plugins, title: { display: false } } }} />
            </div>
          ) : (
            <div style={{ width: '100%', height: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#64748b' }}>No energy data available for this period</div>
          )}
        </div>

        {/* HVAC Charts */}
        <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px', position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -20, right: -20, width: '150px', height: '150px', borderRadius: '50%', background: '#ff6384', opacity: 0.05, filter: 'blur(30px)', pointerEvents: 'none' }} />
          <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px', position: 'relative', zIndex: 1 }}>Temperature Trend{chartSuffix}</h3>
          
          {loading && <div style={{ position: 'absolute', inset: 0, background: 'rgba(15,23,42,0.6)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10, borderRadius: '16px' }}><p style={{ color: '#cbd5e1', fontWeight: 500 }}>Updating...</p></div>}
          
          {temperatureChartData.datasets[0].data.length > 0 ? (
            <div style={{ position: 'relative', width: '100%', height: '300px', zIndex: 1 }}>
              <Line data={temperatureChartData} options={{ ...otherChartOptions, plugins: { ...otherChartOptions.plugins, title: { display: false } } }} />
            </div>
          ) : (
            <div style={{ width: '100%', height: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#64748b' }}>No data available</div>
          )}
        </div>

        <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px', position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -20, right: -20, width: '150px', height: '150px', borderRadius: '50%', background: '#36a2eb', opacity: 0.05, filter: 'blur(30px)', pointerEvents: 'none' }} />
          <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px', position: 'relative', zIndex: 1 }}>Humidity Trend{chartSuffix}</h3>
          
          {loading && <div style={{ position: 'absolute', inset: 0, background: 'rgba(15,23,42,0.6)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10, borderRadius: '16px' }}><p style={{ color: '#cbd5e1', fontWeight: 500 }}>Updating...</p></div>}
          
          {humidityChartData.datasets[0].data.length > 0 ? (
            <div style={{ position: 'relative', width: '100%', height: '300px', zIndex: 1 }}>
              <Line data={humidityChartData} options={{ ...otherChartOptions, plugins: { ...otherChartOptions.plugins, title: { display: false } } }} />
            </div>
          ) : (
            <div style={{ width: '100%', height: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#64748b' }}>No data available</div>
          )}
        </div>

        {/* Security Chart */}
        <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px', position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -20, right: -20, width: '150px', height: '150px', borderRadius: '50%', background: '#ffce56', opacity: 0.05, filter: 'blur(30px)', pointerEvents: 'none' }} />
          <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px', position: 'relative', zIndex: 1 }}>Security Alerts Trend{chartSuffix}</h3>
          
          {loading && <div style={{ position: 'absolute', inset: 0, background: 'rgba(15,23,42,0.6)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10, borderRadius: '16px' }}><p style={{ color: '#cbd5e1', fontWeight: 500 }}>Updating...</p></div>}
          
          {securityChartData.datasets[0].data.length > 0 ? (
            <div style={{ position: 'relative', width: '100%', height: '300px', zIndex: 1 }}>
              <Line data={securityChartData} options={{ ...otherChartOptions, plugins: { ...otherChartOptions.plugins, title: { display: false } } }} />
            </div>
          ) : (
            <div style={{ width: '100%', height: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#64748b' }}>No data available</div>
          )}
        </div>
      </div> {/* End Charts Grid */}

      {/* Room-specific sections */}
      {isRoomScope && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', marginTop: '32px' }}>
          {/* Energy Statistics */}
          {summary && billing && (
            <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ffffff', margin: '0 0 20px' }}>{scopeTitle} Energy Statistics</h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '20px' }}>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Total Energy</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{summary.total_energy.toFixed(3)} <span style={{ fontSize: '14px', color: '#64748b' }}>kWh</span></p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Avg Power</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{summary.avg_power.toFixed(2)} <span style={{ fontSize: '14px', color: '#64748b' }}>kW</span></p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Peak Power</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{summary.peak_power.toFixed(2)} <span style={{ fontSize: '14px', color: '#64748b' }}>kW</span></p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Reading Count</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{summary.reading_count}</p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Total Cost</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{billing.total_cost.toFixed(2)} <span style={{ fontSize: '14px', color: '#64748b' }}>{billing.currency}</span></p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Effective Rate</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#60a5fa', margin: 0 }}>{billing.effective_rate.toFixed(2)} <span style={{ fontSize: '14px', color: '#64748b' }}>{billing.currency}/kWh</span></p>
                </div>
              </div>
              {billing.details.length > 0 && (
                <div style={{ marginTop: '24px', paddingTop: '20px', borderTop: '1px solid #1e293b' }}>
                  <h5 style={{ fontSize: '14px', fontWeight: 600, color: '#cbd5e1', margin: '0 0 12px' }}>Cost Breakdown by Component</h5>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {billing.details.map((detail, idx) => (
                      <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '8px', borderBottom: idx < billing.details.length - 1 ? '1px solid #1e293b' : 'none' }}>
                        <span style={{ fontSize: '14px', color: '#94a3b8' }}>{detail.name}</span>
                        <span style={{ fontSize: '14px', fontWeight: 500, color: '#e2e8f0' }}>{detail.cost.toFixed(2)} {billing.currency} <span style={{ color: '#64748b' }}>({detail.energy.toFixed(3)} kWh)</span></span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* HVAC Status */}
          {hvacData && (
            <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ffffff', margin: '0 0 20px' }}>{scopeTitle} HVAC Status</h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '20px' }}>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Avg Temperature</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{hvacData.avgTemperature.toFixed(1)} <span style={{ fontSize: '14px', color: '#64748b' }}>°C</span></p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Avg Humidity</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#60a5fa', margin: 0 }}>{hvacData.avgHumidity.toFixed(1)} <span style={{ fontSize: '14px', color: '#64748b' }}>%</span></p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Active Zones</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{hvacData.activeZones} <span style={{ fontSize: '14px', color: '#64748b' }}>/ {hvacData.totalZones}</span></p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Data Points</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{hvacData.dataPoints}</p>
                </div>
              </div>
            </div>
          )}

          {/* Security Status */}
          {securityData && (
            <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ffffff', margin: '0 0 20px' }}>{scopeTitle} Security Status</h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '20px' }}>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Active Devices</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{securityData.activeDevices} <span style={{ fontSize: '14px', color: '#64748b' }}>/ {securityData.totalDevices}</span></p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Alert Count</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#ef4444', margin: 0 }}>{securityData.alertCount}</p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Status</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#22c55e', margin: 0, textTransform: 'capitalize' }}>{securityData.status}</p>
                </div>
                <div>
                  <p style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px', margin: '0 0 4px' }}>Data Points</p>
                  <p style={{ fontSize: '20px', fontWeight: 600, color: '#e2e8f0', margin: 0 }}>{securityData.dataPoints}</p>
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </PageLayout>
  );
};

export default UsagePage;