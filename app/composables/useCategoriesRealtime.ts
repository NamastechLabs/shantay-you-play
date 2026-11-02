/**
 * Calls `onChange` whenever a category row changes (status, title, ...).
 * Realtime respects RLS, so contestants never hear about drafts. The event is
 * only a signal: callers refetch their own data. Client-side only.
 *
 * @param categoryId limit the subscription to a single category
 */
export function useCategoriesRealtime(onChange: () => void, categoryId?: string): void {
  const supabase = useSupabaseClient()

  // Bursts of events (several admin edits at once) collapse into one refetch
  let timer: ReturnType<typeof setTimeout> | undefined
  const notify = (): void => {
    clearTimeout(timer)
    timer = setTimeout(onChange, 150)
  }

  onMounted(() => {
    const channel = supabase
      .channel(`categories-${categoryId ?? 'all'}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'categories', ...(categoryId && { filter: `id=eq.${categoryId}` }) },
        notify,
      )
      // Anything may have changed while the socket was down (or the tab was asleep)
      .subscribe((status, error) => {
        if (status === 'SUBSCRIBED') notify()
        else if (error) console.warn('Realtime de categorías:', error.message)
      })

    onBeforeUnmount(() => {
      clearTimeout(timer)
      supabase.removeChannel(channel)
    })
  })
}
