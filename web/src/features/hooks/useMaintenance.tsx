import { useEffect, useState } from 'react';
import type { MaintenanceRequest } from '../types/dashboardTypes';
import { maintenanceService } from '../services/maintenanceService';

export const useMaintenanceRequests = () => {
  const [requests, setRequests] = useState<MaintenanceRequest[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchRequests = async () => {
      try {
        const data = await maintenanceService.getAll();
        setRequests(data);
      } catch (error) {
        console.error("Failed to fetch maintenance requests:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchRequests();
  }, []);

  return { requests, loading };
};