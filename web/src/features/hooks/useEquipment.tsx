import { useEffect, useState } from "react";
import { equipmentService } from "../services/equipmentService";
import type { Equipment } from "../types/dashboardTypes";

export const useEquipment = () => {
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [loading, setLoading] = useState(true);

  // fetch all
  const fetchEquipment = async () => {
    setLoading(true);
    try {
      const data = await equipmentService.getAll();
      setEquipment(data);
    } catch (err) {
      console.error("Failed to fetch equipment:", err);
    } finally {
      setLoading(false);
    }
  };

  // CRUD wrappers
  const addEquipment = async (payload: Partial<Equipment>) => {
    try {
      const created = await equipmentService.create(payload);
      setEquipment((prev) => [...prev, created]);
      return created;
    } catch (err) {
      console.error("Failed to add equipment:", err);
      throw err;
    }
  };

  const updateEquipment = async (id: string, payload: Partial<Equipment>) => {
    try {
      const updated = await equipmentService.update(id, payload);
      setEquipment((prev) => prev.map((e) => (e.id === id ? { ...e, ...updated } : e)));
      return updated;
    } catch (err) {
      console.error("Failed to update equipment:", err);
      throw err;
    }
  };

  const deleteEquipment = async (id: string) => {
    try {
      await equipmentService.remove(id);
      setEquipment((prev) => prev.filter((e) => e.id !== id));
    } catch (err) {
      console.error("Failed to delete equipment:", err);
      throw err;
    }
  };

  useEffect(() => {
    fetchEquipment();
  }, []);

  return {
    equipment,
    loading,
    refetch: fetchEquipment,
    addEquipment,
    updateEquipment,
    deleteEquipment,
  };
};
