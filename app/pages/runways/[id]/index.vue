<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { BreadcrumbItem } from '~/components/AppBreadcrumb.vue'

type Category = Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text'>
type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'> & { categories: Category[] }

interface RunwayLook {
  id: string
  category_id: string
  image_url: string
  intro: string | null
  participant: Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
}

interface RunwayData {
  runway: Runway
  looks: RunwayLook[]
  /** Final place per queen (participant id); only filled once the runway is closed */
  placeByParticipant: Record<string, number>
}

const route = useRoute()
const supabase = useSupabaseClient()
const runwayId = String(route.params.id)

// RLS hides draft runways (and their categories and looks) from contestants, so they get a 404
const { data, error: loadError, refresh } = await useAsyncData(
  `runway-${runwayId}`,
  async (): Promise<RunwayData | null> => {
    const [runway, looks] = await Promise.all([
      supabase
        .from('runways')
        .select('id, week_number, runway_date, status, categories(id, title, intro_text)')
        .eq('id', runwayId)
        .order('created_at', { referencedTable: 'categories', ascending: true })
        .maybeSingle(),
      supabase
        .from('looks')
        .select('id, category_id, image_url, intro, participant:participants!looks_participant_id_fkey(id, name, drag_name), category:categories!looks_category_id_fkey!inner(runway_id)')
        .eq('category.runway_id', runwayId)
        .order('created_at', { ascending: true }),
    ])

    if (runway.error) throw runway.error
    if (looks.error) throw looks.error
    if (!runway.data) return null

    let placeByParticipant: Record<string, number> = {}
    if (runway.data.status === 'closed') {
      const ranking = await supabase.rpc('runway_ranking', { p_runway_id: runwayId })
      if (ranking.error) throw ranking.error
      placeByParticipant = Object.fromEntries(ranking.data.map(row => [row.participant_id, row.place]))
    }

    return { runway: runway.data, looks: looks.data, placeByParticipant }
  },
)

// The final ranking appears as soon as the jurado closes the runway
useRunwaysRealtime(refresh, runwayId)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Semana no encontrada', fatal: true })
}

const runway = computed(() => data.value?.runway ?? null)
const placeByParticipant = computed(() => data.value?.placeByParticipant ?? {})
const isClosed = computed(() => runway.value?.status === 'closed')

// One gallery per category. Closed runways list the final ranking first; queens nobody voted for keep their runway order
const sections = computed(() => {
  const place = (look: RunwayLook): number => placeByParticipant.value[look.participant.id] ?? Infinity
  return (runway.value?.categories ?? []).map((category) => {
    const looks = (data.value?.looks ?? []).filter(look => look.category_id === category.id)
    return { category, looks: isClosed.value ? [...looks].sort((a, b) => place(a) - place(b)) : looks }
  })
})
const allLooks = computed(() => sections.value.flatMap(section => section.looks))
const hasSeveralCategories = computed(() => (runway.value?.categories.length ?? 0) > 1)

// Closed runways are reached from "Semanas pasadas", so the trail goes back through it
const breadcrumb = computed<BreadcrumbItem[]>(() => {
  const current = { label: `Semana ${runway.value?.week_number}` }
  return isClosed.value
    ? [{ label: 'Inicio', to: '/' }, { label: 'Semanas pasadas', to: '/runways/past' }, current]
    : [{ label: 'Inicio', to: '/' }, current]
})

const displayName = (look: RunwayLook): string => look.participant.drag_name ?? look.participant.name

// --- Enlarged view --------------------------------------------------------
const selectedLook = ref<RunwayLook | null>(null)
const selectedCategoryTitle = computed(() =>
  hasSeveralCategories.value
    ? runway.value?.categories.find(category => category.id === selectedLook.value?.category_id)?.title ?? null
    : null,
)

// Step through the looks in gallery order, wrapping around at both ends
function showAdjacentLook(step: 1 | -1): void {
  const current = allLooks.value.findIndex(look => look.id === selectedLook.value?.id)
  if (current === -1) return
  selectedLook.value = allLooks.value[(current + step + allLooks.value.length) % allLooks.value.length] ?? null
}
</script>

<template>
  <main v-if="runway" class="page page--wide">
    <AppNav />
    <AppBreadcrumb :items="breadcrumb" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Semana {{ runway.week_number }} · {{ formatRunwayDate(runway.runway_date) }}
          <StatusBadge :status="runway.status" />
        </p>
        <h1>{{ runwayTitle(runway.categories) }}</h1>
      </div>
      <nav class="page-header__actions">
        <NuxtLink v-if="runway.status === 'voting'" :to="`/runways/${runway.id}/vote`" class="btn btn--primary">
          Votar a las mejores reinas
        </NuxtLink>
      </nav>
    </header>

    <RunwayCategories v-if="!hasSeveralCategories" :categories="runway.categories" />

    <template v-if="allLooks.length">
      <section v-for="section in sections" :key="section.category.id" class="section">
        <template v-if="hasSeveralCategories">
          <h2>{{ section.category.title }}</h2>
          <p v-if="section.category.intro_text" class="lead intro">
            {{ section.category.intro_text }}
          </p>
        </template>

        <ul v-if="section.looks.length" class="gallery">
          <li v-for="look in section.looks" :key="look.id">
            <button type="button" class="look-card" @click="selectedLook = look">
              <span v-if="placeByParticipant[look.participant.id]" class="look-card__rank">{{ placeByParticipant[look.participant.id] }}</span>
              <span v-if="placeByParticipant[look.participant.id] === 1" class="look-card__crown" role="img" aria-label="Ganadora">♛</span>
              <img
                class="look-card__photo"
                :src="look.image_url"
                :alt="`Look de ${displayName(look)}`"
                loading="lazy"
              >
              <span class="look-card__body">
                <span class="look-card__name">{{ displayName(look) }}</span>
                <span v-if="look.intro" class="look-card__intro">{{ look.intro }}</span>
              </span>
            </button>
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

    <AppModal wide :open="selectedLook !== null" :title="selectedLook ? displayName(selectedLook) : ''" @close="selectedLook = null">
      <figure v-if="selectedLook" class="look-full">
        <img :src="selectedLook.image_url" :alt="`Look de ${displayName(selectedLook)}`">
        <figcaption class="look-full__intro">
          <strong v-if="selectedCategoryTitle">{{ selectedCategoryTitle }}</strong>
          <template v-if="selectedLook.intro">
            {{ selectedLook.intro }}
          </template>
        </figcaption>
        <nav v-if="allLooks.length > 1" class="look-full__nav" aria-label="Navegar entre looks">
          <button type="button" class="btn btn--secondary" @click="showAdjacentLook(-1)">
            ← Look anterior
          </button>
          <button type="button" class="btn btn--secondary" @click="showAdjacentLook(1)">
            Look siguiente →
          </button>
        </nav>
      </figure>
    </AppModal>
  </main>

  <main v-else class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }]" />
    <p class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
  </main>
</template>

<style scoped>
.intro {
  max-width: 44rem;
  white-space: pre-line;
}
</style>
