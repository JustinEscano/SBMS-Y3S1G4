import axiosInstance from "../../service/AppService";
import type { User } from "../types/dashboardTypes"

const ROOM_API = "/api/users/";

export const userService = {
  getAll: async (): Promise<User[]> => {
    const res = await axiosInstance.get<User[]>(ROOM_API);
    return res.data;
  },

  getById: async (id: string): Promise<User> => {
    const res = await axiosInstance.get<User>(`${ROOM_API}${id}/`);
    return res.data;
  },

  create: async (roomData: Partial<User>): Promise<User> => {
    const res = await axiosInstance.post<User>(ROOM_API, roomData);
    return res.data;
  },

  update: async (id: string, roomData: Partial<User>): Promise<User> => {
    const res = await axiosInstance.put<User>(`${ROOM_API}${id}/`, roomData);
    return res.data;
  },

  remove: async (id: string): Promise<void> => {
    await axiosInstance.delete(`${ROOM_API}${id}/`);
  },
};