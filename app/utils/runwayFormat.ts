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

/** "2026-11-05T20:00:00+00:00" -> "5 de noviembre" (in the runway time zone): the day without the hour */
export function formatRunwayLongDate(timestamp: string): string {
  return new Date(timestamp).toLocaleDateString('es', { day: 'numeric', month: 'long', timeZone: RUNWAY_TIME_ZONE })
}

/** "2026-11-05T20:00:00+00:00" -> "5 nov" (in the runway time zone) */
export function formatRunwayDay(timestamp: string): string {
  return new Date(timestamp).toLocaleDateString('es', { day: 'numeric', month: 'short', timeZone: RUNWAY_TIME_ZONE }).replace('.', '')
}

/** "2026-11-05T20:00:00+00:00" -> "21:00" (in the runway time zone) */
export function formatRunwayTime(timestamp: string): string {
  return new Date(timestamp).toLocaleTimeString('es', { hour: '2-digit', minute: '2-digit', timeZone: RUNWAY_TIME_ZONE })
}

const pad2 = (value: number): string => String(value).padStart(2, '0')

export interface CountdownUnit {
  /** Two digits, e.g. "05" */
  value: string
  /** "día" / "días", "hora" / "horas"... */
  label: string
}

/** Time left until a runway, split into days, hours, minutes and seconds (always the four of them) */
export function splitCountdown(milliseconds: number): CountdownUnit[] {
  const total = Math.max(0, Math.floor(milliseconds / 1000))
  const days = Math.floor(total / 86_400)
  const hours = Math.floor((total % 86_400) / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const seconds = total % 60

  return [
    { value: pad2(days), label: days === 1 ? 'Día' : 'Días' },
    { value: pad2(hours), label: hours === 1 ? 'Hora' : 'Horas' },
    { value: pad2(minutes), label: minutes === 1 ? 'Minuto' : 'Minutos' },
    { value: pad2(seconds), label: seconds === 1 ? 'Segundo' : 'Segundos' },
  ]
}
