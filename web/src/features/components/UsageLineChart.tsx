import React, { useState, useEffect } from "react";
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
} from "chart.js";
import { fetchUsageData, type UsageCategory } from "./usageDataService";
import "./UsageLineChart.css";

ChartJS.register(LineElement, PointElement, CategoryScale, LinearScale, Title, Tooltip, Legend);

const categories: UsageCategory[] = ["HVAC", "Lighting", "Security", "Maintenance"];

const UsageLineChart: React.FC = () => {
  const [selectedCategory, setSelectedCategory] = useState<UsageCategory>("HVAC");
  const [chartData, setChartData] = useState<any>(null);
  const [usageDetails, setUsageDetails] = useState<{ icons: string[]; labels: string[]; values: number[] }>({
    icons: [],
    labels: [],
    values: [],
  });

  useEffect(() => {
    const data = fetchUsageData(selectedCategory);
    setUsageDetails({
      icons: data.icons,
      labels: data.labels,
      values: data.values,
    });
    setChartData({
      labels: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
      datasets: [
        {
          label: selectedCategory,
          data: data.values,
          borderColor: "#4B9CD3",
          backgroundColor: "rgba(75, 156, 211, 0.2)",
          fill: true,
          tension: 0.3,
        },
      ],
    });
  }, [selectedCategory]);

  const options = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      labels: {
        color: "#ffffff", // Legend text
      },
    },
    tooltip: {
      bodyColor: "#ffffff", // Tooltip text
      titleColor: "#ffffff",
    },
  },
  scales: {
    x: {
      ticks: {
        color: "#ffffff", // X-axis labels
      },
    },
    y: {
      ticks: {
        color: "#ffffff", // Y-axis labels
      },
      grid: {
        color: "rgba(255, 255, 255, 0.2)",
      },
    },
  },
};

  return (
    <div>        
      <div className="content-container">
        {/* Stat boxes */}
        <div className="stats-boxes">
          {usageDetails.labels.map((label, index) => (
            <div className="stat-box" key={index}>
              <div className="stat-icon">{usageDetails.icons[index]}</div>
              <div className="stat-info">
                <p className="stat-number">{usageDetails.values[index]}</p>
                <p className="stat-label">{label}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
        <div className="category-selector">
            <label htmlFor="category-select">Select Category:</label>
            <select
                id="category-select"
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value as UsageCategory)}
            >
                {categories.map((cat) => (
                <option key={cat} value={cat}>
                    {cat}
                </option>
                ))}
            </select>
        </div>
        <div className="line-chart">
            {chartData && <Line data={chartData} options={options} />}
        </div>
    </div>
  );
};

export default UsageLineChart;