// src/services/sensorService.ts
import axiosInstance from "../../service/AppService.tsx";
import type { ESP32Response } from "../types/sensorLogTypes";

const SENSOR_API = "/api/esp32/";

export const sensorService = {
  // ✅ Get latest sensor data
  fetchLatest: async (): Promise<ESP32Response> => {
    const { data } = await axiosInstance.get<ESP32Response>(`${SENSOR_API}latest/`);
    return data;
  },

  // ✅ Get latest sensor data filtered by pageType
  fetchByPageType: async (pageType: string): Promise<ESP32Response> => {
    const { data } = await axiosInstance.get<ESP32Response>(
      `${SENSOR_API}latest/`,
      { params: { pageType } }
    );
    return data;
  },
};
