<script setup lang="ts">
import type { Tables } from '~/types/database.types'

interface OpenRunway extends Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'> {
  categories: Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text'>[]
}

interface JuryMember {
  id: string
  image_url: string
  intro: string
  name: string
  /** Only set when the runway has several categories */
  categoryTitle: string | null
}

interface HomeData {
  runways: OpenRunway[]
  /** Voting runways where the current participant already cast a ballot */
  votedRunwayIds: string[]
  /** Top 3 queens of the runway being revealed (empty when there is none) */
  topThree: RunwayQueen[]
  /** Judges' looks of the week's runway while it is on the runway (empty otherwise) */
  jury: JuryMember[]
  /** Most recent closed runway with its winner (null when none has closed yet) */
  previousWeek: { runway: OpenRunway, winner: RunwayQueen | null } | null
}

interface RunwayAction {
  to: string
  label: string
}

const RUNWAY_COLUMNS = 'id, week_number, runway_date, status, categories(id, title, intro_text)'

const supabase = useSupabaseClient()
const { loadTopThree, loadWinners } = useRunwayResults()
const { participant } = useCurrentParticipant()

// RLS already hides drafts from contestants
const { data, error, refresh } = await useAsyncData('home', async (): Promise<HomeData> => {
  const { data: runways, error } = await supabase
    .from('runways')
    .select(RUNWAY_COLUMNS)
    .in('status', ['werk_room', 'runway', 'voting', 'reveal'])
    .order('week_number', { ascending: false })
    .order('created_at', { referencedTable: 'categories', ascending: true })

  if (error) throw error

  const revealRunway = runways.find(runway => runway.status === 'reveal')
  const featured = pickWeekRunway(runways)
  const [topThree, votedRunwayIds, jury, previousWeek] = await Promise.all([
    revealRunway ? loadTopThree(revealRunway.id) : [],
    loadVotedRunwayIds(runways),
    featured?.status === 'runway' ? loadJury(featured) : [],
    loadPreviousWeek(),
  ])

  return { runways, votedRunwayIds, topThree, jury, previousWeek }
})

async function loadPreviousWeek(): Promise<HomeData['previousWeek']> {
  const { data: closed, error: closedError } = await supabase
    .from('runways')
    .select(RUNWAY_COLUMNS)
    .eq('status', 'closed')
    .order('week_number', { ascending: false })
    .order('created_at', { referencedTable: 'categories', ascending: true })
    .limit(1)
  if (closedError) throw closedError

  const runway = closed[0]
  if (!runway) return null
  const winners = await loadWinners([runway.id])
  return { runway, winner: winners[runway.id] ?? null }
}

// Status changes (voting -> reveal -> closed) reach everyone without a page refresh
useRunwaysRealtime(refresh)

async function loadJury(runway: OpenRunway): Promise<JuryMember[]> {
  const categoryIds = runway.categories.map(category => category.id)
  if (!categoryIds.length) return []

  const { data: rows, error: juryError } = await supabase
    .from('jury_looks')
    .select('id, category_id, image_url, intro, participant:participants!jury_looks_participant_id_fkey(name, drag_name)')
    .in('category_id', categoryIds)
    .order('created_at', { ascending: true })
  if (juryError) throw juryError

  const titleByCategory = new Map(runway.categories.map(category => [category.id, category.title]))
  return rows.map(row => ({
    id: row.id,
    image_url: row.image_url,
    intro: row.intro,
    name: row.participant.drag_name ?? row.participant.name,
    categoryTitle: runway.categories.length > 1 ? titleByCategory.get(row.category_id) ?? null : null,
  }))
}

async function loadVotedRunwayIds(runways: OpenRunway[]): Promise<string[]> {
  const votingIds = runways.filter(runway => runway.status === 'voting').map(runway => runway.id)
  if (!votingIds.length || !participant.value) return []

  const { data: ballots, error: ballotsError } = await supabase
    .from('votes')
    .select('runway_id')
    .eq('voter_id', participant.value.id)
    .in('runway_id', votingIds)

  if (ballotsError) throw ballotsError
  return ballots.map(ballot => ballot.runway_id)
}

