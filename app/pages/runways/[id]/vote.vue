<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { LookImages } from '~/utils/lookSlots'

type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'> & {
  categories: Pick<Tables<'categories'>, 'id' | 'title' | 'kind'>[]
}
type Ballot = Pick<Tables<'votes'>, 'id' | 'top_1_participant_id' | 'top_2_participant_id' | 'top_3_participant_id'>

interface VoteLook extends LookImages {
  id: string
  category_id: string
  intro: string | null
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
        .select('id, category_id, image_url, image2_url, image3_url, image4_url, intro, participant:participants!looks_participant_id_fkey(id, name, drag_name), category:categories!looks_category_id_fkey!inner(runway_id)')
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

// --- Steps (runways with a group category) -----------------------------------------
// Jury: best band, order of the queens, Top 3. Contestant: order of the rival band, Top 3.
// Only one group category per runway is supported. Navigation is free; steps show a check once saved.
type VoteStep = 'band' | 'ranking' | 'top3'

interface GroupProgress {
  eligible: boolean
  band: boolean
  ranking: boolean
  rankingIds: string[]
}

const groupCategory = computed(() => groupCategories.value[0] ?? null)
/** The group category is the only one: the jury's ranking is their whole vote, so they cast no individual Top 3. Contestants still do. */
const groupOnly = computed(() => isJury.value && !!groupCategory.value && runway.value?.categories.length === 1)
const isJury = computed(() => participant.value?.role === 'jurado')
const groupProgress = ref<GroupProgress | null>(null)

const steps = computed<{ id: VoteStep, label: string, done: boolean }[]>(() => {
  if (!groupCategory.value) return []
  const progress = groupProgress.value
  const list: { id: VoteStep, label: string, done: boolean }[] = []
  if (progress?.eligible) {
    if (isJury.value) list.push({ id: 'band', label: 'Mejor banda', done: progress.band })
    list.push({ id: 'ranking', label: isJury.value ? 'Ordena a las reinas' : 'Ordena a la banda rival', done: progress.ranking })
  }
  if (!groupOnly.value) list.push({ id: 'top3', label: 'Tu Top 3', done: !!ballotId.value })
  return list
})

const hasSteps = computed(() => steps.value.length > 1)
/** The step lives in the URL (?paso=2) so a refresh keeps it */
const stepIndex = computed(() => {
  const requested = Number(route.query.paso)
  return Number.isInteger(requested) && requested >= 1 && requested <= steps.value.length ? requested - 1 : 0
})
const currentStep = computed<VoteStep>(() => steps.value[stepIndex.value]?.id ?? 'top3')
const showTop3 = computed(() => !groupOnly.value && (!hasSteps.value || currentStep.value === 'top3'))
const pendingSteps = computed(() => steps.value.filter(step => step.id !== 'top3' && !step.done).map(step => step.label))

async function goToStep(index: number): Promise<void> {
  await navigateTo({ query: { ...route.query, paso: String(index + 1) } }, { replace: true })
  if (import.meta.client) document.getElementById('vote-steps')?.scrollIntoView({ block: 'start' })
}

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

// The jury's Top 3 is proposed from the first three queens of their ranking (they can change it)
const prefillCandidates = computed(() => (groupProgress.value?.rankingIds ?? [])
  .filter(id => queens.value.some(queen => queen.id === id && !isOwnQueen(queen)))
  .slice(0, BALLOT_SIZE))
const lastPrefill = ref<string[]>([])

function prefillFromRanking(): void {
  picks.value = [...prefillCandidates.value]
  lastPrefill.value = [...prefillCandidates.value]
  saved.value = false
  saveError.value = ''
}

// On the Top 3 step, propose the ranking unless the jury already saved or changed their picks
watch([currentStep, prefillCandidates], () => {
  if (!isJury.value || currentStep.value !== 'top3' || ballotId.value || !prefillCandidates.value.length) return
  const untouched = picks.value.length === 0 || picks.value.join() === lastPrefill.value.join()
  if (untouched) prefillFromRanking()
}, { immediate: true })

const isComplete = computed(() => picks.value.length === BALLOT_SIZE)
const votableCount = computed(() => queens.value.filter(queen => !isOwnQueen(queen)).length)

const rankOf = (queen: Queen): number | null => {
  const index = picks.value.indexOf(queen.id)
  return index === -1 ? null : index + 1
}

/** First photo of a picked queen, for the small thumbnails of the ballot bar */
function pickPhoto(index: number): string | null {
  return queens.value.find(candidate => candidate.id === picks.value[index])?.looks[0]?.image_url ?? null
}

// --- Look dialog: the whole look of a queen, without picking her -----------------------
const zoom = ref<{ queenId: string, index: number } | null>(null)
const zoomQueen = computed(() => queens.value.find(queen => queen.id === zoom.value?.queenId) ?? null)
const zoomLook = computed(() => zoomQueen.value?.looks[zoom.value?.index ?? 0] ?? null)

function showAdjacentLook(step: 1 | -1): void {
  const queen = zoomQueen.value
  if (!queen || !zoom.value) return
  zoom.value = { queenId: queen.id, index: (zoom.value.index + step + queen.looks.length) % queen.looks.length }
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
  <main v-if="runway" class="page vote-page">
    <AppNav />
    <AppBreadcrumb
      :items="[
        { label: 'Inicio', to: '/' },
        { label: `Semana ${runway.week_number}`, to: `/runways/${runway.id}` },
        { label: groupCategory ? 'Tu votación' : 'Tu Top 3' },
      ]"
    />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Semana {{ runway.week_number }} · {{ runwayTitle(runway.categories) }}
        </p>
        <h1>{{ groupCategory ? 'Tu votación' : 'Tu Top 3' }}</h1>
      </div>
      <nav class="page-header__actions">
        <NuxtLink :to="`/runways/${runway.id}`" class="btn btn--secondary btn--small">
          Ver la pasarela
        </NuxtLink>
      </nav>
    </header>

