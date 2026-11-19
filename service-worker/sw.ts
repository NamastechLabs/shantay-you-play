/// <reference lib="webworker" />
import { clientsClaim } from 'workbox-core'
import { cleanupOutdatedCaches, precacheAndRoute } from 'workbox-precaching'
import { registerRoute, setCatchHandler } from 'workbox-routing'
import { CacheFirst, StaleWhileRevalidate } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'
import { CacheableResponsePlugin } from 'workbox-cacheable-response'

declare const self: ServiceWorkerGlobalScope & { __WB_MANIFEST: Array<string | { url: string, revision: string | null }> }

/**
 * Caching rules (DRG-18). The app is live (stage, votes, runway) and the theme is rendered
 * server-side from a cookie, so only static, hashed assets are cached:
 * - precache: the build's /_nuxt/ JS, CSS and fonts and the icons
 * - /offline.html is cached on install, apart from the precache (which would rename it to /offline, a page that redirects to /login)
 * - Google Fonts: stylesheet stale-while-revalidate, font files cache-first
 * - everything else (HTML pages, Supabase, /api, images from Storage) is NOT handled here:
 *   the browser goes straight to the network, as if there were no service worker.
 * - when a page can't load because the device is offline, /offline.html is shown.
 */

// A new service worker takes over right away (registerType: 'autoUpdate')
self.skipWaiting()
clientsClaim()

const OFFLINE_CACHE = 'offline-page'
self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(OFFLINE_CACHE).then(cache => cache.add('/offline.html')))
})

cleanupOutdatedCaches()
precacheAndRoute(self.__WB_MANIFEST)

registerRoute(
  ({ url }) => url.origin === 'https://fonts.googleapis.com',
  new StaleWhileRevalidate({ cacheName: 'google-fonts-styles' }),
)

registerRoute(
  ({ url }) => url.origin === 'https://fonts.gstatic.com',
  new CacheFirst({
    cacheName: 'google-fonts-files',
    plugins: [
      new CacheableResponsePlugin({ statuses: [0, 200] }),
      new ExpirationPlugin({ maxEntries: 30, maxAgeSeconds: 60 * 60 * 24 * 365 }),
    ],
  }),
)

// Page navigations are never answered from a cache; they only fall back to /offline.html on failure.
// (A catch handler only runs for requests that matched a route and failed, so route navigations explicitly.)
registerRoute(
  ({ request }) => request.mode === 'navigate',
  async ({ request }) => fetch(request),
)

setCatchHandler(async ({ request }) => {
  if (request.destination === 'document') {
    const offline = await caches.match('/offline.html', { cacheName: OFFLINE_CACHE })
    if (offline) return offline
  }
  return Response.error()
})
