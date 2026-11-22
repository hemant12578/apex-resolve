export const modes = {
  explore: 'Explorer',
  communication: 'Communication',
  resolution: 'Resolution',
} as const;

export function homeMode(value: unknown): keyof typeof modes {
  return value === 'communication' || value === 'resolution' ? value : 'explore';
}
