import type { InjectionKey } from 'vue'
import type { Tables } from '~/types/database.types'

export type AdminRunway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'>
export type AdminCategory = Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text'>

export interface AdminRunwayContext {
  runway: ComputedRef<AdminRunway>
  categories: ComputedRef<AdminCategory[]>
  refresh: () => Promise<void>
}

const adminRunwayKey: InjectionKey<AdminRunwayContext> = Symbol('admin-runway')

/** Called by the runway layout page (`admin/runways/[id].vue`) to share its data with the section pages. */
export function provideAdminRunway(context: AdminRunwayContext): void {
  provide(adminRunwayKey, context)
}

/** The runway being edited and its categories, loaded once by the layout page. */
export function useAdminRunway(): AdminRunwayContext {
  const context = inject(adminRunwayKey)
  if (!context) throw new Error('useAdminRunway() must be used inside admin/runways/[id]')
  return context
}
