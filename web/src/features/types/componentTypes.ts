export type ComponentType =
  | "PZEM"           // Power & energy measurement (voltage/current/power/energy)
  | "DHT22"          // Temperature & humidity sensor
  | "PHOTORESISTOR"  // Light detection sensor
  | "MOTION"         // PIR motion detector
  | "HVAC"           // Air-conditioning or ventilation control
  | "GENERIC";       // Fallback for others

export interface Component {
  id: string;
  equipment: string; // equipment ID
  component_type: ComponentType;
  identifier: string;
  status: string;
  created_at: string;
}

