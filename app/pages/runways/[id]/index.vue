<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { BreadcrumbItem } from '~/components/AppBreadcrumb.vue'
import type { JuryMember } from '~/components/JuryLooks.vue'

type Category = Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text' | 'kind'>
type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status' | 'top_three_revealed'> & { categories: Category[] }

interface RunwayLook {
  id: string
  category_id: string
  image_url: string
  image2_url: string | null
  image3_url: string | null
  image4_url: string | null
  intro: string | null
  participant: Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
}

interface RunwayData {
  runway: Runway
  looks: RunwayLook[]
  /** The judges' looks (not voted on), shown above the queens of their category */
  juryLooks: (LookImages & { id: string, category_id: string, intro: string, participant: Pick<Tables<'participants'>, 'name' | 'drag_name'> })[]
  /** Final place per queen (participant id); only filled once the runway is closed */
  placeByParticipant: Record<string, number>
  /** The signed-in person already cast a ballot (only looked up while voting is open) */
  hasVoted: boolean
}

const route = useRoute()
const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()
const runwayId = String(route.params.id)

// RLS hides draft runways (and their categories and looks) from contestants, so they get a 404
const { data, error: loadError, refresh } = await useAsyncData(
  `runway-${runwayId}`,
  async (): Promise<RunwayData | null> => {
    const runway = await supabase
      .from('runways')
      .select('id, week_number, runway_date, status, top_three_revealed, categories(id, title, intro_text, kind)')
      .eq('id', runwayId)
      .order('created_at', { referencedTable: 'categories', ascending: true })
      .maybeSingle()

    if (runway.error) throw runway.error
    if (!runway.data) return null
    // Before voting opens nobody gets the looks, not even the jury (the page answers 403 below)
    if (!isRunwayPublic(runway.data.status)) {
      return { runway: runway.data, looks: [], juryLooks: [], placeByParticipant: {}, hasVoted: false }
    }

    const [looks, juryLooks, ballot] = await Promise.all([
      supabase
        .from('looks')
        .select('id, category_id, image_url, image2_url, image3_url, image4_url, intro, participant:participants!looks_participant_id_fkey(id, name, drag_name), category:categories!looks_category_id_fkey!inner(runway_id)')
        .eq('category.runway_id', runwayId)
        .order('created_at', { ascending: true }),
      supabase
        .from('jury_looks')
        .select('id, category_id, image_url, image2_url, image3_url, image4_url, intro, participant:participants!jury_looks_participant_id_fkey(name, drag_name), category:categories!jury_looks_category_id_fkey!inner(runway_id)')
        .eq('category.runway_id', runwayId)
        .order('created_at', { ascending: true }),
      // RLS only returns the person's own ballot while voting is open
      runway.data.status === 'voting' && participant.value
        ? supabase.from('votes').select('id').eq('runway_id', runwayId).eq('voter_id', participant.value.id).maybeSingle()
        : null,
    ])

    if (looks.error) throw looks.error
    if (juryLooks.error) throw juryLooks.error
    if (ballot?.error) throw ballot.error

    let placeByParticipant: Record<string, number> = {}
    if (runway.data.status === 'closed') {
      const ranking = await supabase.rpc('runway_ranking', { p_runway_id: runwayId })
      if (ranking.error) throw ranking.error
      placeByParticipant = Object.fromEntries(ranking.data.map(row => [row.participant_id, row.place]))
    }

    return { runway: runway.data, looks: looks.data, juryLooks: juryLooks.data, placeByParticipant, hasVoted: !!ballot?.data }
  },
)

// The final ranking appears as soon as the jurado closes the runway
useRunwaysRealtime(refresh, runwayId)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Semana no encontrada', fatal: true })
}

// The public runway stays closed until voting opens, whoever asks (even by typing the URL)
function blockUntilVoting(): never {
  throw createError({ statusCode: 403, statusMessage: RUNWAY_LOCKED_MESSAGE, fatal: true })
}
if (data.value && !isRunwayPublic(data.value.runway.status)) blockUntilVoting()

// A jurado can move the runway back while someone is looking at it: the realtime refresh brings
// the new status, and the page closes right away instead of showing an empty gallery
watch(
  () => data.value?.runway.status,
  (status) => {
    if (status && !isRunwayPublic(status)) {
      showError({ statusCode: 403, statusMessage: RUNWAY_LOCKED_MESSAGE })
    }
  },
)

const runway = computed(() => data.value?.runway ?? null)
const placeByParticipant = computed(() => data.value?.placeByParticipant ?? {})
const isClosed = computed(() => runway.value?.status === 'closed')
const isVoting = computed(() => runway.value?.status === 'voting')
const hasVoted = computed(() => data.value?.hasVoted ?? false)
const voteLabel = computed(() => (hasVoted.value ? 'Cambiar mi Top 3' : 'Votar a las mejores reinas'))

