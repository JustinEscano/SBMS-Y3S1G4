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

  // ✅ New version: energy summary analytics from /energysummary/?room_id=
  getEnergySummary: async (
  roomId: string,
  period_type: string = "daily",
  selectedPeriod?: string
): Promise<RoomAnalyticsItem[]> => {   // <-- add proper return type
  let url = `${ENERGY_SUMMARY_API}?room_id=${roomId}&period_type=${period_type}`;

  if (selectedPeriod) {
    const [start, end] = selectedPeriod.split("→").map((s) => s.trim());
    const startISO = new Date(start).toISOString();
    const endISO = new Date(end).toISOString();
    url += `&period_start=${encodeURIComponent(startISO)}&period_end=${encodeURIComponent(endISO)}`;
  }

  const { data } = await axiosInstance.get<RoomAnalyticsItem[]>(url); // ✅ cast to RoomAnalyticsItem[]
  return data; // ✅ now TypeScript knows this is RoomAnalyticsItem[]
},


};
