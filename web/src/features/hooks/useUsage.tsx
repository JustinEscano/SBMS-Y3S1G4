import { useEffect, useState } from "react";
import type { PeriodType } from "../services/usageService";
import {
  getUsageTable,
  getUsageChart,
  getUsageStats,
} from "../services/usageService";

export function useUsage(periodType: PeriodType) {
  const [loading, setLoading] = useState(true);
  const [table, setTable] = useState<any[]>([]);
  const [chart, setChart] = useState<any[]>([]);
  const [stats, setStats] = useState<{
    totalUsage: number;
    avgDaily: number;
    totalCost: number;
  } | null>(null);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const [tableData, chartData, statsData] = await Promise.all([
          getUsageTable(periodType),
          getUsageChart(periodType),
          getUsageStats(periodType),
        ]);
        setTable(tableData);
        setChart(chartData);
        setStats(statsData);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [periodType]);

  return { loading, table, chart, stats };
}
