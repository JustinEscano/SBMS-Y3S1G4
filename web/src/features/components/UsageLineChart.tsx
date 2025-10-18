// components/UsageLineChart.tsx
import React from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Title,
  Tooltip,
  Legend,
  Filler,
} from "chart.js";
import type { TrendDataPoint } from "../types/usageTypes";

ChartJS.register(
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Title,
  Tooltip,
  Legend,
  Filler
);

interface UsageLineChartProps {
  data: TrendDataPoint[];
}

const UsageLineChart: React.FC<UsageLineChartProps> = ({ data }) => {
  if (!data || data.length === 0) {
    return <p className="text-gray-500 text-center">No trend data available</p>;
  }

  // Ensure valid dates and numbers
  const labels = data.map((d) => {
    const date = new Date(d.periodStart);
    return isNaN(date.getTime())
      ? "Invalid date"
      : date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
  });

  const chartData = {
    labels,
    datasets: [
      {
        label: "Total Energy (kWh)",
        data: data.map((d) => Number(d.totalEnergy) || 0),
        borderColor: "rgba(75, 192, 192, 1)",
        backgroundColor: "rgba(75, 192, 192, 0.2)",
        fill: true,
        tension: 0.3,
      },
      {
        label: "Avg Power (kW)",
        data: data.map((d) => Number(d.avgPower) || 0),
        borderColor: "rgba(255, 206, 86, 1)",
        backgroundColor: "rgba(255, 206, 86, 0.2)",
        fill: false,
        tension: 0.3,
      },
      {
        label: "Peak Power (kW)",
        data: data.map((d) => Number(d.peakPower) || 0),
        borderColor: "rgba(255, 99, 132, 1)",
        backgroundColor: "rgba(255, 99, 132, 0.2)",
        fill: false,
        tension: 0.3,
      },
    ],
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false, // allow container height to work
    plugins: {
      legend: { position: "top" as const },
      title: { display: true, text: "Energy Usage Trends" },
    },
    scales: {
      x: { title: { display: true, text: "Date" } },
      y: { title: { display: true, text: "kWh / kW" } },
    },
  };

  return <Line data={chartData} options={options} />;
};

export default UsageLineChart;
