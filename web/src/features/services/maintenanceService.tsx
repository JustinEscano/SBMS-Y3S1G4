import axiosInstance from "../../service/AppService";
import type { MaintenanceRequest } from "../types/dashboardTypes";

const MAINTENANCE_API = "/api/maintenancerequest/";

export const maintenanceService = {
  getAll: async (): Promise<MaintenanceRequest[]> => {
    const res = await axiosInstance.get<MaintenanceRequest[]>(MAINTENANCE_API);
    return res.data;
  },

  getById: async (id: string): Promise<MaintenanceRequest> => {
    const res = await axiosInstance.get<MaintenanceRequest>(`${MAINTENANCE_API}${id}/`);
    return res.data;
  },

  create: async (requestData: Partial<MaintenanceRequest>): Promise<MaintenanceRequest> => {
    const res = await axiosInstance.post<MaintenanceRequest>(MAINTENANCE_API, requestData);
    return res.data;
  },

  update: async (id: string, requestData: Partial<MaintenanceRequest>): Promise<MaintenanceRequest> => {
    const res = await axiosInstance.put<MaintenanceRequest>(`${MAINTENANCE_API}${id}/`, requestData);
    return res.data;
  },

  remove: async (id: string): Promise<void> => {
    await axiosInstance.delete(`${MAINTENANCE_API}${id}/`);
  },
};
