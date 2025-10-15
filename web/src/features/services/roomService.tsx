// src/features/services/roomService.ts
import axiosInstance from "../../service/AppService.tsx";
import type { Room } from "../types/dashboardTypes";
import type { RoomAnalytics, RoomAnalyticsItem } from "../types/sensorLogTypes";

const ROOM_API = "/api/rooms/";
const ENERGY_SUMMARY_API = "/api/energysummary/";

console.log("🚀 [RoomService] axiosInstance imported:", axiosInstance);

export const roomService = {
  getAll: async (): Promise<Room[]> => {
    console.log(
      "🔍 [RoomService] Token exists?",
      localStorage.getItem("access_token") ? "YES" : "NO"
    );
    const { data } = await axiosInstance.get<Room[]>(ROOM_API);
    return data;
  },

  getById: async (id: string): Promise<Room> => {
    const { data } = await axiosInstance.get<Room>(`${ROOM_API}${id}/`);
    return data;
  },

  create: async (roomData: Partial<Room>): Promise<Room> => {
    const { data } = await axiosInstance.post<Room>(ROOM_API, roomData);
    return data;
  },

  update: async (id: string, roomData: Partial<Room>): Promise<Room> => {
    const { data } = await axiosInstance.put<Room>(`${ROOM_API}${id}/`, roomData);
    return data;
  },

  remove: async (id: string): Promise<void> => {
    await axiosInstance.delete(`${ROOM_API}${id}/`);
  },

  // ⚡ Old endpoint (if Django had /rooms/:id/analytics/)
  getAnalytics: async (id: string): Promise<RoomAnalytics> => {
    const { data } = await axiosInstance.get<RoomAnalytics>(`${ROOM_API}${id}/analytics/`);
    return data;
  },

  // ✅ Refactored: Fetch all periods, filter client-side for DB data (avoids agg zeros)
  // For weekly/monthly: Uses existing DB rows (e.g., your Sep sample with 0.024 kWh)
  // selectedPeriod: Optional for custom range (format: "Start Label → End Label")
  getEnergySummary: async (
    roomId: string,
    period_type: string = "daily",
    selectedPeriod?: string
  ): Promise<RoomAnalyticsItem[]> => {
    // Always fetch without period_type to get all DB rows (daily + pre-agg weekly/monthly)
    let url = `${ENERGY_SUMMARY_API}?room_id=${roomId}`;

    // If selectedPeriod: Add range filter
    if (selectedPeriod) {
      try {
        const [startLabel, endLabel] = selectedPeriod.split("→").map((s) => s.trim());
        const startISO = new Date(startLabel).toISOString();
        const endISO = new Date(endLabel).toISOString();
        url += `&period_start=${encodeURIComponent(startISO)}&period_end=${encodeURIComponent(endISO)}`;
        console.log(`🎯 [RoomService] Applied custom range: ${startLabel} → ${endLabel}`);
      } catch (err) {
        console.warn(`⚠️ [RoomService] Invalid selectedPeriod: ${selectedPeriod}. Skipping range.`);
      }
    }

    try {
      const { data } = await axiosInstance.get<RoomAnalyticsItem[]>(url);
      console.log(`📥 [RoomService] Raw all data:`, data);

      // Client-side filter by period_type (hits existing DB rows for weekly/monthly)
      const filteredData = data.filter(item => item.period_type === period_type);

      // If no exact match, fallback to daily for non-daily (or empty)
      if (filteredData.length === 0 && period_type !== "daily") {
        console.warn(`⚠️ [RoomService] No ${period_type} data; falling back to daily`);
        const dailyFiltered = data.filter(item => item.period_type === "daily");
        return dailyFiltered.length > 0 ? dailyFiltered : filteredData;  // Empty if no dailies
      }

      // Sort chronological (oldest first)
      filteredData.sort((a, b) => new Date(a.period_start).getTime() - new Date(b.period_start).getTime());

      console.log(`📊 [RoomService] Filtered ${period_type} data (${filteredData.length} items):`, filteredData);
      return filteredData;
    } catch (err: any) {
      console.error(`❌ [RoomService] Fetch error for ${period_type}:`, err);
      if (err.response?.status === 400 && period_type !== "daily") {
        console.warn(`🔄 [RoomService] Fallback to daily`);
        return roomService.getEnergySummary(roomId, "daily", selectedPeriod);
      }
      throw err;
    }
  },
};