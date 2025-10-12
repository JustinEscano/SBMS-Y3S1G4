import type { MaintenanceRequest } from "../types/dashboardTypes";

export const parseComments = (rawComments: string | undefined): { timestamp: string; user: string; role: string; message: string }[] => {
  if (!rawComments) return [];
  return rawComments
    .split('\n')
    .filter(line => line.trim() && line.startsWith('['))
    .map(line => {
      const match = line.match(/\[([^\]]+)\]\s*([^(\s]+)\s*\(([^)]+)\):\s*(.*)/);
      return match
        ? {
            timestamp: match[1],
            user: match[2],
            role: match[3],
            message: match[4].trim(),
          }
        : null;
    })
    .filter(Boolean) as any[];
};