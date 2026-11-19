// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },

  modules: ['@nuxtjs/supabase', '@vite-pwa/nuxt'],

  css: ['~/assets/scss/main.scss'],

  routeRules: {
    // These pages used to live at Spanish paths: keep old links working
    '/novedades': { redirect: { to: '/release-notes', statusCode: 301 } },
    '/votacion-bandas': { redirect: { to: '/band-voting', statusCode: 301 } },
    // The service worker and the manifest must always be revalidated so new deploys reach installed apps
    '/sw.js': { headers: { 'cache-control': 'public, max-age=0, must-revalidate' } },
    '/manifest.webmanifest': { headers: { 'cache-control': 'public, max-age=0, must-revalidate' } },
  },

  app: {
    head: {
      title: 'Shantay You Play',
      htmlAttrs: { lang: 'es' },
      meta: [{ name: 'description', content: 'Shantay You Play: la competencia semanal de looks, pasarela y votación.' }],
      link: [
        { rel: 'icon', type: 'image/png', href: '/favicon.png' },
        { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        {
          // One family per theme (Y2K Camp, Retro Glam, Neon Nightclub); browsers only download the faces in use
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700;800&family=Playfair+Display:ital,wght@0,700;1,900&family=DM+Sans:wght@400;500;600;700&family=Bungee&family=Inter:wght@400;500;600;700&display=swap',
        },
      ],
    },
  },

  // Installable app (DRG-18). Only static assets are cached (see service-worker/sw.ts); pages and data always use the network.
  pwa: {
    strategies: 'buildSW',
    filename: 'sw.js',
    registerType: 'autoUpdate',
    manifest: {
      name: 'Shantay You Play',
      short_name: 'Shantay',
      description: 'La competencia semanal de looks, pasarela y votación.',
      lang: 'es',
      id: '/',
      start_url: '/',
      scope: '/',
      display: 'standalone',
      // Default theme (Y2K Camp); the browser bar color follows the active theme at runtime (app.vue)
      theme_color: '#eaf4ff',
      background_color: '#eaf4ff',
      icons: [
        { src: '/pwa-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/pwa-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/pwa-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
      ],
    },
    buildSW: {
      swSrc: 'service-worker/sw.ts',
      globPatterns: ['_nuxt/**/*.{js,css,woff2}', '*.png'],
      globIgnores: ['_nuxt/builds/**'],
      // The module also adds the Nuxt build-meta JSON, which we ignore on purpose (it must always come from the network)
      globStrict: false,
    },
    client: { installPrompt: true },
    // The service worker is off in `nuxt dev`; try it with `pnpm build && pnpm preview`
    devOptions: { enabled: false },
  },

  // @nuxtjs/supabase reads SUPABASE_URL and SUPABASE_KEY (anon/publishable key) from .env
  supabase: {
    // Generated with `supabase gen types typescript`; `~` resolves to app/ in Nuxt 4
    types: '~/types/database.types.ts',

    // Global auth guard: unauthenticated users are sent to /login
    redirect: true,
    redirectOptions: {
      login: '/login',
      // Google OAuth returns here; must also be listed under Auth > URL Configuration in Supabase
      callback: '/confirm',
      exclude: [],
      // Send users back to the page they originally requested after login
      saveRedirectToCookie: true,
    },
  },

  // Dev only: let HTTPS tunnels (Cloudflare) reach the dev server, e.g. to test sharing on a phone
  vite: {
    // The WebP WASM encoder resolves its .wasm file relative to its own module, which pre-bundling breaks
    optimizeDeps: { exclude: ['@jsquash/webp'] },
    server: {
      allowedHosts: ['.trycloudflare.com'],
    },
  },

  runtimeConfig: {
    // Server only; set NUXT_DEV_ALLOW_TUNNEL=true in .env.local to let /api/dev answer through a Cloudflare tunnel
    devAllowTunnel: false,
    // Server only; bearer token for /api/commentary/*. Set NUXT_COMMENTARY_API_TOKEN; unset = routes answer 404
    commentaryApiToken: '',
    // @nuxtjs/supabase copies these env vars into the bundle at BUILD time (and Netlify's secret scan then
    // fails the build). Declaring them empty keeps the value out of the output; at runtime
    // NUXT_SUPABASE_SECRET_KEY still overrides it.
    supabase: { secretKey: '', serviceKey: '' },
    public: {
      runwayLooksBucket: 'runway-looks',
      runwayIntroBucket: 'runway-intro',
      avatarsBucket: 'participant-avatars',
    },
  },
})