    <template v-if="isVotingOpen">
      <VoteStepper
        v-if="hasSteps"
        id="vote-steps"
        :steps="steps"
        :current="stepIndex"
        label="Pasos de la votación"
        @select="goToStep"
      />

      <GroupCategoryVote
        v-if="groupCategory"
        :category="groupCategory"
        :show-title="runway.categories.length > 1"
        :step="currentStep"
        @progress="groupProgress = $event"
      />

      <div v-show="showTop3" class="vote-top3">
        <h2 v-if="hasSteps" class="vote-top3__title">
          Tu Top 3 de la semana
        </h2>
        <!-- Phones: only the first sentence, the how-to is behind "Leer más" -->
        <ReadMoreText
          class="lead"
          intro="Vota a las reinas por el conjunto de sus looks de la semana."
          :more="`Toca las reinas en orden: la primera será tu Top 1. Tócala otra vez para quitarla.${ballotId ? ' Puedes cambiar tu voto mientras la votación siga abierta.' : ''}`"
        />


        <p v-if="hasSteps && isJury && lastPrefill.length" class="hint">
          Hemos propuesto tus tres primeras del orden anterior. Puedes cambiarlas.
          <button type="button" class="btn btn--secondary" @click="prefillFromRanking">
            Usar mi orden otra vez
          </button>
        </p>
        <p v-if="hasSteps && pendingSteps.length" class="hint">
          Todavía no has votado: {{ pendingSteps.join(' y ') }}.
        </p>

        <p v-if="votableCount < BALLOT_SIZE" class="empty">
          Hacen falta al menos {{ BALLOT_SIZE }} reinas con looks para votar.
        </p>

        <!-- Phones: two queens per row, so six fit in a screen and a half instead of six screens -->
        <ul v-else class="gallery vote-gallery">
          <li v-for="queen in queens" :key="queen.id" class="vote-card" :class="{ 'vote-card--own': isOwnQueen(queen) }">
            <button
              type="button"
              class="look-card"
              :class="{ 'look-card--picked': rankOf(queen) }"
              :aria-pressed="rankOf(queen) !== null"
              :disabled="isOwnQueen(queen) || (isComplete && rankOf(queen) === null)"
              @click="togglePick(queen)"
            >
              <span v-if="rankOf(queen)" class="look-card__rank">{{ rankOf(queen) }}</span>
              <span class="queen-photos" :style="{ '--looks': queen.looks.length }">
                <img
                  v-for="look in queen.looks"
                  :key="look.id"
                  class="queen-photos__photo"
                  :src="look.image_url"
                  :alt="`Look de ${queen.name}: ${categoryTitles.get(look.category_id) ?? ''}`"
                  loading="lazy"
                >
                <!-- Phones show the first look only; the others are in the look dialog -->
                <span v-if="queen.looks.length > 1" class="look-card__count queen-photos__more" aria-hidden="true">+{{ queen.looks.length - 1 }}</span>
              </span>
              <span class="look-card__body">
                <span class="look-card__name">{{ queen.name }}</span>
                <span v-if="isOwnQueen(queen)" class="look-card__intro">Eres tú: no puedes votarte.</span>
              </span>
            </button>

