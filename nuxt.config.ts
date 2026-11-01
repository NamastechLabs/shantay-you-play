// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },

  modules: ['@nuxtjs/supabase'],

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

  runtimeConfig: {
    public: {
      runwayLooksBucket: 'runway-looks',
    },
  },
})
