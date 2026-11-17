export interface BallotPerson {
  id: string
  name: string
  avatar: string | null
}

export interface RunwayBallot {
  voter: BallotPerson
  /** Top 1, Top 2 and Top 3 of the voter, in that order */
  picks: BallotPerson[]
}

const PERSON_COLUMNS = 'id, name, drag_name, avatar_url'

/**
 * Who each voter picked in a runway's Top 3. The `votes` table has one ballot per runway
 * (not per category). RLS only returns everyone's ballots once the runway is closed, and
 * never those of special guests, whose votes stay anonymous.
 */
export function useRunwayBallots() {
  const supabase = useSupabaseClient()

  async function loadBallots(runwayId: string): Promise<RunwayBallot[]> {
    const { data: votes, error: votesError } = await supabase
      .from('votes')
      .select('voter_id, top_1_participant_id, top_2_participant_id, top_3_participant_id')
      .eq('runway_id', runwayId)
    if (votesError) throw votesError
    if (!votes.length) return []

    const ids = [...new Set(votes.flatMap(vote => [
      vote.voter_id,
      vote.top_1_participant_id,
      vote.top_2_participant_id,
      vote.top_3_participant_id,
    ]))]
    const { data: participants, error: participantsError } = await supabase
      .from('participants')
      .select(PERSON_COLUMNS)
      .in('id', ids)
    if (participantsError) throw participantsError

    const people = new Map<string, BallotPerson>(participants.map(participant => [
      participant.id,
      { id: participant.id, name: participant.drag_name ?? participant.name, avatar: participant.avatar_url },
    ]))
    const person = (id: string): BallotPerson => people.get(id) ?? { id, name: '—', avatar: null }

    return votes
      .map(vote => ({
        voter: person(vote.voter_id),
        picks: [vote.top_1_participant_id, vote.top_2_participant_id, vote.top_3_participant_id].map(person),
      }))
      .sort((a, b) => a.voter.name.localeCompare(b.voter.name, 'es'))
  }

  return { loadBallots }
}