            <!-- Your own queen: a thin row on phones (a whole card to say "it is you" is a waste of screen) -->
            <p v-if="isOwnQueen(queen)" class="vote-card__own">
              {{ queen.name }}: eres tú, no puedes votarte.
            </p>
            <button
              v-else
              type="button"
              class="vote-card__zoom"
              :aria-label="`Ver el look de ${queen.name} en grande`"
              @click="zoom = { queenId: queen.id, index: 0 }"
            >
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <circle cx="11" cy="11" r="6.5" />
                <path d="m16 16 4.5 4.5M11 8.5v5M8.5 11h5" />
              </svg>
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
              <!-- Phones: a small photo and the rank number instead of the (clipped) name -->
              <span class="ballot-bar__num" aria-hidden="true">{{ index + 1 }}</span>
              <img v-if="pickPhoto(index)" class="ballot-bar__thumb" :src="pickPhoto(index)!" alt="">
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
              <!-- Phones: a "send" icon and the short text "Enviar" instead of the long label -->
              <svg class="ballot-bar__send" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M21 3 10 14M21 3l-7 18-4-7-7-4 18-7z" />
              </svg>
              <span class="ballot-bar__label">{{ saving ? 'Guardando…' : ballotId ? 'Actualizar' : 'Votar' }}</span>
              <span class="ballot-bar__short" aria-hidden="true">Enviar</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Phones only: the same stepper again below the step, so you do not scroll back up to change step -->
      <VoteStepper
        v-if="hasSteps"
        class="vote-steps__bottom"
        :steps="steps"
        :current="stepIndex"
        label="Pasos de la votación (abajo)"
        @select="goToStep"
      />