// One gallery per category. Closed runways list the final ranking first; queens nobody voted for keep their runway order
const sections = computed(() => {
  const place = (look: RunwayLook): number => placeByParticipant.value[look.participant.id] ?? Infinity
  return (runway.value?.categories ?? []).map((category) => {
    const looks = (data.value?.looks ?? []).filter(look => look.category_id === category.id)
    const jury: JuryMember[] = (data.value?.juryLooks ?? [])
      .filter(look => look.category_id === category.id)
      .map(look => ({
        id: look.id,
        name: look.participant.drag_name ?? look.participant.name,
        intro: look.intro,
        photos: lookPhotos(look),
      }))
    return { category, jury, looks: isClosed.value ? [...looks].sort((a, b) => place(a) - place(b)) : looks }
  })
})
const allLooks = computed(() => sections.value.flatMap(section => section.looks))
const hasAnyLooks = computed(() => allLooks.value.length > 0 || sections.value.some(section => section.jury.length > 0))
const hasGroupCategory = computed(() => runway.value?.categories.some(category => category.kind === 'group') ?? false)
const hasSeveralCategories = computed(() => (runway.value?.categories.length ?? 0) > 1)

// Closed runways are reached from "Semanas pasadas", so the trail goes back through it
const breadcrumb = computed<BreadcrumbItem[]>(() => {
  const current = { label: `Semana ${runway.value?.week_number}` }
  return isClosed.value
    ? [{ label: 'Inicio', to: '/' }, { label: 'Semanas pasadas', to: '/runways/past' }, current]
    : [{ label: 'Inicio', to: '/' }, current]
})

const displayName = (look: RunwayLook): string => look.participant.drag_name ?? look.participant.name

// --- Look dialog: every photo of a look ------------------------------------
const fullLook = ref<RunwayLook | null>(null)
const fullLookCategoryTitle = computed(() =>
  hasSeveralCategories.value
    ? runway.value?.categories.find(category => category.id === fullLook.value?.category_id)?.title ?? null
    : null,
)

// Step through the looks in gallery order, wrapping around at both ends
function showAdjacentLook(step: 1 | -1): void {
  const current = allLooks.value.findIndex(look => look.id === fullLook.value?.id)
  if (current === -1) return
  fullLook.value = allLooks.value[(current + step + allLooks.value.length) % allLooks.value.length] ?? null
}
</script>

