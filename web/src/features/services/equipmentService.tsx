import axiosInstance from "../../service/AppService.tsx";
import type { Equipment } from "../types/dashboardTypes";

const EQUIPMENT_API = "/api/equipment/";

export const equipmentService = {
  getAll: async (): Promise<Equipment[]> => {
    const res = await axiosInstance.get<Equipment[]>(EQUIPMENT_API);
    return res.data;
  },

  getById: async (id: string): Promise<Equipment> => {
    const res = await axiosInstance.get<Equipment>(`${EQUIPMENT_API}${id}/`);
    return res.data;
  },

  create: async (equipmentData: Partial<Equipment>): Promise<Equipment> => {
    const res = await axiosInstance.post<Equipment>(EQUIPMENT_API, equipmentData);
    return res.data;
  },

  update: async (id: string, equipmentData: Partial<Equipment>): Promise<Equipment> => {
    const res = await axiosInstance.put<Equipment>(`${EQUIPMENT_API}${id}/`, equipmentData);
    return res.data;
  },

  remove: async (id: string): Promise<void> => {
    await axiosInstance.delete(`${EQUIPMENT_API}${id}/`);
  },

  fetchByRoom: async (roomId: string): Promise<Equipment[]> => {
    const { data } = await axiosInstance.get<Equipment[]>(`${EQUIPMENT_API}?room=${roomId}`);
    return data;
  },
};