// ✅ Strict equipment hardware types from backend
export type EquipmentType =
  | "esp32"
  | "sensor"
  | "actuator"
  | "controller"
  | "monitor";

// ✅ Mode is the dashboard category
export type EquipmentMode = "hvac" | "lighting" | "security";

// ✅ Mapping of allowed hardware types per dashboard
export const MODE_TYPE_MAP: Record<EquipmentMode, EquipmentType[]> = {
  hvac: ["esp32", "monitor"],
  security: ["sensor"],
  lighting: ["actuator", "controller"],
};

export interface Equipment {
  id: string;
  name: string;
  room: string; // UUID of Room
  type: EquipmentType; // Hardware type
  status: "online" | "offline" | "maintenance" | "error";
  qr_code: string;
  created_at: string;
}

export interface Room {
  id: string;
  name: string;
  floor: number;
  capacity: number;
  type: string;
  created_at: string;
  equipment?: Equipment[];
}

export interface MaintenanceRequest {
  id: string;
  user: string; // UUID of user
  equipment: string; // UUID of equipment
  issue: string;
  status: "Pending" | "In Progress" | "Resolved";
  scheduled_date: string;
  resolved_at?: string | null;
  created_at: string;
}

export interface User {
  id: string;              // UUID
  username: string;
  email: string;
  role: string;
  created_at: string;      // ISO datetime string
  last_login?: string | null; // can be null
};

export type EquipmentStatus = "online" | "offline" | "maintenance" | "error";
