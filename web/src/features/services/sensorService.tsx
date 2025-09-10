// src/services/sensorService.ts
import type { ESP32Response } from "../types/sensorLogTypes";

class SensorService {
  private baseUrl = "/api/esp32";

  async fetchLatest(): Promise<ESP32Response> {
    const response = await fetch(`${this.baseUrl}/latest/`);
    if (!response.ok) {
      throw new Error("Failed to fetch sensor data");
    }
    return response.json();
  }

  async fetchByPageType(pageType: string): Promise<ESP32Response> {
    const response = await fetch(`${this.baseUrl}/latest/?pageType=${pageType}`);
    if (!response.ok) {
      throw new Error("Failed to fetch sensor data for page type");
    }
    return response.json();
  }
}

export const sensorService = new SensorService();
