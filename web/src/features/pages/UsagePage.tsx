import React, { useState, useMemo } from "react";
import PageLayout from "./PageLayout";
import UsageLineChart from "../components/UsageLineChart";
import { useUsage } from "../hooks/useUsage";
import type { PeriodType } from "../services/usageService";
import type { TrendDataPoint } from "../types/usageTypes";

const UsagePage: React.FC = () => {
  const [period, setPeriod] = useState<PeriodType>("daily");
  const { loading, table, stats } = useUsage(period);

  // Generate chart data from table
  const chartData: TrendDataPoint[] = useMemo(() => {
    if (!table || table.length === 0) return [];

    return table.map((row, index) => ({
      id: row.componentId ?? `row-${index}`,
      periodStart: row.timestamp ?? new Date().toISOString(), // use actual timestamp if available
      periodEnd: row.timestamp ?? new Date().toISOString(),
      periodType: period,
      totalEnergy: row.energy ?? 0,
      avgPower: row.avgPower ?? 0,
      peakPower: row.peakPower ?? 0,
    }));
  }, [table, period]);

  return (
    <PageLayout initialSection={{ parent: "Usage" }}>
      <div className="content-container p-4">
        {/* Header */}
        <div className="usage-header flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold">Usage | {period}</h2>
          <div className="flex items-center gap-4">
            <select
              value={period}
              onChange={(e) => setPeriod(e.target.value as PeriodType)}
              className="border rounded px-2 py-1"
            >
              <option value="daily">Daily</option>
              <option value="weekly">Weekly</option>
              <option value="monthly">Monthly</option>
            </select>
            <span className="date-picker text-sm text-gray-600">
              13 Aug, 2025 – 19 Aug, 2025
            </span>
          </div>
        </div>

        {/* Loading */}
        {loading && <p>Loading usage data...</p>}

        {!loading && (
          <>
            {/* Chart */}
            <div className="usage-chart-container mb-8 h-72">
              <UsageLineChart data={chartData} />
            </div>

            {/* Stats */}
            {stats && (
              <div className="stats-boxes flex flex-col md:flex-row gap-4 mb-8">
                <div className="stats-box bg-gray-100 p-4 rounded shadow flex-1 text-center">
                  <p className="stat-number text-2xl font-bold">
                    {stats.totalUsage.toFixed(2)} kWh
                  </p>
                  <p className="stat-label text-gray-600">Total Usage</p>
                </div>
                <div className="stats-box bg-gray-100 p-4 rounded shadow flex-1 text-center">
                  <p className="stat-number text-2xl font-bold">
                    {stats.avgDaily.toFixed(2)} kWh
                  </p>
                  <p className="stat-label text-gray-600">Avg Daily</p>
                </div>
                <div className="stats-box bg-gray-100 p-4 rounded shadow flex-1 text-center">
                  <p className="stat-number text-2xl font-bold">
                    ${stats.totalCost.toFixed(2)}
                  </p>
                  <p className="stat-label text-gray-600">Total Cost</p>
                </div>
              </div>
            )}

            {/* Usage Table */}
            <div className="overflow-x-auto">
              <table className="w-full table-auto border-collapse border border-gray-300">
                <thead>
                  <tr className="bg-gray-200">
                    <th className="border border-gray-300 px-2 py-1">Component</th>
                    <th className="border border-gray-300 px-2 py-1">Usage (kWh)</th>
                    <th className="border border-gray-300 px-2 py-1">Avg Power (kW)</th>
                    <th className="border border-gray-300 px-2 py-1">Peak Power (kW)</th>
                    <th className="border border-gray-300 px-2 py-1">Readings</th>
                    <th className="border border-gray-300 px-2 py-1">Anomalies</th>
                  </tr>
                </thead>
                <tbody>
                  {table.length > 0 ? (
                    table.map((row) => (
                      <tr key={row.componentId} className="hover:bg-gray-50">
                        <td className="border border-gray-300 px-2 py-1">{row.componentId}</td>
                        <td className="border border-gray-300 px-2 py-1">{row.energy.toFixed(2)}</td>
                        <td className="border border-gray-300 px-2 py-1">{row.avgPower.toFixed(2)}</td>
                        <td className="border border-gray-300 px-2 py-1">{row.peakPower.toFixed(2)}</td>
                        <td className="border border-gray-300 px-2 py-1">{row.readings}</td>
                        <td className="border border-gray-300 px-2 py-1">{row.anomalies}</td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={6} className="text-center py-4 text-gray-500">
                        No component usage found
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </>
        )}
      </div>
    </PageLayout>
  );
};

export default UsagePage;
