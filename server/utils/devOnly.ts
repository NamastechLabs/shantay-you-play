import type { H3Event } from 'h3'

const LOOPBACK_HOSTS = ['localhost', '127.0.0.1', '[::1]']

/**
 * Guards the debugging endpoints under /api/dev: they only exist in `nuxt dev`
 * and only answer on loopback, otherwise they look like any unknown route.
 */
export function assertDevOnly(event: H3Event): void {
  if (!import.meta.dev || !LOOPBACK_HOSTS.includes(getRequestURL(event).hostname)) {
    throw createError({ statusCode: 404, statusMessage: 'Not Found' })
  }
}
