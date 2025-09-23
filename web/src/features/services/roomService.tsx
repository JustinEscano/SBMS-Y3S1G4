import axiosInstance from "../../service/AppService.tsx";
import type { RoomAnalytics } from "../types/sensorLogTypes";
import type { Room } from "../types/dashboardTypes";

const ROOM_API = "/api/rooms/";

console.log('🚀 [RoomService] axiosInstance imported:', axiosInstance);

export const roomService = {
  getAll: async (): Promise<Room[]> => {
    console.log('🔍 [RoomService] Token exists?', localStorage.getItem('access_token') ? 'YES' : 'NO');
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

  // 🔥 New: fetch analytics for one room
  getAnalytics: async (id: string): Promise<RoomAnalytics> => {
    const { data } = await axiosInstance.get<RoomAnalytics>(`${ROOM_API}${id}/analytics/`);
    return data;
  },
};
