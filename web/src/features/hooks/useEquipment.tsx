import { useEffect, useState } from 'react';
import type { Equipment } from '../types/equipmentTypes';
import { getAllEquipment } from '../services/equipmentService';

export const useEquipment = () => {
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchEquipment = async () => {
      try {
        const data = await getAllEquipment();
        setEquipment(data);
      } catch (error) {
        console.error('Failed to fetch equipment:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchEquipment();
  }, []);

  return { equipment, loading };
};