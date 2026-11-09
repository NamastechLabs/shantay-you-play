<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { BreadcrumbItem } from '~/components/AppBreadcrumb.vue'
import type { JuryMember } from '~/components/JuryLooks.vue'

type Category = Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text'>
type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'> & { categories: Category[] }

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
}

const route = useRoute()
const supabase = useSupabaseClient()
const runwayId = String(route.params.id)

// RLS hides draft runways (and their categories and looks) from contestants, so they get a 404
const { data, error: loadError, refresh } = await useAsyncData(
  `runway-${runwayId}`,
  async (): Promise<RunwayData | null> => {
    const runway = await supabase
      .from('runways')
      .select('id, week_number, runway_date, status, categories(id, title, intro_text)')
      .eq('id', runwayId)
      .order('created_at', { referencedTable: 'categories', ascending: true })
      .maybeSingle()

    if (runway.error) throw runway.error
    if (!runway.data) return null
    // Before voting opens nobody gets the looks, not even the jury (the page answers 403 below)
    if (!isRunwayPublic(runway.data.status)) {
      return { runway: runway.data, looks: [], juryLooks: [], placeByParticipant: {} }
    }

    const [looks, juryLooks] = await Promise.all([
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
    ])

    if (looks.error) throw looks.error
    if (juryLooks.error) throw juryLooks.error

    let placeByParticipant: Record<string, number> = {}
    if (runway.data.status === 'closed') {
      const ranking = await supabase.rpc('runway_ranking', { p_runway_id: runwayId })
      if (ranking.error) throw ranking.error
      placeByParticipant = Object.fromEntries(ranking.data.map(row => [row.participant_id, row.place]))
    }

    return { runway: runway.data, looks: looks.data, juryLooks: juryLooks.data, placeByParticipant }
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

    <template v-if="hasAnyLooks">
      <section v-for="section in sections" :key="section.category.id" class="section">
        <template v-if="hasSeveralCategories">
          <h2>{{ section.category.title }}</h2>
          <p v-if="section.category.intro_text" class="lead intro">
            {{ section.category.intro_text }}
          </p>
        </template>

        <!-- The jury walks first: its looks set the bar and are not voted on -->
        <JuryLooks :members="section.jury" title="El jurado" :level="hasSeveralCategories ? 3 : 2" />

        <component :is="hasSeveralCategories ? 'h3' : 'h2'" v-if="section.jury.length" class="queens-title">
          Las reinas
        </component>

        <ul v-if="section.looks.length" class="gallery">
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
                  <span v-if="look.intro" class="look-card__intro">{{ look.intro }}</span>
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

<style scoped>
.queens-title {
  font-size: 1.25rem;
}

.intro {
  max-width: 44rem;
  white-space: pre-line;
}
</style>
