import axiosInstance from "../../service/AppService.tsx";
export type PeriodType = "daily" | "weekly" | "monthly";

export interface EnergySummary {
  id: string;
  period_start: string;
  period_end: string;
  period_type: PeriodType;
  total_energy: number;
  avg_power: number;
  peak_power: number;
  reading_count: number;
  anomaly_count: number;
  created_at: string;
  component_id: string;
  room_id: string;
}

// Billing calculation (client-side since no API)
export const calculateEnergyCost = (totalEnergy: number, periodType: PeriodType) => {
  const rate = 0.12; // Fixed rate like COST_PER_KWH
  return {
    total_cost: totalEnergy * rate,
    effective_rate: rate,
    currency: 'PHP',
    details: [],
  };
};

export async function fetchEnergySummaries(roomId?: string): Promise<EnergySummary[]> {
  let url = "/api/energysummary/";
  if (roomId) {
    url += `?room_id=${roomId}`;
  }
  const res = await axiosInstance.get<EnergySummary[]>(url);
  return res.data;
}

export async function getUsageTable(roomId: string, periodType: PeriodType) {
  const all = await fetchEnergySummaries(roomId);
  return all
    .filter((row) => row.period_type === periodType && row.room_id === roomId)
    .map((row) => ({
      componentId: row.component_id,
      energy: row.total_energy,
      avgPower: row.avg_power,
      peakPower: row.peak_power,
      readings: row.reading_count,
      anomalies: row.anomaly_count,
      periodStart: row.period_start,
      periodEnd: row.period_end,
    }));
}

export async function getUsageChart(roomId: string, periodType: PeriodType) {
  const all = await fetchEnergySummaries(roomId);
  const filtered = all.filter((row) => row.period_type === periodType && row.room_id === roomId);

  const grouped: Record<string, { x: string; y: number }[]> = {};

  filtered.forEach((row) => {
    if (!grouped[row.component_id]) {
      grouped[row.component_id] = [];
    }
    grouped[row.component_id].push({
      x: row.period_start,
      y: row.total_energy,
    });
  });

  return Object.entries(grouped).map(([componentId, data]) => ({
    id: componentId,
    data: data.sort((a, b) => new Date(a.x).getTime() - new Date(b.x).getTime()),
  }));
}

export async function getUsageStats(roomId: string, periodType: PeriodType) {
  const all = await fetchEnergySummaries(roomId);
  const filtered = all.filter((row) => row.period_type === periodType && row.room_id === roomId);

  const totalUsage = filtered.reduce((sum, r) => sum + r.total_energy, 0);

  let days = 1;
  if (periodType === "weekly") days = 7;
  if (periodType === "monthly") days = 30;

  const billing = calculateEnergyCost(totalUsage, periodType);

  return {
    totalUsage,
    avgDaily: totalUsage / days,
    ...billing,
  };
}