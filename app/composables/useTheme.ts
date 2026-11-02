/**
 * Current UI theme, persisted in a cookie so the server renders the right
 * theme from the first byte (no flash of the default one).
 */
export function useTheme() {
  const cookie = useCookie<string>('theme', {
    default: () => DEFAULT_THEME,
    maxAge: 60 * 60 * 24 * 365,
    sameSite: 'lax',
  })

  const theme = computed<ThemeName>({
    get: () => (isTheme(cookie.value) ? cookie.value : DEFAULT_THEME),
    set: (value) => {
      cookie.value = value
    },
  })

  return { theme }
}
