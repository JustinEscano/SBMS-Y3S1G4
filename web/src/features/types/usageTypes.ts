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