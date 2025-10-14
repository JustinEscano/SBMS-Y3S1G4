// Raw sensor log data (from ESP32 or SensorLog model)
export interface SensorData {
  equipment_id: string;
  equipment_name: string;
  device_id: string;
  status: string;
  recorded_at: string;

  // Equipment type for filtering (esp32, sensor, actuator, etc.)
  type?: string;

  // HVAC
  temperature?: number;
  humidity?: number;

  // Lighting
  light_level?: number;
  energy_usage?: number;

  // Security
  motion_detected?: boolean;
  camera_status?: string;
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
