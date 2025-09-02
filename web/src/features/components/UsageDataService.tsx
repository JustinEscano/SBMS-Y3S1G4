export type UsageCategory = "HVAC" | "Lighting" | "Security" | "Maintenance";

interface UsageData {
  icons: string[];
  labels: string[];
  values: number[];
}

export const fetchUsageData = (category: UsageCategory): UsageData => {
  switch (category) {
    case "HVAC":
      return {
        icons: ["❄️", "✅", "❌"],
        labels: ["Total HVAC Units", "Active Units", "Inactive Units"],
        values: [120, 90, 30, 45, 60, 80, 70],
      };
    case "Lighting":
      return {
        icons: ["💡", "✅", "❌"],
        labels: ["Total Lighting Units", "Active Units", "Inactive Units"],
        values: [130, 250, 50, 80, 90, 100, 110],
      };
    case "Security":
      return {
        icons: ["🔒", "✅", "❌"],
        labels: ["Total Security Units", "Active Units", "Inactive Units"],
        values: [80, 65, 15, 20, 30, 40, 50],
      };
    case "Maintenance":
      return {
        icons: ["🛠️", "⏳", "✅"],
        labels: ["Total Requests", "Pending", "Resolved"],
        values: [150, 40, 110, 30, 50, 70, 90],
      };
    default:
      return { icons: [], labels: [], values: [] };
  }
};
