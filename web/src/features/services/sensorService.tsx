// src/services/sensorService.ts
import axiosInstance from "../../service/AppService.tsx";
import type { ESP32Response, SensorData } from "../types/sensorLogTypes";

const SENSOR_API = "/api/esp32/";

console.log("🚀 [SensorService] axiosInstance imported:", axiosInstance);

export const sensorService = {
  // ✅ Get latest sensor data
  fetchLatest: async (): Promise<ESP32Response> => {
    console.log("🔍 [SensorService] Fetching latest sensor data");
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}latest/`);
    return data;
  },

  // src/features/services/sensorService.ts
  fetchLatestReading: async (componentId: string): Promise<SensorData | null> => {
    try {
      const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}latest/`, {
        params: { component: componentId },
      });
      return data?.data?.[0] || null; // return latest log object
    } catch (error) {
      console.error("❌ [SensorService] Failed to fetch latest reading:", error);
      return null;
    }
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
    try {
      console.log(`🔍 [SensorService] Fetching all logs for component: ${componentId}`);
      const { data } = await axiosInstance.get<SensorData[]>(`/api/sensorlog/`, {
        params: { component: componentId }, // or 'equipment' depending on your filter
      });
      return data || []; // Return full logs array, empty if none
    } catch (error) {
      console.error(`❌ [SensorService] Failed to fetch all logs for component ${componentId}:`, error);
      return [];
    }
  },
};
