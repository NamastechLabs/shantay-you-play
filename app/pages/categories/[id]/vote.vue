<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Category = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'status'>
type Ballot = Pick<Tables<'votes'>, 'id' | 'top_1_look_id' | 'top_2_look_id' | 'top_3_look_id'>

interface VoteLook {
  id: string
  image_url: string
  intro: string | null
  participant: Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
}

interface VoteData {
  category: Category
  looks: VoteLook[]
  ballot: Ballot | null
}

const BALLOT_SIZE = 3
const RANK_LABELS = ['Top 1', 'Top 2', 'Top 3'] as const

/** Postgres insufficient_privilege: RLS rejected the ballot (voting closed or own look) */
const RLS_VIOLATION = '42501'
/** PostgREST: .single() matched no rows, i.e. the update was filtered out by RLS */
const NO_ROWS = 'PGRST116'

const route = useRoute()
const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()
const categoryId = String(route.params.id)

// RLS only returns the current participant's own ballot while voting is open
const { data, error: loadError } = await useAsyncData(
  `vote-${categoryId}`,
  async (): Promise<VoteData | null> => {
    // Loaded by the drag-name global middleware before any page renders
    const participantId = participant.value?.id
    if (!participantId) throw new Error('No has iniciado sesión')

    const [category, looks, ballot] = await Promise.all([
      supabase
        .from('categories')
        .select('id, week_number, title, status')
        .eq('id', categoryId)
        .maybeSingle(),
      supabase
        .from('looks')
        .select('id, image_url, intro, participant:participants!looks_participant_id_fkey(id, name, drag_name)')
        .eq('category_id', categoryId)
        .order('created_at', { ascending: true }),
      supabase
        .from('votes')
        .select('id, top_1_look_id, top_2_look_id, top_3_look_id')
        .eq('category_id', categoryId)
        .eq('voter_id', participantId)
        .maybeSingle(),
    ])

    if (category.error) throw category.error
    if (looks.error) throw looks.error
    if (ballot.error) throw ballot.error
    if (!category.data) return null

    return { category: category.data, looks: looks.data, ballot: ballot.data }
  },
)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Categoría no encontrada', fatal: true })
}

const category = computed(() => data.value?.category ?? null)
const looks = computed(() => data.value?.looks ?? [])
const isVotingOpen = computed(() => category.value?.status === 'voting')

const displayName = (look: VoteLook): string => look.participant.drag_name ?? look.participant.name
const isOwnLook = (look: VoteLook): boolean => look.participant.id === participant.value?.id

// --- Ballot ----------------------------------------------------------------
const ballotId = ref(data.value?.ballot?.id ?? null)
/** Picked look ids in rank order (index 0 = Top 1) */
const picks = ref<string[]>(
  data.value?.ballot
    ? [data.value.ballot.top_1_look_id, data.value.ballot.top_2_look_id, data.value.ballot.top_3_look_id]
    : [],
)
const saving = ref(false)
const saveError = ref('')
const saved = ref(false)

const isComplete = computed(() => picks.value.length === BALLOT_SIZE)
const votableCount = computed(() => looks.value.filter(look => !isOwnLook(look)).length)

const rankOf = (look: VoteLook): number | null => {
  const index = picks.value.indexOf(look.id)
  return index === -1 ? null : index + 1
}

function pickName(index: number): string {
  const look = looks.value.find(candidate => candidate.id === picks.value[index])
  return look ? displayName(look) : '—'
}

/** Tapping a look adds it to the next free rank; tapping it again removes it and moves the rest up. */
function togglePick(look: VoteLook): void {
  saved.value = false
  saveError.value = ''
  if (picks.value.includes(look.id)) {
    picks.value = picks.value.filter(id => id !== look.id)
  }
  else if (picks.value.length < BALLOT_SIZE) {
    picks.value = [...picks.value, look.id]
  }
}

async function saveBallot(): Promise<void> {
  const [top1, top2, top3] = picks.value
  if (!top1 || !top2 || !top3 || !participant.value) return

  saving.value = true
  saveError.value = ''
  saved.value = false

  const picksPayload = { top_1_look_id: top1, top_2_look_id: top2, top_3_look_id: top3 }

  // Only the top_N columns are updatable, so an existing ballot is updated by id rather than upserted
  const { data: row, error } = ballotId.value
    ? await supabase.from('votes').update(picksPayload).eq('id', ballotId.value).select('id').single()
    : await supabase
        .from('votes')
        .insert({ ...picksPayload, category_id: categoryId, voter_id: participant.value.id })
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
  <main v-if="category" class="page page--wide vote-page">
    <AppNav />
    <AppBreadcrumb
      :items="[
        { label: 'Inicio', to: '/' },
        { label: `Semana ${category.week_number}`, to: `/categories/${category.id}` },
        { label: 'Tu Top 3' },
      ]"
    />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Semana {{ category.week_number }} · {{ category.title }}
          <StatusBadge :status="category.status" />
        </p>
        <h1>Tu Top 3</h1>
      </div>
      <nav class="page-header__actions">
        <NuxtLink :to="`/categories/${category.id}`" class="btn btn--secondary">
          Ver la pasarela
        </NuxtLink>
      </nav>
    </header>

    <template v-if="isVotingOpen">
      <p class="lead">
        Toca los looks en orden: el primero será tu Top 1. Tócalo otra vez para quitarlo.
        {{ ballotId ? 'Puedes cambiar tu voto mientras la votación siga abierta.' : '' }}
      </p>

      <p v-if="votableCount < BALLOT_SIZE" class="empty">
        Hacen falta al menos {{ BALLOT_SIZE }} looks de otras reinas para votar.
      </p>

      <ul v-else class="gallery">
        <li v-for="look in looks" :key="look.id">
          <button
            type="button"
            class="look-card"
            :class="{ 'look-card--picked': rankOf(look) }"
            :aria-pressed="rankOf(look) !== null"
            :disabled="isOwnLook(look) || (isComplete && rankOf(look) === null)"
            @click="togglePick(look)"
          >
            <span v-if="rankOf(look)" class="look-card__rank">{{ rankOf(look) }}</span>
            <img
              class="look-card__photo"
              :src="look.image_url"
              :alt="`Look de ${displayName(look)}`"
              loading="lazy"
            >
            <span class="look-card__body">
              <span class="look-card__name">{{ displayName(look) }}</span>
              <span v-if="isOwnLook(look)" class="look-card__intro">Tu look: no puedes votarte.</span>
              <span v-else-if="look.intro" class="look-card__intro">{{ look.intro }}</span>
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
    </template>

    <p v-else class="empty">
      {{ category.status === 'closed' || category.status === 'reveal'
        ? 'La votación de esta categoría ya cerró.'
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
