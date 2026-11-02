/**
 * Calls `onChange` whenever a runway row changes (status, date, ...).
 * Realtime respects RLS, so contestants never hear about drafts. The event is
 * only a signal: callers refetch their own data. Client-side only.
 *
 * @param runwayId limit the subscription to a single runway
 */
export function useRunwaysRealtime(onChange: () => void, runwayId?: string): void {
  const supabase = useSupabaseClient()

  // Bursts of events (several admin edits at once) collapse into one refetch
  let timer: ReturnType<typeof setTimeout> | undefined
  const notify = (): void => {
    clearTimeout(timer)
    timer = setTimeout(onChange, 150)
  }

  onMounted(() => {
    const channel = supabase
      .channel(`runways-${runwayId ?? 'all'}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'runways', ...(runwayId && { filter: `id=eq.${runwayId}` }) },
        notify,
      )
      // Anything may have changed while the socket was down (or the tab was asleep)
      .subscribe((status, error) => {
        if (status === 'SUBSCRIBED') notify()
        else if (error) console.warn('Realtime de pasarelas:', error.message)
      })

    onBeforeUnmount(() => {
      clearTimeout(timer)
      supabase.removeChannel(channel)
    })
  })
}
