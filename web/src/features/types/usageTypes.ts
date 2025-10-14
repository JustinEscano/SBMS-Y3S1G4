// Raw row returned by /api/energysummary/
export interface EnergySummaryRow {
  id: string;
  period_start: string; // ISO timestamp
  total_energy: number; // kWh
  avg_power: number;    // kW
  peak_power: number;   // kW
  component?: {
    id: string;
    equipment?: {
      id: string;
      name: string;
      mode: string; // "HVAC" | "Lighting" | "Security"
    };
  };
  component_id?: string; // ensure grouping
}

// Trend data used in charts
export interface TrendDataPoint {
  id: string;
  periodStart: string; // use this instead of timestamp
  periodEnd: string;
  periodType: "daily" | "weekly" | "monthly";
  totalEnergy: number;
  avgPower: number;
  peakPower: number;
}


// Stats summary
export interface UsageStats {
  totalUsage: number;
  avgDaily: number;
  totalCost: number;
}

// Table row for equipment usage
export interface UsageTableRow {
  equipment: string;
  usage: number;
  cost: number;
}
