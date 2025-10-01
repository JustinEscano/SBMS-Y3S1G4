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

// Cost per kWh (adjust to your business logic)
const COST_PER_KWH = 0.12;

async function fetchEnergySummaries(): Promise<EnergySummary[]> {
  const res = await axiosInstance.get<EnergySummary[]>("/api/energysummary/");
  return res.data;
}

export async function getUsageTable(periodType: PeriodType) {
  const all = await fetchEnergySummaries();
  return all
    .filter((row) => row.period_type === periodType)
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

/**
 * Chart data: time series per component
 */
export async function getUsageChart(periodType: PeriodType) {
  const all = await fetchEnergySummaries();
  const filtered = all.filter((row) => row.period_type === periodType);

  // group by component
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

  // return dataset for chart.js/recharts
  return Object.entries(grouped).map(([componentId, data]) => ({
    id: componentId,
    data: data.sort((a, b) => new Date(a.x).getTime() - new Date(b.x).getTime()),
  }));
}

/**
 * Stats data: totals for cards
 */
export async function getUsageStats(periodType: PeriodType) {
  const all = await fetchEnergySummaries();
  const filtered = all.filter((row) => row.period_type === periodType);

  const totalUsage = filtered.reduce((sum, r) => sum + r.total_energy, 0);

  // Figure out how many days this period covers
  let days = 1;
  if (periodType === "weekly") days = 7;
  if (periodType === "monthly") days = 30;

  return {
    totalUsage,
    avgDaily: totalUsage / days,
    totalCost: totalUsage * COST_PER_KWH,
  };
}
