// Raw sensor log data (from ESP32 or SensorLog model)
export interface SensorData {
  equipment_id: string;
  equipment_name?: string;
  device_id: string;
  status: string;
  recorded_at: string | null;

  // Equipment type for filtering (esp32, sensor, actuator, etc.)
  type?: string;

  // HVAC
  temperature?: number;
  humidity?: number;

  // Lighting
  light_level?: boolean;
  energy_usage?: number;

  // Security
  motion_detect?: boolean;
  camera_status?: string;
  component_name?: string;
}

export interface ESP32Response {
  success: boolean;
  data: SensorData[];
}

// Analytics: summary of equipment in a room
export interface EquipmentSummary {
  id: string; // Equipment.id (UUID)
  name: string; // Equipment.name
  status: string; // Equipment.status (online/offline/etc.)
  latest_log?: {
    temperature?: number;
    humidity?: number;
    light_level?: number;
    energy_usage?: number;
    motion_detected?: boolean;
    recorded_at?: string;
  };
}

// Analytics: grouped by room
export interface RoomAnalytics {
  room: {
    id: string;
    name: string;
  };
  overall_status: {
    equipment_count: number;
    online: number;
    offline: number;
    maintenance: number;
    error: number;
  };
  equipment_by_mode: {
    hvac?: EquipmentSummary[];
    lighting?: EquipmentSummary[];
    security?: EquipmentSummary[];
  };
}

export interface RoomAnalyticsItem {
  period_start: string;
  period_end: string;
  period_type: string;
  total_energy: number;
  avg_power: number;
  peak_power: number;
  reading_count: number;
  anomaly_count: number;
  total_cost: number;
  currency?: string;
}

