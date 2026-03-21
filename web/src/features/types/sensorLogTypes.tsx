// src/types/sensorLogTypes.ts
export interface SensorData {
  id?: string;
  device_id?: string;
  equipment?: string;          // FK UUID from serializer
  equipment_id?: string;       // alias used in some places
  equipment_name?: string;
  component?: string;          // FK UUID from serializer
  component_name?: string;
  component_type?: string;

  // Sensor readings (match serializer field names exactly)
  status?: string;
  temperature?: number | null;
  humidity?: number | null;
  light_detected?: boolean | null;   // serializer uses 'light_detected' not 'light_level'
  motion_detected?: boolean | null;  // serializer uses 'motion_detected'
  energy_usage?: number | null;      // legacy/alias field
  voltage?: number | null;
  current?: number | null;
  power?: number | null;             // kW — used by power chart
  energy?: number | null;            // kWh cumulative — used by energy chart

  // Timestamps
  recorded_at?: string;
  pzem_recorded_at?: string;
  dht22_recorded_at?: string;
  photoresistor_recorded_at?: string;
  motion_recorded_at?: string;

  // Computed / joined fields (from esp32/sensor-data endpoint)
  room_id?: string;                  // present on sensor-data endpoint
  alerts?: number;                   // alert count from security processing

  [key: string]: any; // For any other backend fields not explicitly typed
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
