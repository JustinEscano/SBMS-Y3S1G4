import axiosInstance from '../../service/AppService';
import type { MaintenanceRequest } from '../types/maintenanceTypes';

const MAINTENANCE_API = '/api/maintenancerequest/';

export const getAllMaintenanceRequests = async (): Promise<MaintenanceRequest[]> => {
  const res = await axiosInstance.get<MaintenanceRequest[]>(MAINTENANCE_API);
  return res.data;
};

export const getMaintenanceRequestById = async (id: string): Promise<MaintenanceRequest> => {
  const res = await axiosInstance.get<MaintenanceRequest>(`${MAINTENANCE_API}${id}/`);
  return res.data;
};

export const createMaintenanceRequest = async (
  requestData: Partial<MaintenanceRequest>
): Promise<MaintenanceRequest> => {
  const res = await axiosInstance.post<MaintenanceRequest>(MAINTENANCE_API, requestData);
  return res.data;
};

export const updateMaintenanceRequest = async (
  id: string,
  requestData: Partial<MaintenanceRequest>
): Promise<MaintenanceRequest> => {
  const res = await axiosInstance.put<MaintenanceRequest>(`${MAINTENANCE_API}${id}/`, requestData);
  return res.data;
};

export const deleteMaintenanceRequest = async (id: string): Promise<void> => {
  await axiosInstance.delete(`${MAINTENANCE_API}${id}/`);
};