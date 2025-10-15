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

  // Generalized fetch logs with params
  fetchLogs: async (params: Record<string, string>): Promise<SensorData[]> => {
    const { data } = await axiosInstance.get<SensorData[]>(SENSOR_LOG_API, { params });
    return data;
  },


  // ✅ Get latest sensor data filtered by pageType
  fetchByPageType: async (pageType: string): Promise<ESP32Response> => {
    console.log("🔍 [SensorService] Fetching sensor data for pageType:", pageType);
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}latest/`, {
      params: { pageType },
    });
    return data;
  },

  // 🔥 Future endpoints (if needed, just like RoomService has `analytics`)
  fetchSensorData: async (): Promise<ESP32Response> => {
    console.log("🔍 [SensorService] Fetching full sensor data");
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}sensor-data/`);
    return data;
  },

  fetchHealthCheck: async (): Promise<ESP32Response> => {
    console.log("🔍 [SensorService] Running ESP32 health check");
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}health/`);
    return data;
  },

  fetchHeartbeat: async (): Promise<ESP32Response> => {
    console.log("🔍 [SensorService] Fetching ESP32 heartbeat");
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
