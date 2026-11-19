# Installable app (PWA)

Status: **implemented** (DRG-18). Installability only: there is no offline mode and no push notifications (see DRG-19 for those).

## What users get

- The site can be added to the home screen of Android, iPhone and iPad (and installed from desktop Chrome / Edge). It opens standalone, with the name "Shantay You Play", its own icon and no browser bar.
- An **"Instalar app"** item in the app menu (the burger drawer on phones, the user dropdown on wider screens). It only shows when the app can be installed and is not installed yet (`useInstallApp`):
  - **Android / Chrome / Edge:** the browser fires `beforeinstallprompt`; `@vite-pwa/nuxt` keeps it (`$pwa.showInstallPrompt`) and the item calls `$pwa.install()`.
  - **iPhone / iPad:** there is no install event, so the item opens `InstallAppModal` with the manual steps (Compartir → Añadir a pantalla de inicio). Not shown in in-app browsers (Instagram, WhatsApp...), where the steps do not exist.
  - **Already installed** (`display-mode: standalone` or `navigator.standalone`): hidden.
- The copy is in `app/utils/pwaContent.ts`; the help page has the section "Instala la app en tu móvil" (`app/utils/helpContent.ts`).

## Files

| File | What it does |
|---|---|
| `nuxt.config.ts` → `pwa` | Manifest, `buildSW` strategy, `registerType: 'autoUpdate'`, precache globs, install prompt on. Off in `nuxt dev` |
| `service-worker/sw.ts` | The service worker (workbox) |
| `public/offline.html` | Spanish page shown when a navigation fails because the device is offline |
| `public/pwa-192.png`, `pwa-512.png`, `pwa-maskable-512.png`, `apple-touch-icon.png` | Icons: the crowned "S" on an opaque lilac background (maskable has extra padding for Android's safe zone; iOS fills transparency with black) |
| `app/app.vue` | `<NuxtPwaAssets />` (adds the manifest link) and the `theme-color` meta |
| `app/composables/useInstallApp.ts`, `app/components/InstallAppModal.vue`, `app/components/AppNav.vue` | The install item and the iOS steps |

The `.png` icons `icon-192.png` / `icon-512.png` are kept: the brand "S" shown while photos load uses `icon-192.png`.

## Caching rules (important)

The app is live (stage, votes, runway) and the theme is rendered **server-side from a cookie**, so nothing dynamic is cached:

- **Precached** (versioned, replaced on every deploy): `_nuxt/**/*.{js,css,woff2}` and the root `.png` icons.
- **Google Fonts:** stylesheet stale-while-revalidate, font files cache-first.
- **`/offline.html`** is cached when the service worker installs. It is not in the precache on purpose: workbox renames `offline.html` to `/offline`, which is an app route that redirects to `/login`.
- **Everything else is not handled by the service worker:** HTML pages, Supabase, `/api` and Storage photos always go to the network. A failed navigation (offline) shows `/offline.html`.
- The Nuxt build metadata (`_nuxt/builds/`) is excluded so the app always learns about a new deploy.

## Updates

`registerType: 'autoUpdate'` plus `skipWaiting()` / `clientsClaim()`: a new service worker takes over on the next page load and replaces the precache. `/sw.js` and `/manifest.webmanifest` are served with `Cache-Control: public, max-age=0, must-revalidate` (`routeRules` in `nuxt.config.ts`, which Netlify turns into `_headers`), so installed apps always check for a new version.

## Browser bar color

`<meta name="theme-color">` is the default theme's page color (`#eaf4ff`, also the manifest's `theme_color` and `background_color`) on the server. After mount, `app.vue` reads `--color-page` of the active theme, so it follows the theme switcher without hardcoding any color. The manifest color cannot change per theme.

## Testing

1. `pnpm build`, then `node --env-file=.env .output/server/index.mjs` (the service worker is not active in `pnpm dev`).
2. DevTools → Application: manifest without warnings, service worker "activated", caches `workbox-precache-…`, `google-fonts-*` and `offline-page`; no HTML page in any cache.
3. DevTools → Network → Offline, then navigate: the "Sin conexión" page shows.
4. Lighthouse → "Installable".
5. On real devices (needs HTTPS, e.g. the deployed site or `pnpm tunnel:app`): install from Android Chrome and from iPhone Safari, then check **login (Google / Microsoft) and voting from the installed icon**. On iOS an installed app has its own storage, so a Safari session does not carry over.

## Notes

- iOS only supports installing from the browser's Share menu (Safari; Chrome and others since iOS 16.4).
- Push notifications on iOS only work for installed apps on iOS 16.4+; they are a separate ticket (DRG-19).
