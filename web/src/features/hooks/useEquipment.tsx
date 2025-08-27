import { useEffect, useState } from "react";
import { equipmentService } from "../services/equipmentService";
import type { Equipment } from "../types/equipmentTypes";

export const useEquipment = () => {
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchEquipment = async () => {
    setLoading(true);
    try {
      const data = await equipmentService.getAll();
      setEquipment(data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEquipment();
  }, []);

  return { equipment, loading, refetch: fetchEquipment };
};