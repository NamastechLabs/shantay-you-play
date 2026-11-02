<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type OpenCategory = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'intro_text' | 'status'>

interface TopLook {
  id: string
  place: number
  image_url: string
  name: string
}

interface HomeData {
  categories: OpenCategory[]
  /** Voting categories where the current participant already cast a ballot */
  votedCategoryIds: string[]
  /** Top 3 of the category being revealed (empty when there is none) */
  topThree: TopLook[]
}

interface CategoryAction {
  to: string
  label: string
}

const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()

// RLS already hides drafts from contestants
const { data, error } = await useAsyncData('home', async (): Promise<HomeData> => {
  const { data: categories, error } = await supabase
    .from('categories')
    .select('id, week_number, title, intro_text, status')
    .in('status', ['runway', 'voting', 'reveal'])
    .order('week_number', { ascending: false })

  if (error) throw error

  const revealCategory = categories.find(category => category.status === 'reveal')
  const [topThree, votedCategoryIds] = await Promise.all([
    revealCategory ? loadTopThree(revealCategory.id) : [],
    loadVotedCategoryIds(categories),
  ])

  return { categories, votedCategoryIds, topThree }
})

async function loadTopThree(categoryId: string): Promise<TopLook[]> {
  const { data: ranking, error: rankingError } = await supabase.rpc('category_top_three', { p_category_id: categoryId })
  if (rankingError) throw rankingError
  if (!ranking.length) return []

  const { data: looks, error: looksError } = await supabase
    .from('looks')
    .select('id, image_url, participant:participants!looks_participant_id_fkey(name, drag_name)')
    .in('id', ranking.map(row => row.look_id))
  if (looksError) throw looksError

  const placeByLook = new Map(ranking.map(row => [row.look_id, row.place]))
  return looks.map(look => ({
    id: look.id,
    place: placeByLook.get(look.id) ?? 0,
    image_url: look.image_url,
    name: look.participant.drag_name ?? look.participant.name,
  }))
}

async function loadVotedCategoryIds(categories: OpenCategory[]): Promise<string[]> {
  const votingIds = categories.filter(category => category.status === 'voting').map(category => category.id)
  if (!votingIds.length || !participant.value) return []

  const { data: ballots, error: ballotsError } = await supabase
    .from('votes')
    .select('category_id')
    .eq('voter_id', participant.value.id)
    .in('category_id', votingIds)

  if (ballotsError) throw ballotsError
  return ballots.map(ballot => ballot.category_id)
}

// Several categories can be open at once (last week still voting while the new runway opens):
// a category being revealed takes the stage, otherwise the newest one is the week's category.
// The rest stay reachable below it.
const weekCategory = computed(() =>
  data.value?.categories.find(category => category.status === 'reveal') ?? data.value?.categories[0] ?? null,
)
const otherOpenCategories = computed(() =>
  data.value?.categories.filter(category => category.id !== weekCategory.value?.id) ?? [],
)
const revealedTopThree = computed(() => (weekCategory.value?.status === 'reveal' ? data.value?.topThree ?? [] : []))

const STATUS_HINTS: Record<OpenCategory['status'], string> = {
  draft: '',
  runway: 'La votación abrirá pronto.',
  voting: '',
  reveal: 'Pronto se revelará el Top 3.',
  closed: '',
}

// The runway stays hidden until voting opens, so only voting categories have an action
function primaryAction(category: OpenCategory): CategoryAction | null {
  if (category.status !== 'voting') return null
  const hasVoted = data.value?.votedCategoryIds.includes(category.id) ?? false
  return { to: `/categories/${category.id}/vote`, label: hasVoted ? 'Cambiar mi Top 3' : 'Votar los mejores looks' }
}
</script>

<template>
  <main class="page">
    <AppNav />

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <section v-else-if="weekCategory" class="week-hero" aria-labelledby="week-title">
      <p class="kicker week-hero__kicker">
        Categoría de la semana · Semana {{ weekCategory.week_number }}
        <StatusBadge :status="weekCategory.status" />
      </p>

      <h1 id="week-title" class="display week-hero__title">
        {{ weekCategory.title }}
      </h1>
      <span class="rule" aria-hidden="true" />

      <p v-if="weekCategory.intro_text" class="lead week-hero__intro">
        {{ weekCategory.intro_text }}
      </p>

      <p class="week-hero__status">
        {{ weekCategory.status === 'voting'
          ? '¡La votación está abierta! Elige tu Top 3 de la semana.'
          : weekCategory.status === 'reveal'
            ? '¡La votación terminó! Estas son las tres mejores reinas de la semana.'
            : 'Las reinas ya están en la pasarela. La votación abrirá pronto.' }}
      </p>

      <TopThreeReveal
        v-if="revealedTopThree.length"
        :key="weekCategory.id"
        class="week-hero__reveal"
        :looks="revealedTopThree"
      />

      <div v-if="primaryAction(weekCategory)" class="actions">
        <NuxtLink :to="primaryAction(weekCategory)!.to" class="btn btn--primary">
          {{ primaryAction(weekCategory)!.label }}
        </NuxtLink>
        <NuxtLink :to="`/categories/${weekCategory.id}`" class="btn btn--secondary">
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

    <section v-if="otherOpenCategories.length" class="section" aria-labelledby="open-title">
      <h2 id="open-title">
        Siguen abiertas
      </h2>
      <ul class="row-list">
        <li v-for="category in otherOpenCategories" :key="category.id">
          <NuxtLink v-if="primaryAction(category)" :to="primaryAction(category)!.to" class="row row--link">
            <span class="row__main">
              <span class="row__title">Semana {{ category.week_number }} · {{ category.title }}</span>
              <span class="muted">{{ primaryAction(category)!.label }}</span>
            </span>
            <StatusBadge :status="category.status" />
          </NuxtLink>
          <div v-else class="row">
            <span class="row__main">
              <span class="row__title">Semana {{ category.week_number }} · {{ category.title }}</span>
              <span class="muted">{{ STATUS_HINTS[category.status] }}</span>
            </span>
            <StatusBadge :status="category.status" />
          </div>
        </li>
      </ul>
    </section>

    <NuxtLink to="/categories/past" class="row row--link past-link">
      <span class="row__main">
        <span class="row__title">Categorías pasadas</span>
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
}

.week-hero__title {
  font-size: clamp(2rem, 1.5rem + 2.5vw, 3rem);
  overflow-wrap: anywhere;
}

.week-hero__intro {
  max-width: 40rem;
  white-space: pre-line;
}

.week-hero__status {
  font-weight: 600;
}

.week-hero__reveal {
  justify-self: stretch;
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
