<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'> & {
  categories: Pick<Tables<'categories'>, 'id' | 'title' | 'kind'>[]
}
type Ballot = Pick<Tables<'votes'>, 'id' | 'top_1_participant_id' | 'top_2_participant_id' | 'top_3_participant_id'>

interface VoteLook {
  id: string
  category_id: string
  image_url: string
  participant: Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
}

/** A queen with every look she walked in this runway: the ballot ranks queens, not looks */
interface Queen {
  id: string
  name: string
  looks: VoteLook[]
}

interface VoteData {
  runway: Runway
  looks: VoteLook[]
  ballot: Ballot | null
}

const BALLOT_SIZE = 3
const RANK_LABELS = ['Top 1', 'Top 2', 'Top 3'] as const

/** Postgres insufficient_privilege: RLS rejected the ballot (voting closed or own queen) */
const RLS_VIOLATION = '42501'
/** PostgREST: .single() matched no rows, i.e. the update was filtered out by RLS */
const NO_ROWS = 'PGRST116'

const route = useRoute()
const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()
const runwayId = String(route.params.id)

// RLS only returns the current participant's own ballot while voting is open
const { data, error: loadError } = await useAsyncData(
  `vote-${runwayId}`,
  async (): Promise<VoteData | null> => {
    // Loaded by the drag-name global middleware before any page renders
    const participantId = participant.value?.id
    if (!participantId) throw new Error('No has iniciado sesión')

    const [runway, looks, ballot] = await Promise.all([
      supabase
        .from('runways')
        .select('id, week_number, runway_date, status, categories(id, title, kind)')
        .eq('id', runwayId)
        .order('created_at', { referencedTable: 'categories', ascending: true })
        .maybeSingle(),
      supabase
        .from('looks')
        .select('id, category_id, image_url, participant:participants!looks_participant_id_fkey(id, name, drag_name), category:categories!looks_category_id_fkey!inner(runway_id)')
        .eq('category.runway_id', runwayId)
        .order('created_at', { ascending: true }),
      supabase
        .from('votes')
        .select('id, top_1_participant_id, top_2_participant_id, top_3_participant_id')
        .eq('runway_id', runwayId)
        .eq('voter_id', participantId)
        .maybeSingle(),
    ])

    if (runway.error) throw runway.error
    if (looks.error) throw looks.error
    if (ballot.error) throw ballot.error
    if (!runway.data) return null

    return { runway: runway.data, looks: looks.data, ballot: ballot.data }
  },
)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Semana no encontrada', fatal: true })
}

const runway = computed(() => data.value?.runway ?? null)
const isVotingOpen = computed(() => runway.value?.status === 'voting')

// Queens in the order of their first look
const queens = computed<Queen[]>(() => {
  const byId = new Map<string, Queen>()
  for (const look of data.value?.looks ?? []) {
    const queen = byId.get(look.participant.id)
      ?? { id: look.participant.id, name: look.participant.drag_name ?? look.participant.name, looks: [] }
    queen.looks.push(look)
    byId.set(queen.id, queen)
  }
  return [...byId.values()]
})

const groupCategories = computed(() => runway.value?.categories.filter(category => category.kind === 'group') ?? [])
const categoryTitles = computed(() => new Map(runway.value?.categories.map(category => [category.id, category.title])))
const isOwnQueen = (queen: Queen): boolean => queen.id === participant.value?.id

// --- Ballot ----------------------------------------------------------------
const ballotId = ref(data.value?.ballot?.id ?? null)
/** Picked queen ids in rank order (index 0 = Top 1) */
const picks = ref<string[]>(
  data.value?.ballot
    ? [data.value.ballot.top_1_participant_id, data.value.ballot.top_2_participant_id, data.value.ballot.top_3_participant_id]
    : [],
)
const saving = ref(false)
const saveError = ref('')
const saved = ref(false)

const isComplete = computed(() => picks.value.length === BALLOT_SIZE)
const votableCount = computed(() => queens.value.filter(queen => !isOwnQueen(queen)).length)

const rankOf = (queen: Queen): number | null => {
  const index = picks.value.indexOf(queen.id)
  return index === -1 ? null : index + 1
}

function pickName(index: number): string {
  const queen = queens.value.find(candidate => candidate.id === picks.value[index])
  return queen ? queen.name : '—'
}

/** Tapping a queen adds her to the next free rank; tapping her again removes her and moves the rest up. */
function togglePick(queen: Queen): void {
  saved.value = false
  saveError.value = ''
  if (picks.value.includes(queen.id)) {
    picks.value = picks.value.filter(id => id !== queen.id)
  }
  else if (picks.value.length < BALLOT_SIZE) {
    picks.value = [...picks.value, queen.id]
  }
}

