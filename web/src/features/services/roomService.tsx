import axiosInstance from "../../service/AppService";
import type { Room } from "../types/dashboardTypes";

const ROOM_API = "/api/rooms/";

export const roomService = {
  getAll: async (): Promise<Room[]> => {
    const res = await axiosInstance.get<Room[]>(ROOM_API);
    return res.data;
  },

  getById: async (id: string): Promise<Room> => {
    const res = await axiosInstance.get<Room>(`${ROOM_API}${id}/`);
    return res.data;
  },

  create: async (roomData: Partial<Room>): Promise<Room> => {
    const res = await axiosInstance.post<Room>(ROOM_API, roomData);
    return res.data;
  },

  update: async (id: string, roomData: Partial<Room>): Promise<Room> => {
    const res = await axiosInstance.put<Room>(`${ROOM_API}${id}/`, roomData);
    return res.data;
  },

  remove: async (id: string): Promise<void> => {
    await axiosInstance.delete(`${ROOM_API}${id}/`);
  },
};
