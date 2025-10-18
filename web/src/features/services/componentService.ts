// src/services/componentService.ts
import axiosInstance from "../../service/AppService.tsx";
import type { Component } from "../types/componentTypes";

const COMPONENT_API = "/api/components/";

export const componentService = {
  // ✅ Get all components
  fetchAll: async (): Promise<Component[]> => {
    console.log("🔍 [ComponentService] Fetching all components");
    const { data } = await axiosInstance.get<Component[]>(COMPONENT_API);
    return data;
  },

  // ✅ Get components by equipment ID
  fetchByEquipment: async (equipmentId: string): Promise<Component[]> => {
    console.log("🔍 [ComponentService] Fetching components for equipment:", equipmentId);
    const { data } = await axiosInstance.get<Component[]>(`${COMPONENT_API}?equipment=${equipmentId}`);
    return data;
  },

  // ✅ Get single component details
  fetchById: async (componentId: string): Promise<Component> => {
    console.log("🔍 [ComponentService] Fetching component:", componentId);
    const { data } = await axiosInstance.get<Component>(`${COMPONENT_API}${componentId}/`);
    return data;
  },
};
