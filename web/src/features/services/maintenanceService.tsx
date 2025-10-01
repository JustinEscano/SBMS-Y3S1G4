// src/features/services/maintenanceService.ts
import type { MaintenanceRequest, Attachment } from '../types/dashboardTypes.tsx';
import axiosInstance from "../../service/AppService.tsx";

const inProgressCreates = new Set<string>();

const BASE_URL = '/api/maintenancerequest/';

const ATTACHMENT_URL = '/api/maintenanceattachment/';

export const maintenanceService = {
  // Get all maintenance requests
  getAll: async (): Promise<MaintenanceRequest[]> => {
    console.log("Fetching all maintenance requests...");
    try {
      const res = await axiosInstance.get<MaintenanceRequest[]>(BASE_URL);
      console.log("Received maintenance requests:", res.data);
      return res.data;
    } catch (error: any) {
      console.error("Error fetching maintenance requests:", error.response?.data || error);
      throw error;
    }
  },

  // Create a new maintenance request
  create: async (payload: Partial<MaintenanceRequest>): Promise<MaintenanceRequest> => {
    const key = JSON.stringify(payload); // simple way to identify duplicates
    if (inProgressCreates.has(key)) {
      console.log("Create request already in progress for this payload, ignoring duplicate.");
      // Optionally: return a rejected promise or just ignore
      return Promise.reject(new Error("Duplicate create request in progress"));
    }

    inProgressCreates.add(key);
    console.log("Creating maintenance request with payload:", payload);

    try {
      const res = await axiosInstance.post<MaintenanceRequest>(BASE_URL, payload);
      console.log("Create response:", res.data);
      return res.data;
    } catch (error: any) {
      console.error("Error creating maintenance request:", error.response?.data || error);
      throw error;
    } finally {
      inProgressCreates.delete(key); // remove from the set after completion
    }
  },

  // Update an existing request by UUID string
  update: async (id: string, payload: Partial<MaintenanceRequest>): Promise<MaintenanceRequest> => {
    console.log(`Updating maintenance request ${id} with payload:`, payload);
    try {
      const res = await axiosInstance.put<MaintenanceRequest>(`${BASE_URL}${id}/`, payload);
      console.log(`Update response for ${id}:`, res.data);
      return res.data;
    } catch (error: any) {
      console.error(`Error updating maintenance request ${id}:`, error.response?.data || error);
      throw error;
    }
  },

  // Delete a request by UUID string
  delete: async (id: string): Promise<void> => {
    console.log(`Deleting maintenance request ${id}...`);
    try {
      await axiosInstance.delete(`${BASE_URL}${id}/`);
      console.log(`Deleted maintenance request ${id}`);
    } catch (error: any) {
      console.error(`Error deleting maintenance request ${id}:`, error.response?.data || error);
      throw error;
    }
  },

  uploadAttachment: async (requestId: string, file: File, fileName?: string): Promise<Attachment> => {
    console.log(`Uploading attachment for request ${requestId}:`, fileName || file.name);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("file_name", fileName || file.name);

    try {
      const res = await axiosInstance.post<Attachment>(
        `${BASE_URL}${requestId}/upload_attachment/`,
        formData,
        { headers: { "Content-Type": "multipart/form-data" } }
      );
      console.log("Upload response:", res.data);
      return res.data;
    } catch (error: any) {
      console.error("Error uploading attachment:", error.response?.data || error);
      throw error;
    }
  },

  // List all attachments (admin/superadmin can see all)
  getAttachments: async (): Promise<Attachment[]> => {
    console.log("Fetching all attachments...");
    try {
      const res = await axiosInstance.get<Attachment[]>(ATTACHMENT_URL);
      return res.data;
    } catch (error: any) {
      console.error("Error fetching attachments:", error.response?.data || error);
      throw error;
    }
  },

  deleteAttachment: async (requestId: string, attachmentId: string) => {
    await axiosInstance.delete(
      `/api/maintenancerequest/${requestId}/upload_attachment/${attachmentId}/`
    );
  },

  respond: async (requestId: string, payload: { response: string; assigned_to?: string }) => {
  const res = await axiosInstance.post<MaintenanceRequest>(
    `/api/maintenancerequest/${requestId}/respond/`,
    payload
  );
  return res.data;
},
};
