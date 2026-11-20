import type { Tables } from '~/types/database.types'

export type Subcategory = Pick<Tables<'category_subcategories'>, 'id' | 'name' | 'position'>

/** A queen in pick order, with the sub-category she took (if visible to the current user) */
export interface SubcategoryQueen {
  id: string
  name: string
  avatarUrl: string | null
  /** 1 picks first */
  turn: number
  /** Whether she has already picked. Queens do not see what the others took */
  hasPicked: boolean
  /** The sub-category she took: only known for yourself (and for judges, who see all) */
  subcategoryId: string | null
}

/**
 * Sub-categories of an individual category, who took each one, and whose turn it is.
 * The turn order comes from the database (ranking of the previous week's runway,
 * then alphabetical), so the app never recomputes it. Queens only get the free sub-categories
 * and their own; judges get everything.
 *
 * @param options.realtime refetch whenever somebody picks or the admin edits the list (client only)
 */
export function useCategorySubcategories(categoryId: MaybeRefOrGetter<string>, options: { realtime?: boolean } = {}) {
  const supabase = useSupabaseClient()

  const subcategories = ref<Subcategory[]>([])
  const queens = ref<SubcategoryQueen[]>([])
  const loading = ref(false)
  const error = ref('')

  /** The queen who has to pick now: the first in the order without a sub-category */
  const nextQueen = computed(() => queens.value.find(queen => !queen.hasPicked) ?? null)
  const takenIds = computed(() => new Set(queens.value.flatMap(queen => (queen.subcategoryId ? [queen.subcategoryId] : []))))
  const available = computed(() => subcategories.value.filter(subcategory => !takenIds.value.has(subcategory.id)))
  const queenOf = (subcategoryId: string): SubcategoryQueen | undefined =>
    queens.value.find(queen => queen.subcategoryId === subcategoryId)

  async function load(): Promise<void> {
    const id = toValue(categoryId)
    try {
      const [subs, picks, order, people] = await Promise.all([
        supabase.from('category_subcategories').select('id, name, position').eq('category_id', id).order('position').order('created_at'),
        supabase.from('category_subcategory_picks').select('subcategory_id, participant_id').eq('category_id', id),
        supabase.rpc('subcategory_turn_order', { p_category_id: id }),
        supabase.from('participants').select('id, name, drag_name, avatar_url').eq('role', 'concursante'),
      ])
      for (const result of [subs, picks, order, people]) {
        if (result.error) throw result.error
      }

      const pickOf = new Map((picks.data ?? []).map(pick => [pick.participant_id, pick.subcategory_id]))
      const person = new Map((people.data ?? []).map(row => [row.id, row]))
      subcategories.value = subs.data ?? []
      queens.value = (order.data ?? []).flatMap((row) => {
        const found = person.get(row.participant_id)
        if (!found) return []
        return [{
          id: row.participant_id,
          name: found.drag_name ?? found.name,
          avatarUrl: found.avatar_url,
          turn: row.turn,
          hasPicked: row.has_picked,
          subcategoryId: pickOf.get(row.participant_id) ?? null,
        }]
      })
      error.value = ''
    }
    catch (caught) {
      error.value = toErrorMessage(caught)
    }
  }

  async function init(): Promise<void> {
    loading.value = true
    await load()
    loading.value = false
  }

  /** A queen takes a sub-category on her turn */
  async function pick(subcategoryId: string): Promise<void> {
    const { error: pickError } = await supabase.rpc('pick_subcategory', { p_subcategory_id: subcategoryId })
    await load()
    if (pickError) throw pickError
  }

  /** A judge gives a sub-category to a queen (replacing hers) */
  async function assign(subcategoryId: string, participantId: string): Promise<void> {
    const { error: assignError } = await supabase.rpc('assign_subcategory', { p_subcategory_id: subcategoryId, p_participant_id: participantId })
    await load()
    if (assignError) throw assignError
  }

  /** A judge frees the sub-category of a queen */
  async function free(participantId: string): Promise<void> {
    const { error: freeError } = await supabase
      .from('category_subcategory_picks')
      .delete()
      .eq('category_id', toValue(categoryId))
      .eq('participant_id', participantId)
    await load()
    if (freeError) throw freeError
  }

  if (options.realtime) {
    let timer: ReturnType<typeof setTimeout> | undefined
    const notify = (): void => {
      clearTimeout(timer)
      timer = setTimeout(() => void load(), 150)
    }

    onMounted(() => {
      // Queens cannot read other queens' picks, so realtime does not tell them whose turn it is: poll too
      const poll = setInterval(() => {
        if (document.visibilityState === 'visible') void load()
      }, 8000)
      const id = toValue(categoryId)
      const filter = `category_id=eq.${id}`
      const channel = supabase
        .channel(`subcategories-${id}`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'category_subcategories', filter }, notify)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'category_subcategory_picks', filter }, notify)
        // Anything may have changed while the socket was down (or the tab was asleep)
        .subscribe((status, subscribeError) => {
          if (status === 'SUBSCRIBED') notify()
          else if (subscribeError) console.warn('Realtime de subcategorías:', subscribeError.message)
        })

      onBeforeUnmount(() => {
        clearTimeout(timer)
        clearInterval(poll)
        supabase.removeChannel(channel)
      })
    })
  }

  return { subcategories, queens, loading, error, nextQueen, available, queenOf, init, pick, assign, free }
}
