export interface CategoryWinner {
  image_url: string
  name: string
}

/** Winner (1st place) of each closed category, keyed by category id. Categories without votes are omitted. */
export function useCategoryWinners() {
  const supabase = useSupabaseClient()

  async function loadWinners(categoryIds: string[]): Promise<Record<string, CategoryWinner>> {
    if (!categoryIds.length) return {}

    const rankings = await Promise.all(categoryIds.map(async (categoryId) => {
      const { data, error } = await supabase.rpc('category_top_three', { p_category_id: categoryId })
      if (error) throw error
      return { categoryId, lookId: data.find(row => row.place === 1)?.look_id }
    }))

    const winning = rankings.filter((entry): entry is { categoryId: string, lookId: string } => !!entry.lookId)
    if (!winning.length) return {}

    const { data: looks, error } = await supabase
      .from('looks')
      .select('id, image_url, participant:participants!looks_participant_id_fkey(name, drag_name)')
      .in('id', winning.map(entry => entry.lookId))
    if (error) throw error

    const lookById = new Map(looks.map(look => [look.id, look]))
    const winners: Record<string, CategoryWinner> = {}
    for (const { categoryId, lookId } of winning) {
      const look = lookById.get(lookId)
      if (look) winners[categoryId] = { image_url: look.image_url, name: look.participant.drag_name ?? look.participant.name }
    }
    return winners
  }

  return { loadWinners }
}
