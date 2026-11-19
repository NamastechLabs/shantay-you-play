/**
 * "Install the app" state (DRG-18). Everything here is client-only: until the page is mounted
 * nothing can be installed, so server and client markup match.
 * - Android / Chrome / Edge: the browser fires `beforeinstallprompt` (handled by @vite-pwa/nuxt as `$pwa`)
 *   and the install dialog is opened from our own menu item.
 * - iPhone / iPad: there is no install event; we explain Share > "Añadir a pantalla de inicio".
 * - Already installed (standalone) or an in-app browser (Instagram, WhatsApp...): nothing is offered.
 */
export function useInstallApp() {
  const nuxtApp = useNuxtApp()
  const mounted = useState('install-app-mounted', () => false)
  const iosHintOpen = useState('install-app-ios-hint', () => false)
  const standalone = ref(false)
  const ios = ref(false)
  const inAppBrowser = ref(false)

  onMounted(() => {
    const ua = navigator.userAgent
    const iPadOs = navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1
    ios.value = /iPhone|iPad|iPod/i.test(ua) || iPadOs
    inAppBrowser.value = /FBAN|FBAV|Instagram|Line\/|WhatsApp|Twitter|TikTok|Snapchat/i.test(ua)
    standalone.value
      = window.matchMedia('(display-mode: standalone)').matches
      || (navigator as Navigator & { standalone?: boolean }).standalone === true
    mounted.value = true
  })

  const pwa = nuxtApp.$pwa as { showInstallPrompt?: boolean, isPWAInstalled?: boolean, install?: () => Promise<unknown> } | undefined

  /** The browser can show its own install dialog */
  const canPrompt = computed(() => mounted.value && !standalone.value && !!pwa?.showInstallPrompt && !pwa?.isPWAInstalled)
  /** iPhone / iPad in a real browser: show the manual steps */
  const showIosHint = computed(() => mounted.value && !standalone.value && ios.value && !inAppBrowser.value && !canPrompt.value)
  const canInstall = computed(() => canPrompt.value || showIosHint.value)

  async function install(): Promise<void> {
    if (canPrompt.value) await pwa?.install?.()
    else if (showIosHint.value) iosHintOpen.value = true
  }

  return { canInstall, install, iosHintOpen }
}
