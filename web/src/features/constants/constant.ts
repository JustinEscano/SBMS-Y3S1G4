<<<<<<< HEAD
=======
// constants/constant.ts

// 🔹 Enum-like object with lowercase values
>>>>>>> web-only
export const PAGE_TYPES = {
  HVAC: "hvac",
  LIGHTING: "lighting",
  SECURITY: "security",
} as const;

<<<<<<< HEAD
export type PageType = typeof PAGE_TYPES[keyof typeof PAGE_TYPES];
=======
// 🔹 PageType is derived automatically from PAGE_TYPES values
export type PageType = (typeof PAGE_TYPES)[keyof typeof PAGE_TYPES];

// 🔹 Equipment types mapping for each page
export const PAGE_TYPE_MAP: Record<PageType, string[]> = {
  [PAGE_TYPES.HVAC]: ["thermostat", "air_quality_sensor", "humidity_sensor"],
  [PAGE_TYPES.LIGHTING]: ["light_sensor", "energy_meter"],
  [PAGE_TYPES.SECURITY]: ["motion_sensor", "camera", "door_lock"],
};
>>>>>>> web-only
