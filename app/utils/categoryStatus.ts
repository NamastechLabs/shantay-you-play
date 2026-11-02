import type { Enums } from '~/types/database.types'

export type CategoryStatus = Enums<'category_status'>

/** Lifecycle order of a weekly category */
export const CATEGORY_STATUSES: readonly CategoryStatus[] = ['draft', 'werk_room', 'runway', 'voting', 'reveal', 'closed']

export const CATEGORY_STATUS_LABELS: Record<CategoryStatus, string> = {
  draft: 'Borrador',
  werk_room: 'Werk Room',
  runway: 'Pasarela',
  voting: 'Votación',
  reveal: 'Revelación',
  closed: 'Cerrada',
}

/** Status before/after the given one, or null at either end of the lifecycle. */
export function adjacentStatus(status: CategoryStatus, direction: 1 | -1): CategoryStatus | null {
  return CATEGORY_STATUSES[CATEGORY_STATUSES.indexOf(status) + direction] ?? null
}

/** Looks can only be uploaded/replaced before voting opens (mirrors the RLS policies). */
export function canEditLooks(status: CategoryStatus): boolean {
  return status === 'draft' || status === 'werk_room' || status === 'runway'
}
