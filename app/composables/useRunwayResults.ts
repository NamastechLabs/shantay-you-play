export interface RunwayQueen {
  /** The queen's participant id */
  id: string
  /** 1 = winner */
  place: number
  /** Photo of her first look of the runway */
  image_url: string
  name: string
}

/**
 * Results are per queen, not per look: a queen walks one look per category, so
 * her photo here is the first look she uploaded in the runway.
 */
export function useRunwayResults() {
  const supabase = useSupabaseClient()

  /** Top 3 queens of a runway; empty until it reaches 'reveal'. */
  async function loadTopThree(runwayId: string): Promise<RunwayQueen[]> {
    const { data: ranking, error: rankingError } = await supabase.rpc('runway_top_three', { p_runway_id: runwayId })
    if (rankingError) throw rankingError
    if (!ranking.length) return []

    const { data: looks, error: looksError } = await supabase
      .from('looks')
      .select('participant_id, image_url, participant:participants!looks_participant_id_fkey(name, drag_name), category:categories!looks_category_id_fkey!inner(runway_id)')
      .eq('category.runway_id', runwayId)
      .in('participant_id', ranking.map(row => row.participant_id))
      .order('created_at', { ascending: true })
    if (looksError) throw looksError

    const queens: RunwayQueen[] = []
    for (const row of ranking) {
      const look = looks.find(candidate => candidate.participant_id === row.participant_id)
      if (look) {
        queens.push({
          id: row.participant_id,
          place: row.place,
          image_url: look.image_url,
          name: look.participant.drag_name ?? look.participant.name,
        })
      }
    }
    return queens
  }

  /** Winner (1st place) of each runway, keyed by runway id. Runways without votes are omitted. */
  async function loadWinners(runwayIds: string[]): Promise<Record<string, RunwayQueen>> {
    const topThrees = await Promise.all(runwayIds.map(async runwayId => ({
      runwayId,
      winner: (await loadTopThree(runwayId)).find(queen => queen.place === 1),
    })))

    const winners: Record<string, RunwayQueen> = {}
    for (const { runwayId, winner } of topThrees) {
      if (winner) winners[runwayId] = winner
    }
    return winners
  }

  return { loadTopThree, loadWinners }
}
