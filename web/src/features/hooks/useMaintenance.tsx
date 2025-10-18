import { useState, useEffect, useCallback } from "react";
import type { MaintenanceRequest } from "../types/dashboardTypes";
import { maintenanceService } from "../services/maintenanceService";
  // CRUD wrappers (local state is updated immediately, no refetch)
import { useRef } from "react";

export const useMaintenanceRequests = () => {
  const [requests, setRequests] = useState<MaintenanceRequest[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  // Fetch all requests
  const fetchRequests = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await maintenanceService.getAll();
      setRequests(data);
    } catch (err: any) {
      console.error("Failed to fetch maintenance requests:", err);
      setError(err?.message || "Failed to fetch maintenance requests");
    } finally {
      setLoading(false);
    }
  }, []);

const addRequestLock = useRef(false);

const addRequest = useCallback(async (payload: Partial<MaintenanceRequest>) => {
  // prevent duplicate adds
  if (addRequestLock.current) {
    console.log("Add request in progress, ignoring duplicate.");
    return;
  }
  addRequestLock.current = true;

  try {
    const created = await maintenanceService.create(payload);
    setRequests((prev) => [...prev, created]);
    return created;
  } catch (err) {
    console.error("Failed to add maintenance request:", err);
    throw err;
  } finally {
    addRequestLock.current = false;
  }
}, []);

  const updateRequest = useCallback(async (id: string, payload: Partial<MaintenanceRequest>) => {
    try {
      const updated = await maintenanceService.update(id, payload);
      setRequests((prev) =>
        prev.map((r) => (r.id === id ? { ...r, ...updated } : r))
      );
      return updated;
    } catch (err) {
      console.error("Failed to update maintenance request:", err);
      throw err;
    }
  }, []);

  const deleteRequest = useCallback(async (id: string) => {
    try {
      await maintenanceService.delete(id);
      setRequests((prev) => prev.filter((r) => r.id !== id));
    } catch (err) {
      console.error("Failed to delete maintenance request:", err);
      throw err;
    }
  }, []);

  // Initial load
  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

  return {
    requests,
    loading,
    error,
    refetch: fetchRequests, // still exposed if you ever want a full reload
    addRequest,
    updateRequest,
    deleteRequest,
  };
};
