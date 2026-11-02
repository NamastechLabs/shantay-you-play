/**
 * Time zone the runway time is shown and edited in. Fixed (instead of the
 * browser's) so server-rendered pages match the client and everyone sees the
 * same hour.
 */
export const RUNWAY_TIME_ZONE = 'Europe/Madrid'

/** "2026-11-05T20:00:00+00:00" -> "5 de noviembre, 21:00" */
export function formatRunwayDate(timestamp: string): string {
  return new Date(timestamp).toLocaleString('es', {
    day: 'numeric',
    month: 'long',
    hour: '2-digit',
    minute: '2-digit',
    timeZone: RUNWAY_TIME_ZONE,
  })
}

/** Offset (ms) of the runway time zone from UTC at the given instant. */
function zoneOffsetMs(instant: Date): number {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: RUNWAY_TIME_ZONE,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    }).formatToParts(instant).map(part => [part.type, part.value]),
  )
  const asUtc = Date.UTC(+parts.year!, +parts.month! - 1, +parts.day!, +parts.hour!, +parts.minute!, +parts.second!)
  return asUtc - Math.floor(instant.getTime() / 1000) * 1000
}

/** Timestamp -> value of an `<input type="datetime-local">` ("2026-11-05T21:00") in the runway time zone. */
export function toDatetimeLocal(timestamp: string): string {
  const instant = new Date(timestamp)
  return new Date(instant.getTime() + zoneOffsetMs(instant)).toISOString().slice(0, 16)
}

/** Value of an `<input type="datetime-local">` read in the runway time zone -> ISO timestamp. */
export function fromDatetimeLocal(value: string): string {
  const guess = Date.parse(`${value}:00Z`)
  // Second pass so the offset is the one in force at the resulting instant (daylight saving changes)
  const first = guess - zoneOffsetMs(new Date(guess))
  return new Date(guess - zoneOffsetMs(new Date(first))).toISOString()
}

/** A runway is named after its categories: "Denim · Alfombra roja". */
export function runwayTitle(categories: readonly { title: string }[]): string {
  return categories.map(category => category.title).join(' · ') || 'Pasarela'
}
