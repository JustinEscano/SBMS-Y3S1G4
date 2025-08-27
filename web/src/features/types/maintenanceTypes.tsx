export interface MaintenanceRequest {
  id: string;
  user: string; // UUID of user
  equipment: string; // UUID of equipment
  issue: string;
  status: string;
  scheduled_date: string;
  resolved_at?: string | null;
  created_at: string;
}