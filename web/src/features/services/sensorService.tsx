// src/services/sensorService.ts
import axiosInstance from "../../service/AppService.tsx";
import type { ESP32Response } from "../types/sensorLogTypes";

const SENSOR_API = "/api/esp32/";

console.log("🚀 [SensorService] axiosInstance imported:", axiosInstance);

export const sensorService = {
  // ✅ Get latest sensor data
  fetchLatest: async (): Promise<ESP32Response> => {
    console.log("🔍 [SensorService] Fetching latest sensor data");
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}latest/`);
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
};
