import axiosInstance from '../../service/AppService';
import type { Equipment } from '../types/equipmentTypes';

export const getAllEquipment = async (): Promise<Equipment[]> => {
  const res = await axiosInstance.get<Equipment[]>('/api/equipment/');
  return res.data;
};

export const getEquipmentById = async (id: string): Promise<Equipment> => {
  const res = await axiosInstance.get<Equipment>(`/api/equipment/${id}/`);
  return res.data;
};

export const createEquipment = async (
  equipmentData: Partial<Equipment>
): Promise<Equipment> => {
  const res = await axiosInstance.post<Equipment>('/api/equipment/', equipmentData);
  return res.data;
};

export const updateEquipment = async (
  id: string,
  equipmentData: Partial<Equipment>
): Promise<Equipment> => {
  const res = await axiosInstance.put<Equipment>(`/api/equipment/${id}/`, equipmentData);
  return res.data;
};

export const deleteEquipment = async (id: string): Promise<void> => {
  await axiosInstance.delete(`/api/equipment/${id}/`);
};