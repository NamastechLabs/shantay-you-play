import type { H3Event } from 'h3'

const LOOPBACK_HOSTS = ['localhost', '127.0.0.1', '[::1]']
const TUNNEL_SUFFIX = '.trycloudflare.com'

/**
 * Guards the debugging endpoints under /api/dev: they only exist in `nuxt dev`
 * and only answer on loopback, otherwise they look like any unknown route.
 * A Cloudflare tunnel (to debug on a phone) is accepted only when
 * `NUXT_DEV_ALLOW_TUNNEL=true` is set, which belongs in `.env.local` next to the local
 * database: through a public URL these endpoints let anyone sign in as anyone.
 */
export function assertDevOnly(event: H3Event): void {
  const { hostname } = getRequestURL(event)
  const allowedHost = LOOPBACK_HOSTS.includes(hostname)
    || (hostname.endsWith(TUNNEL_SUFFIX) && useRuntimeConfig(event).devAllowTunnel === true)

  if (!import.meta.dev || !allowedHost) {
    throw createError({ statusCode: 404, statusMessage: 'Not Found' })
  }
}
