import axiosInstance from "../../service/AppService.tsx";
import type { User } from "../types/dashboardTypes"

const USER_API = "/api/users/";

export const userService = {
  getAll: async (): Promise<User[]> => {
    const res = await axiosInstance.get<User[]>(USER_API);
    return res.data;
  },

  getById: async (id: string): Promise<User> => {
    const res = await axiosInstance.get<User>(`${USER_API}${id}/`);
    return res.data;
  },

  create: async (roomData: Partial<User>): Promise<User> => {
    const res = await axiosInstance.post<User>(USER_API, roomData);
    return res.data;
  },

  update: async (id: string, roomData: Partial<User>): Promise<User> => {
    const res = await axiosInstance.put<User>(`${USER_API}${id}/`, roomData);
    return res.data;
  },

  remove: async (id: string): Promise<void> => {
    await axiosInstance.delete(`${USER_API}${id}/`);
  },
};