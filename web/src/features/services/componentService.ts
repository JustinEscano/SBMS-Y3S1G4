// src/services/componentService.ts
import axiosInstance from "../../service/AppService.tsx";
import type { Component } from "../types/componentTypes";

const COMPONENT_API = "/api/components/";

export const componentService = {
  fetchAll: async (): Promise<Component[]> => {
    const { data } = await axiosInstance.get<Component[]>(COMPONENT_API);
    return data;
  },

  fetchByEquipment: async (equipmentId: string): Promise<Component[]> => {
    const { data } = await axiosInstance.get<Component[]>(`${COMPONENT_API}?equipment=${equipmentId}`);
    return data;
  },

  fetchById: async (componentId: string): Promise<Component> => {
    const { data } = await axiosInstance.get<Component>(`${COMPONENT_API}${componentId}/`);
    return data;
  },
};
