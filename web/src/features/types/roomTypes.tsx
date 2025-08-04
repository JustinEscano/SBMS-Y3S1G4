export interface Equipment {
  id: string;
  name: string;
  room: string; // UUID of Room
  type: string;
  status: string;
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
  equipment?: Equipment[]; // optional if nested
}