async function saveBallot(): Promise<void> {
  const [top1, top2, top3] = picks.value
  if (!top1 || !top2 || !top3 || !participant.value) return

  saving.value = true
  saveError.value = ''
  saved.value = false

  const picksPayload = { top_1_participant_id: top1, top_2_participant_id: top2, top_3_participant_id: top3 }

  // Only the top_N columns are updatable, so an existing ballot is updated by id rather than upserted
  const { data: row, error } = ballotId.value
    ? await supabase.from('votes').update(picksPayload).eq('id', ballotId.value).select('id').single()
    : await supabase
        .from('votes')
        .insert({ ...picksPayload, runway_id: runwayId, voter_id: participant.value.id })
        .select('id')
        .single()

  saving.value = false

  if (error) {
    saveError.value = error.code === RLS_VIOLATION || error.code === NO_ROWS
      ? 'No se pudo guardar: la votación ya no está abierta.'
      : toErrorMessage(error)
    return
  }

  ballotId.value = row.id
  saved.value = true
}
</script>

<template>
  <main v-if="runway" class="page page--wide vote-page">
    <AppNav />
    <AppBreadcrumb
      :items="[
        { label: 'Inicio', to: '/' },
        { label: `Semana ${runway.week_number}`, to: `/runways/${runway.id}` },
        { label: 'Tu Top 3' },
      ]"
    />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Semana {{ runway.week_number }} · {{ runwayTitle(runway.categories) }}
        </p>
        <h1>Tu Top 3</h1>
      </div>
      <nav class="page-header__actions">
        <NuxtLink :to="`/runways/${runway.id}`" class="btn btn--secondary">
          Ver la pasarela
        </NuxtLink>
      </nav>
    </header>

    <template v-if="isVotingOpen">
      <p class="lead">
        Vota a las reinas por el conjunto de sus looks de la semana. Toca las reinas en orden: la primera será tu Top 1. Tócala otra vez para quitarla.
        {{ ballotId ? 'Puedes cambiar tu voto mientras la votación siga abierta.' : '' }}
      </p>

      <p v-if="votableCount < BALLOT_SIZE" class="empty">
        Hacen falta al menos {{ BALLOT_SIZE }} reinas con looks para votar.
      </p>

      <ul v-else class="gallery">
        <li v-for="queen in queens" :key="queen.id">
          <button
            type="button"
            class="look-card"
            :class="{ 'look-card--picked': rankOf(queen) }"
            :aria-pressed="rankOf(queen) !== null"
            :disabled="isOwnQueen(queen) || (isComplete && rankOf(queen) === null)"
            @click="togglePick(queen)"
          >
            <span v-if="rankOf(queen)" class="look-card__rank">{{ rankOf(queen) }}</span>
            <span class="queen-photos" :style="{ gridTemplateColumns: `repeat(${queen.looks.length}, minmax(0, 1fr))` }">
              <img
                v-for="look in queen.looks"
                :key="look.id"
                class="queen-photos__photo"
                :src="look.image_url"
                :alt="`Look de ${queen.name}: ${categoryTitles.get(look.category_id) ?? ''}`"
                loading="lazy"
              >
            </span>
            <span class="look-card__body">
              <span class="look-card__name">{{ queen.name }}</span>
              <span v-if="isOwnQueen(queen)" class="look-card__intro">Eres tú: no puedes votarte.</span>
            </span>
          </button>
        </li>
      </ul>

      <div v-if="votableCount >= BALLOT_SIZE" class="ballot-bar">
        <ol class="ballot-bar__picks" aria-label="Tu Top 3">
          <li
            v-for="(label, index) in RANK_LABELS"
            :key="label"
            class="ballot-bar__pick"
            :class="{ 'ballot-bar__pick--filled': picks[index] }"
          >
            <span class="ballot-bar__rank">{{ label }}</span>
            <span class="ballot-bar__name">{{ pickName(index) }}</span>
          </li>
        </ol>
        <div class="ballot-bar__actions">
          <p v-if="saveError" class="form-error" role="alert">
            {{ saveError }}
          </p>
          <p v-else-if="saved" class="ballot-bar__saved" role="status">
            ¡Voto guardado!
          </p>
          <button
            type="button"
            class="btn btn--primary"
            :disabled="!isComplete || saving"
            @click="saveBallot"
          >
            {{ saving ? 'Guardando…' : ballotId ? 'Actualizar mi voto' : 'Enviar mi voto' }}
          </button>
        </div>
      </div>

      <GroupCategoryVote
        v-for="category in groupCategories"
        :key="category.id"
        :category="category"
        :show-title="runway.categories.length > 1"
      />
    </template>

    <p v-else class="empty">
      {{ runway.status === 'closed' || runway.status === 'reveal'
        ? 'La votación de esta semana ya cerró.'
        : 'La votación aún no ha abierto. ¡Mientras tanto, disfruta de la pasarela!' }}
    </p>
  </main>

  <main v-else class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }]" />
    <p class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
  </main>
</template>

<style scoped lang="scss">
// All the looks of a queen side by side, one per category
.queen-photos {
  display: grid;
  gap: 2px;
}

.queen-photos__photo {
  width: 100%;
  aspect-ratio: 3 / 4;
  object-fit: cover;
}
</style>
