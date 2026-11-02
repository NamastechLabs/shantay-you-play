/** UI themes. Each one is a set of CSS variables scoped by <html data-theme="..."> (see assets/scss/tokens). */
export const THEMES = ['y2k-camp', 'retro-glam', 'neon-nightclub'] as const

export type ThemeName = (typeof THEMES)[number]

export const DEFAULT_THEME: ThemeName = 'y2k-camp'

export const THEME_LABELS: Record<ThemeName, string> = {
  'y2k-camp': 'Y2K Camp',
  'retro-glam': 'Retro Glam',
  'neon-nightclub': 'Neon Nightclub',
}

export function isTheme(value: unknown): value is ThemeName {
  return typeof value === 'string' && (THEMES as readonly string[]).includes(value)
}
