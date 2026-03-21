// src/services/sensorService.ts
import axiosInstance from "../../service/AppService.tsx";
import type { ESP32Response, SensorData } from "../types/sensorLogTypes";

const SENSOR_API = "/api/esp32/";
const SENSOR_LOG_API = "/api/sensorlog/";

export const sensorService = {
  fetchLatest: async (): Promise<ESP32Response> => {
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}latest/`);
    return data;
  },

  fetchLatestReading: async (componentId: string): Promise<SensorData | null> => {
    try {
      const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}latest/`, {
        params: { component: componentId },
      });
      return data?.data?.[0] || null;
    } catch (error) {
      console.error("Failed to fetch latest reading:", error);
      return null;
    }
  },

  // BUG FIX: DRF pagination wraps responses as { count, next, previous, results: [...] }
  // Previously this was typed as SensorData[] and parsed directly — meaning `data`
  // was the wrapper object {count:X, results:[...]}, not the array. Charts were always
  // empty because `data.map(...)` would fail or iterate over object keys.
  fetchLogs: async (params: Record<string, string>): Promise<SensorData[]> => {
    const { data } = await axiosInstance.get<SensorData[] | { count: number; results: SensorData[] }>(SENSOR_LOG_API, { params });
    // Handle both paginated ({ results: [...] }) and non-paginated ([...]) responses
    if (data && !Array.isArray(data) && 'results' in data) {
      return data.results;
    }
    return data as SensorData[];
  },


  // ✅ Get latest sensor data filtered by pageType
  fetchByPageType: async (pageType: string): Promise<ESP32Response> => {
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}latest/`, {
      params: { pageType },
    });
    return data;
  },

  // 🔥 Future endpoints (if needed, just like RoomService has `analytics`)

  fetchHealthCheck: async (): Promise<ESP32Response> => {
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}health/`);
    return data;
  },

  fetchHeartbeat: async (): Promise<ESP32Response> => {
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}heartbeat/`);
    return data;
  },

  fetchByRoom: async (roomId: string): Promise<SensorData> => {
    const { data } = await axiosInstance.get<SensorData>(`${SENSOR_API}?room=${roomId}`);
    return data;
  },

  // ✅ Get logs by equipment
  fetchByEquipment: async (equipmentId: string): Promise<SensorData> => {
    const { data } = await axiosInstance.get<SensorData>(`${SENSOR_API}?equipment=${equipmentId}`);
    return data;
  },

  fetchAllLogs: async (componentId: string): Promise<SensorData[]> => {
  // Assuming your API endpoint supports ?device_id= or /:id
    const { data } = await axiosInstance.get<SensorData[]>(`/api/sensorlog/?component_id=${componentId}`);  // Or `/api/sensor-logs/${componentId}`
    return data;  // Backend should filter: SELECT * FROM sensor_logs WHERE device_id = $1
  },
};
