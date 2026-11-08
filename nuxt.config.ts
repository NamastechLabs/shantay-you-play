// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },

  modules: ['@nuxtjs/supabase'],

  css: ['~/assets/scss/main.scss'],

  app: {
    head: {
      title: 'Drag Race Game',
      htmlAttrs: { lang: 'es' },
      meta: [{ name: 'description', content: 'Drag Race Game: la competencia semanal de looks, pasarela y votación.' }],
      link: [
        { rel: 'icon', type: 'image/png', href: '/favicon.png' },
        { rel: 'apple-touch-icon', href: '/icon-192.png' },
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