<template>
  <main v-if="runway" class="page">
    <AppNav />
    <AppBreadcrumb :items="breadcrumb" />

    <header class="page-header">
      <div class="page-header__titles">
        <!-- The day only: the hour of the runway matters in the Werk Room, which is not public -->
        <p class="kicker">
          Semana {{ runway.week_number }} · {{ formatRunwayLongDate(runway.runway_date) }}
        </p>
        <div class="runway-badges">
          <StatusBadge :status="runway.status" />
          <!-- While voting: has this person voted yet? -->
          <span v-if="isVoting" class="badge" :class="hasVoted ? 'badge--approved' : 'badge--pending'">{{ hasVoted ? '✓ Votado' : 'Pendiente' }}</span>
        </div>
        <h1>{{ runwayTitle(runway.categories) }}</h1>
      </div>
      <nav class="page-header__actions">
        <!-- Group runways have their own "Ver resultados" (the band ranking) -->
        <RunwayBallotsResults v-if="isClosed && !hasGroupCategory" :runway-id="runway.id" :week-number="runway.week_number" />
        <NuxtLink v-if="isVoting" :to="`/runways/${runway.id}/vote`" class="btn btn--primary">
          {{ voteLabel }}
        </NuxtLink>
      </nav>
    </header>

    <!-- Phones: jump between the categories of a runway with several; sticks under the top bar -->
    <SectionTabs
      v-if="hasSeveralCategories && hasAnyLooks"
      :items="sections.map(section => section.category)"
      id-prefix="category-"
      label="Categorías de la semana"
    />

    <RunwayCategories v-if="!hasSeveralCategories" :categories="runway.categories" />

    <template v-if="runway.status === 'reveal' || runway.status === 'closed'">
      <GroupCategoryResult
        v-for="category in runway.categories.filter(candidate => candidate.kind === 'group')"
        :key="`${category.id}-${runway.top_three_revealed}`"
        :category="category"
        :show-title="hasSeveralCategories"
      />
    </template>

    <template v-if="hasAnyLooks">
      <section v-for="section in sections" :id="`category-${section.category.id}`" :key="section.category.id" class="section">
        <template v-if="hasSeveralCategories">
          <h2>{{ section.category.title }}</h2>
          <CollapsibleText v-if="section.category.intro_text" class="lead intro" :text="section.category.intro_text" />
        </template>

        <!-- The jury walks first: its looks set the bar and are not voted on -->
        <JuryLooks :members="section.jury" title="El jurado" :level="hasSeveralCategories ? 3 : 2" />

        <CategoryGroupPhotos
          v-if="section.category.kind === 'group'"
          :category-id="section.category.id"
          :level="hasSeveralCategories ? 4 : 3"
          heading="Los grupos"
          :heading-level="hasSeveralCategories ? 3 : 2"
        />

        <component :is="hasSeveralCategories ? 'h3' : 'h2'" v-if="section.jury.length" class="queens-title">
          Las reinas
        </component>

        <!-- Phones: two queens per row, photo and name only (the intro is in the look dialog) -->
        <ul v-if="section.looks.length" class="gallery runway-gallery">
          <li v-for="look in section.looks" :key="look.id">
            <article class="look-card">
              <span v-if="placeByParticipant[look.participant.id]" class="look-card__rank">{{ placeByParticipant[look.participant.id] }}</span>
              <span v-if="placeByParticipant[look.participant.id] === 1" class="look-card__crown" role="img" aria-label="Ganadora">♛</span>
              <button type="button" class="look-card__open" @click="fullLook = look">
                <LookCardPhoto
                  :src="look.image_url"
                  :alt="`Look de ${displayName(look)}`"
                  :count="lookPhotos(look).length"
                />
                <span class="look-card__body">
                  <span class="look-card__name">{{ displayName(look) }}</span>
                  <CollapsibleText v-if="look.intro" class="look-card__intro-text" :text="look.intro" :lines="2" :phones-only="false" inert />
                </span>
              </button>
            </article>
          </li>
        </ul>
        <p v-else class="empty">
          Todavía no hay looks en esta categoría.
        </p>
      </section>
    </template>
    <p v-else class="empty">
      Todavía no hay looks en la pasarela.
    </p>

    <!-- The same vote button at the end of the page, so nobody scrolls back up to vote -->
    <NuxtLink v-if="isVoting && hasAnyLooks" :to="`/runways/${runway.id}/vote`" class="btn btn--primary runway-vote-cta">
      {{ voteLabel }}
    </NuxtLink>

    <BackToTop />

    <LookGalleryDialog
      :open="fullLook !== null"
      :title="fullLook ? displayName(fullLook) : ''"
      :photos="fullLook ? lookPhotos(fullLook) : []"
      :category-title="fullLookCategoryTitle"
      :intro="fullLook?.intro"
      :can-navigate="allLooks.length > 1"
      @previous="showAdjacentLook(-1)"
      @next="showAdjacentLook(1)"
      @close="fullLook = null"
    />
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
// Nothing inside (like the sideways-scrolling tabs) may stretch the page wider than the screen
.page {
  grid-template-columns: minmax(0, 1fr);
}

.page-header__titles {
  justify-items: start;

  // Wider screens: the date and the status badge side by side, the title under them
  @media (min-width: 48rem) {
    grid-template-columns: auto 1fr;
    column-gap: var(--space-3);
    align-items: center;

    > h1 {
      grid-column: 1 / -1;
    }
  }
}

.runway-badges {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: center;
}

.runway-vote-cta {
  justify-self: stretch;
  // Phones: clear of the floating "Volver arriba" button
  margin-bottom: var(--space-5);

  @media (min-width: 48rem) {
    justify-self: start;
    margin-bottom: 0;
  }
}

// Phones: two queens per row, name and photo only; the intro is one tap away in the look dialog
@media (max-width: 47.99rem) {
  .runway-gallery {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: var(--space-3);

    :deep(.look-card__intro-text) {
      display: none;
    }

    :deep(.look-card__rank) {
      width: 3rem;
      height: 3rem;
      padding: 0.25rem 0 0 0.5rem;
      font-size: 1.125rem;
    }

    :deep(.look-card__crown) {
      top: var(--space-2);
      right: var(--space-2);
      width: 2rem;
      height: 2rem;
      font-size: 1.125rem;
    }

    :deep(.look-card__body) {
      padding: var(--space-2) var(--space-3);
    }

    :deep(.look-card__name) {
      font-size: 1rem;
    }

    :deep(.look-card__count) {
      right: var(--space-2);
      bottom: var(--space-2);
      padding: 0 var(--space-2);
      font-size: 0.75rem;
    }
  }
}

// Phones: the action buttons take a full row each
.page-header__actions {
  @media (max-width: 47.99rem) {
    flex-direction: column;
    align-items: stretch;
    width: 100%;

    > .btn {
      width: 100%;
    }
  }
}

.queens-title {
  font-size: 1.25rem;
}

.intro {
  max-width: 44rem;
}
</style>