// Several runways can be open at once (last week still voting while the new one opens):
// a runway being revealed takes the stage, otherwise the newest one is the week's runway.
// The rest stay reachable below it.
function pickWeekRunway(runways: OpenRunway[]): OpenRunway | null {
  return runways.find(runway => runway.status === 'reveal') ?? runways[0] ?? null
}
const weekRunway = computed(() => pickWeekRunway(data.value?.runways ?? []))
const otherOpenRunways = computed(() =>
  data.value?.runways.filter(runway => runway.id !== weekRunway.value?.id) ?? [],
)
const revealedTopThree = computed(() => (weekRunway.value?.status === 'reveal' ? data.value?.topThree ?? [] : []))
const runwayJury = computed(() => (weekRunway.value?.status === 'runway' ? data.value?.jury ?? [] : []))

const STATUS_HINTS: Record<OpenRunway['status'], string> = {
  draft: '',
  werk_room: 'Las reinas se preparan en el Werk Room.',
  runway: 'La votación abrirá pronto.',
  voting: '',
  reveal: 'Pronto se revelará el Top 3.',
  closed: '',
}

// The runway stays hidden until voting opens, so only voting runways have an action
function primaryAction(runway: OpenRunway): RunwayAction | null {
  if (runway.status !== 'voting') return null
  const hasVoted = data.value?.votedRunwayIds.includes(runway.id) ?? false
  return { to: `/runways/${runway.id}/vote`, label: hasVoted ? 'Cambiar mi Top 3' : 'Votar a las mejores reinas' }
}
</script>

<template>
  <main class="page">
    <AppNav />

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <section v-else-if="weekRunway" class="week-hero" aria-labelledby="week-title">
      <p class="kicker week-hero__kicker">
        {{ weekRunway.categories.length > 1 ? 'Categorías de la semana' : 'Categoría de la semana' }} · Semana {{ weekRunway.week_number }} · {{ formatRunwayDate(weekRunway.runway_date) }}
        <StatusBadge :status="weekRunway.status" />
      </p>

      <h1 id="week-title" class="display week-hero__title">
        {{ runwayTitle(weekRunway.categories) }}
      </h1>
      <span class="rule" aria-hidden="true" />

      <RunwayCategories :categories="weekRunway.categories" />

      <p class="week-hero__status">
        {{ weekRunway.status === 'voting'
          ? '¡La votación está abierta! Elige tu Top 3 de reinas de la semana.'
          : weekRunway.status === 'reveal'
            ? '¡La votación terminó! Estas son las tres mejores reinas de la semana.'
            : weekRunway.status === 'werk_room'
              ? 'Las reinas se están preparando en el Werk Room. ¡La pasarela abrirá pronto!'
              : 'Las reinas ya están en la pasarela. La votación abrirá pronto.' }}
      </p>

      <section v-if="runwayJury.length" class="jury" aria-labelledby="jury-title">
        <h2 id="jury-title" class="jury__title">
          El jurado en la pasarela
        </h2>
        <ul class="jury__list">
          <li v-for="member in runwayJury" :key="member.id" class="jury__card">
            <img class="jury__photo" :src="member.image_url" :alt="`Look de ${member.name}`" loading="lazy">
            <div class="jury__body">
              <strong class="jury__name">{{ member.name }}</strong>
              <span v-if="member.categoryTitle" class="muted">{{ member.categoryTitle }}</span>
              <p class="jury__intro">
                {{ member.intro }}
              </p>
            </div>
          </li>
        </ul>
      </section>

      <TopThreeReveal
        v-if="revealedTopThree.length"
        :key="weekRunway.id"
        class="week-hero__reveal"
        :queens="revealedTopThree"
      />

      <!-- Queens upload their own look while the week is in the Werk Room -->
      <div v-if="weekRunway.status === 'werk_room' && participant?.role === 'concursante'" class="actions">
        <NuxtLink :to="`/semana/${weekRunway.week_number}/werk-room`" class="btn btn--primary">
          Ya tienes tu look, súbelo
        </NuxtLink>
      </div>

      <div v-if="primaryAction(weekRunway)" class="actions">
        <NuxtLink :to="primaryAction(weekRunway)!.to" class="btn btn--primary">
          {{ primaryAction(weekRunway)!.label }}
        </NuxtLink>
        <NuxtLink :to="`/runways/${weekRunway.id}`" class="btn btn--secondary">
          Ver la pasarela
        </NuxtLink>
      </div>
    </section>

    <section v-else class="week-empty" aria-labelledby="week-empty-title">
      <span class="week-empty__icon" aria-hidden="true">♛</span>
      <h1 id="week-empty-title">
        La pasarela está en pausa
      </h1>
      <p class="lead">
        El jurado está preparando la próxima categoría. ¡Vuelve pronto, reina!
      </p>
    </section>

    <section v-if="otherOpenRunways.length" class="section" aria-labelledby="open-title">
      <h2 id="open-title">
        Siguen abiertas
      </h2>
      <ul class="row-list">
        <li v-for="runway in otherOpenRunways" :key="runway.id">
          <NuxtLink v-if="primaryAction(runway)" :to="primaryAction(runway)!.to" class="row row--link">
            <span class="row__main">
              <span class="row__title">Semana {{ runway.week_number }} · {{ runwayTitle(runway.categories) }}</span>
              <span class="muted">{{ primaryAction(runway)!.label }}</span>
            </span>
            <StatusBadge :status="runway.status" />
          </NuxtLink>
          <div v-else class="row">
            <span class="row__main">
              <span class="row__title">Semana {{ runway.week_number }} · {{ runwayTitle(runway.categories) }}</span>
              <span class="muted">{{ STATUS_HINTS[runway.status] }}</span>
            </span>
            <StatusBadge :status="runway.status" />
          </div>
        </li>
      </ul>
    </section>

    <section v-if="data?.previousWeek" class="section" aria-labelledby="previous-title">
      <h2 id="previous-title">
        La semana pasada
      </h2>
      <PastRunwayCard :runway="data.previousWeek.runway" :winner="data.previousWeek.winner" />
    </section>

    <NuxtLink to="/runways/past" class="row row--link past-link">
      <span class="row__main">
        <span class="row__title">Semanas pasadas</span>
        <span class="muted">Revive cada pasarela de la temporada.</span>
      </span>
      <span aria-hidden="true">→</span>
    </NuxtLink>
  </main>
