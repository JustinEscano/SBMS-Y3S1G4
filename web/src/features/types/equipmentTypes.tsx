export interface Equipment {
  room_id: string;
  id: string;
  name: string;
  room: string; // UUID of Room
  type: string;
  status: string;
  qr_code: string;
  created_at: string;
}