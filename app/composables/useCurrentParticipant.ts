import type { Tables } from '~/types/database.types'

export type CurrentParticipant = Pick<Tables<'participants'>, 'id' | 'user_id' | 'name' | 'drag_name' | 'avatar_url' | 'email' | 'role'>

const PARTICIPANT_COLUMNS = 'id, user_id, name, drag_name, avatar_url, email, role'

/** Postgres unique_violation, raised by participants_drag_name_key */
const UNIQUE_VIOLATION = '23505'

/**
 * Profile row of the signed-in user, shared app-wide via useState.
 * Loaded by the drag-name global middleware before any page renders.
 */
export function useCurrentParticipant() {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const participant = useState<CurrentParticipant | null>('current-participant', () => null)

  const isJurado = computed(() => participant.value?.role === 'jurado')

  /** Fetches the profile unless it is already cached for the current user. */
  async function load(options: { force?: boolean } = {}): Promise<CurrentParticipant | null> {
    // useSupabaseUser() holds JWT claims; the user id is `sub`
    const userId = user.value?.sub
    if (!userId) {
      participant.value = null
      return null
    }
    if (!options.force && participant.value?.user_id === userId) {
      return participant.value
    }

    const { data, error } = await supabase
      .from('participants')
      .select(PARTICIPANT_COLUMNS)
      .eq('user_id', userId)
      .single()

    if (error) throw error
    participant.value = data
    return data
  }

  /** Saves the user's drag name. Throws a friendly error if it is already taken. */
  async function setDragName(dragName: string): Promise<CurrentParticipant> {
    const userId = user.value?.sub
    if (!userId) throw new Error('No has iniciado sesión')

    const { data, error } = await supabase
      .from('participants')
      .update({ drag_name: dragName.trim() })
      .eq('user_id', userId)
      .select(PARTICIPANT_COLUMNS)
      .single()

    if (error) {
      if (error.code === UNIQUE_VIOLATION) throw new Error('Ese nombre drag ya está en uso')
      throw error
    }
    participant.value = data
    return data
  }

  /** Saves the user's own details. Throws a friendly error if the drag name is taken. */
  async function updateProfile(
    changes: { name: string, drag_name: string, avatar_url: string | null },
  ): Promise<CurrentParticipant> {
    const userId = user.value?.sub
    if (!userId) throw new Error('No has iniciado sesión')

    const { data, error } = await supabase
      .from('participants')
      .update({ name: changes.name.trim(), drag_name: changes.drag_name.trim(), avatar_url: changes.avatar_url })
      .eq('user_id', userId)
      .select(PARTICIPANT_COLUMNS)
      .single()

    if (error) {
      if (error.code === UNIQUE_VIOLATION) throw new Error('Ese nombre drag ya está en uso')
      throw error
    }
    participant.value = data
    return data
  }

  function clear(): void {
    participant.value = null
  }

  return { participant: readonly(participant), isJurado, load, setDragName, updateProfile, clear }
}