</template>

<style scoped lang="scss">
.week-hero {
  position: relative;
  display: grid;
  gap: var(--space-4);
  justify-items: start;
  padding: var(--space-6) var(--space-4);
  overflow: hidden;
  background:
    radial-gradient(28rem 18rem at 100% 0%, color-mix(in srgb, var(--color-primary) 28%, transparent), transparent 70%),
    radial-gradient(22rem 16rem at 0% 100%, color-mix(in srgb, var(--color-accent) 24%, transparent), transparent 70%),
    var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card), var(--glow-primary);

  @media (min-width: 48rem) {
    padding: var(--space-7) var(--space-6);
  }
}

.week-hero__kicker {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: center;
  justify-content: space-between;
  justify-self: stretch;
}

.week-hero__title {
  font-size: clamp(2rem, 1.5rem + 2.5vw, 3rem);
  overflow-wrap: anywhere;
}

.week-hero__status {
  font-weight: 600;
}

.week-hero__reveal {
  justify-self: stretch;
}

.jury {
  display: grid;
  gap: var(--space-4);
  justify-self: stretch;
}

.jury__title {
  font-size: 1.25rem;
}

.jury__list {
  display: grid;
  gap: var(--space-4);
  padding: 0;
  margin: 0;
  list-style: none;

  @media (min-width: 48rem) {
    grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
  }
}

.jury__card {
  display: grid;
  grid-template-columns: 6rem 1fr;
  gap: var(--space-3);
  align-items: start;
  padding: var(--space-3);
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);
}

.jury__photo {
  width: 100%;
  aspect-ratio: 3 / 4;
  object-fit: cover;
  border-radius: var(--radius-sm);
}

.jury__body {
  display: grid;
  gap: var(--space-2);
}

.jury__name {
  font-family: var(--font-display);
  font-size: 1.125rem;
  line-height: 1.3;
  color: var(--color-title);
}

.jury__intro {
  white-space: pre-line;
}

.week-hero .actions {
  width: 100%;

  @media (max-width: 30rem) {
    > .btn {
      flex: 1 1 100%;
    }
  }
}

.week-empty {
  display: grid;
  gap: var(--space-3);
  justify-items: center;
  padding: var(--space-7) var(--space-4);
  text-align: center;
  background-color: var(--color-surface);
  border: 2px dashed var(--color-border);
  border-radius: var(--radius-lg);
}

.week-empty__icon {
  display: grid;
  place-items: center;
  width: 4rem;
  height: 4rem;
  font-size: 2rem;
  color: var(--color-title);
  background-color: color-mix(in srgb, var(--color-highlight) 30%, var(--color-surface));
  border-radius: var(--radius-pill);
  box-shadow: var(--glow-accent);
}

.week-empty .lead {
  max-width: 28rem;
}

.past-link .row__title {
  font-size: 1.125rem;
}
</style>
