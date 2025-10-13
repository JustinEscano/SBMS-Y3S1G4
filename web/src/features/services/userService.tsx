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

  update: async (id: string, userData: Partial<User>): Promise<User> => {
    const res = await axiosInstance.patch<User>(`${USER_API}${id}/`, userData); // Changed to patch
    return res.data;
  },

  remove: async (id: string): Promise<void> => {
    await axiosInstance.delete(`${USER_API}${id}/`);
  },

  changePassword: async (passwordData: { current_password: string; new_password: string }) => {
  const res = await axiosInstance.patch("/api/password/change/", {
    current_password: passwordData.current_password,
    password: passwordData.new_password,  // Backend expects 'password' for new
  });
  return res.data;
},
};