      <LookGalleryDialog
        :open="zoom !== null"
        :title="zoomQueen?.name ?? ''"
        :photos="zoomLook ? lookPhotos(zoomLook) : []"
        :category-title="(zoomQueen?.looks.length ?? 0) > 1 && zoomLook ? categoryTitles.get(zoomLook.category_id) ?? null : null"
        :intro="zoomLook?.intro"
        :can-navigate="(zoomQueen?.looks.length ?? 0) > 1"
        @previous="showAdjacentLook(-1)"
        @next="showAdjacentLook(1)"
        @close="zoom = null"
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
.vote-top3 {
  display: grid;
  gap: var(--space-4);
}

.vote-top3__title {
  font-size: 1.25rem;
}

.vote-steps__bottom {
  @media (min-width: 48rem) {
    display: none;
  }
}

// The title and the "Ver la pasarela" link share a line, the link on the right
.page-header {
  flex-wrap: nowrap;
  align-items: flex-end;
}

.page-header__titles {
  flex: 1;
  min-width: 0;
}

.page-header__actions {
  flex: none;
}

// Phones: the kicker ("Semana 7 · Los 7 pecados capitales") gets the full width on its own row,
// and the title and the button share the row below it
@media (max-width: 47.99rem) {
  .page-header {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: end;
    column-gap: var(--space-3);
  }

  .page-header__titles {
    display: contents;
  }

  .page-header__titles .kicker {
    grid-column: 1 / -1;
  }
}

// All the looks of a queen side by side, one per category (phones: only the first, with a "+N")
.queen-photos {
  position: relative;
  display: grid;
  grid-template-columns: repeat(var(--looks, 1), minmax(0, 1fr));
  gap: 2px;

  @media (max-width: 47.99rem) {
    grid-template-columns: minmax(0, 1fr);
  }
}

.queen-photos__photo {
  width: 100%;
  aspect-ratio: 3 / 4;
  object-fit: cover;
  // The brand's "S" on a tinted card while the photo loads
  background-color: var(--color-surface-raised);
  background-image: url('/icon-192.png');
  background-position: center;
  background-repeat: no-repeat;
  background-size: 30%;

  @media (max-width: 47.99rem) {
    &:nth-child(n + 2) {
      display: none;
    }
  }
}

.queen-photos__more {
  @media (min-width: 48rem) {
    display: none;
  }
}

.vote-card {
  position: relative;
}

// Own queen: a thin row on phones, the full card from tablets up
.vote-card__own {
  margin: 0;
  font-size: 0.875rem;
  color: var(--color-text-muted);

  @media (min-width: 48rem) {
    display: none;
  }
}

// Under the pinned ballot bar (z-index 5), over the card
.ballot-bar {
  z-index: 5;
}

.vote-card__zoom {
  position: absolute;
  top: var(--space-2);
  right: var(--space-2);
  z-index: 1;
  display: grid;
  place-items: center;
  width: 2.5rem;
  height: 2.5rem;
  padding: 0;
  color: var(--color-title);
  cursor: pointer;
  background-color: color-mix(in srgb, var(--color-surface) 88%, transparent);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  box-shadow: var(--shadow-card);
}

// Phones: two queens per row
@media (max-width: 47.99rem) {
  .vote-gallery {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: var(--space-3);
  }

  .vote-card--own {
    grid-column: 1 / -1;

    > .look-card {
      display: none;
    }
  }

  .vote-gallery :deep(.look-card__rank) {
    width: 3rem;
    height: 3rem;
    padding: 0.25rem 0 0 0.5rem;
    font-size: 1.125rem;
  }

  .vote-gallery :deep(.look-card__body) {
    padding: var(--space-2) var(--space-3);
  }

  .vote-gallery :deep(.look-card__name) {
    font-size: 1rem;
  }

  // The zoom button must not cover the photo count badge
  .vote-gallery :deep(.look-card__count) {
    right: var(--space-2);
    bottom: var(--space-2);
    padding: 0 var(--space-2);
    font-size: 0.75rem;
  }
}

// Ballot bar: from tablets up the three picks have their name; on phones a photo with the rank,
// next to the button, so the bar is one short row instead of a third of the screen
.ballot-bar__num,
.ballot-bar__thumb,
.ballot-bar__send,
.ballot-bar__short {
  display: none;
}

@media (max-width: 47.99rem) {
  .ballot-bar__send {
    display: block;
  }

  .ballot-bar__short {
    display: inline;
  }
}

@media (max-width: 47.99rem) {
  .ballot-bar {
    grid-template-columns: auto minmax(0, 1fr);
    gap: var(--space-3);
    align-items: center;
    padding: var(--space-2) var(--space-3);
  }

  .ballot-bar__picks {
    gap: var(--space-2);
  }

  // A short label and a compact button, to the right of the slots
  .ballot-bar__actions {
    justify-items: end;
  }

  // "Votar" / "Actualizar" are replaced by a send icon and the shorter "Enviar" (the long text did not fit)
  .ballot-bar__actions .btn {
    position: relative;
    display: inline-flex;
    gap: var(--space-2);
    align-items: center;
    justify-content: center;
    min-height: 3rem;
    padding: var(--space-2) var(--space-4);
  }

  .ballot-bar__send {
    width: 1.25rem;
    height: 1.25rem;
    flex: none;
  }

  // The real label ("Votar", "Actualizar", "Guardando…") stays for screen readers
  .ballot-bar__label {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip-path: inset(50%);
    white-space: nowrap;
  }

  .ballot-bar__pick {
    position: relative;
    width: 2.75rem;
    height: 3.5rem;
    padding: 0;
    overflow: hidden;
    border-radius: var(--radius-sm);
  }

  // The rank and the name stay for screen readers
  .ballot-bar__rank,
  .ballot-bar__name {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip-path: inset(50%);
    white-space: nowrap;
  }

  .ballot-bar__num {
    position: absolute;
    top: 0;
    left: 0;
    z-index: 1;
    display: grid;
    place-items: center;
    width: 1.25rem;
    height: 1.25rem;
    font-size: 0.75rem;
    font-weight: 800;
    color: var(--color-on-primary);
    background-color: var(--color-primary);
    border-bottom-right-radius: var(--radius-sm);
  }

  .ballot-bar__pick:not(.ballot-bar__pick--filled) .ballot-bar__num {
    top: 50%;
    left: 50%;
    width: auto;
    height: auto;
    color: var(--color-text-muted);
    background: none;
    transform: translate(-50%, -50%);
  }

  .ballot-bar__thumb {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}
</style>
