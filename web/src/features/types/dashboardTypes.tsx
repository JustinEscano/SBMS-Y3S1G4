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

export interface Attachment {
  id: string;                      // UUID
  maintenance_request: string;     // ID of the related maintenance request
  file: string;                    // URL to the uploaded file
  file_name: string;               // Original file name
  file_type: string;               // MIME type (e.g., "image/jpeg")
  uploaded_at: string;             // ISO datetime string
  uploaded_by?: string;            // User ID of uploader
  uploaded_by_name?: string;       // Optional: username of uploader
}

export interface MaintenanceRequest {
  id: string;
  user: string; // ID of the reporting user
  equipment: string; // ID of equipment
  issue: string;
  status: "pending" | "in_progress" | "resolved";
  scheduled_date: string;
  resolved_at?: string;
  assigned_to?: string;
  comments?: string;
  attachments: Attachment[];
  response?: string;
}

export interface User {
  id: string;              // UUID
  username: string;
  email: string;
  role_display: string;
  role: string;
  created_at: string;      // ISO datetime string
  last_login?: string | null; // can be null
  profile?: Profile;  // Optional to handle incomplete data
  full_name?: string;  // Direct on User if used that way; otherwise remove if nested under profile
  organization?: string;
  address?: string;
  profile_picture?: string;  // Assuming this is a URL string; use File | string if handling uploads
};

export type EquipmentStatus = "online" | "offline" | "maintenance" | "error";

export interface Profile {
  id?: string;
  full_name: string;
  organization: string;
  address: string;
  profile_picture?: string | File; // URL or File for upload
  created_at?: string;
  updated_at?: string;
}

// Optional: If Profile is nested in User responses
export interface UserWithProfile extends User {
  profile?: Profile;
}