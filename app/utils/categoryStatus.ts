import type { Enums } from '~/types/database.types'

export type CategoryStatus = Enums<'category_status'>

/** Lifecycle order of a weekly category */
export const CATEGORY_STATUSES: readonly CategoryStatus[] = ['draft', 'runway', 'voting', 'closed']

export const CATEGORY_STATUS_LABELS: Record<CategoryStatus, string> = {
  draft: 'Borrador',
  runway: 'Pasarela',
  voting: 'Votación',
  closed: 'Cerrada',
}

/** Status before/after the given one, or null at either end of the lifecycle. */
export function adjacentStatus(status: CategoryStatus, direction: 1 | -1): CategoryStatus | null {
  return CATEGORY_STATUSES[CATEGORY_STATUSES.indexOf(status) + direction] ?? null
}

/** Looks can only be uploaded/replaced before voting opens (mirrors the RLS policies). */
export function canEditLooks(status: CategoryStatus): boolean {
  return status === 'draft' || status === 'runway'
}
