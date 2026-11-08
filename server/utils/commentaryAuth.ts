import type { H3Event } from 'h3'

/** Constant-time string comparison (no early exit on the first differing byte). */
function safeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a)
  const y = new TextEncoder().encode(b)
  let diff = x.length ^ y.length
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0)
  return diff === 0
}

/**
 * Guards /api/commentary/*: a shared secret sent as `Authorization: Bearer <token>`
 * (or `?token=` for a quick browser check). The endpoints read with the service role, so
 * without a configured token they behave like any unknown route.
 */
export function assertCommentaryToken(event: H3Event): void {
  const expected = useRuntimeConfig(event).commentaryApiToken
  if (!expected) throw createError({ statusCode: 404, statusMessage: 'Not Found' })

  const header = getHeader(event, 'authorization') ?? ''
  const provided = header.startsWith('Bearer ') ? header.slice(7) : String(getQuery(event).token ?? '')

  if (!safeEqual(provided, expected)) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
  }
}
