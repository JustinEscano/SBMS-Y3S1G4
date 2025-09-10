export const PAGE_TYPES = {
  HVAC: "hvac",
  LIGHTING: "lighting",
  SECURITY: "security",
} as const;

export type PageType = typeof PAGE_TYPES[keyof typeof PAGE_TYPES];