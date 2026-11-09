import type { Enums } from '~/types/database.types'

export type RunwayStatus = Enums<'runway_status'>

/** Lifecycle order of a weekly runway */
export const RUNWAY_STATUSES: readonly RunwayStatus[] = ['draft', 'werk_room', 'runway', 'voting', 'reveal', 'closed']

export const RUNWAY_STATUS_LABELS: Record<RunwayStatus, string> = {
  draft: 'Borrador',
  werk_room: 'Werk Room',
  runway: 'Pasarela',
  voting: 'Votación',
  reveal: 'Revelación',
  closed: 'Cerrada',
}

/** Status before/after the given one, or null at either end of the lifecycle. */
export function adjacentStatus(status: RunwayStatus, direction: 1 | -1): RunwayStatus | null {
  return RUNWAY_STATUSES[RUNWAY_STATUSES.indexOf(status) + direction] ?? null
}

/** Looks can only be uploaded/replaced before voting opens (mirrors the RLS policies). */
export function canEditLooks(status: RunwayStatus): boolean {
  return status === 'draft' || status === 'werk_room' || status === 'runway'
}

/** The public runway page (every queen's look) only opens once voting starts. */
export function isRunwayPublic(status: RunwayStatus): boolean {
  return status === 'voting' || status === 'reveal' || status === 'closed'
}

/** Shown on the 403 page when someone opens the public runway before voting opens. */
export const RUNWAY_LOCKED_MESSAGE = '¡Alto ahí, reina! La pasarela todavía no ha abierto sus puertas. Los looks se revelan cuando empiece la votación. 💅'
