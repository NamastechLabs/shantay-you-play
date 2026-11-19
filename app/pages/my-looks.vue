<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { RunwayStatus } from '~/utils/runwayStatus'

interface MyLook {
  id: string
  image_url: string
  image2_url: string | null
  image3_url: string | null
  image4_url: string | null
  intro: string | null
  category: Pick<Tables<'categories'>, 'id' | 'title'> & {
    runway: Pick<Tables<'runways'>, 'id' | 'week_number' | 'status'>
  }
  /** Final place of the queen in the runway; null while it is not public or she got no votes */
  place: number | null
  totalPoints: number | null
}

interface MyLooks {
  /** Looks on the runway as a queen (table looks): ranked */
  queen: MyLook[]
  /** Looks as a judge or special guest (table jury_looks): never ranked */
  jury: MyLook[]
}

const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()

const JURY_LOOK_COLUMNS = 'id, image_url, image2_url, image3_url, image4_url, intro, category:categories!jury_looks_category_id_fkey(id, title, runway:runways!categories_runway_id_fkey(id, week_number, status))'
const QUEEN_LOOK_COLUMNS = 'id, image_url, image2_url, image3_url, image4_url, intro, category:categories!looks_category_id_fkey(id, title, runway:runways!categories_runway_id_fkey(id, week_number, status))'

const isJury = computed(() => participant.value?.role !== undefined && participant.value.role !== 'concursante')

function newestWeekFirst(a: MyLook, b: MyLook): number {
  return b.category.runway.week_number - a.category.runway.week_number
}

// A person can have rows in both tables (e.g. a special guest later promoted to queen), so both are read.
// Only the signed-in participant's own looks; draft runways stay hidden by RLS for queens
const { data, error } = await useAsyncData('my-looks', async (): Promise<MyLooks> => {
  const participantId = participant.value?.id
  if (!participantId) return { queen: [], jury: [] }

  const [juryResult, queenResult] = await Promise.all([
    supabase.from('jury_looks').select(JURY_LOOK_COLUMNS).eq('participant_id', participantId),
    supabase.from('looks').select(QUEEN_LOOK_COLUMNS).eq('participant_id', participantId),
  ])
  if (juryResult.error) throw juryResult.error
  if (queenResult.error) throw queenResult.error

  const jury = juryResult.data
    .map(row => ({ ...row, place: null, totalPoints: null }))
    .sort(newestWeekFirst)
  const rows = queenResult.data

  // The ranking is public from 'reveal' (Top 3 only) and complete once 'closed'
  const rankedRunways = [...new Map(
    rows
      .filter(row => row.category.runway.status === 'reveal' || row.category.runway.status === 'closed')
      .map(row => [row.category.runway.id, row.category.runway.status]),
  )]

  const rankings = await Promise.all(rankedRunways.map(async ([runwayId, status]) => {
    const { data: ranking, error: rankingError } = status === 'closed'
      ? await supabase.rpc('runway_ranking', { p_runway_id: runwayId })
      : await supabase.rpc('runway_top_three', { p_runway_id: runwayId })
    if (rankingError) throw rankingError
    return [runwayId, ranking.find(row => row.participant_id === participantId)] as const
  }))
  const resultByRunway = new Map(rankings)

  const queen = rows
    .map(row => ({
      ...row,
      place: resultByRunway.get(row.category.runway.id)?.place ?? null,
      totalPoints: resultByRunway.get(row.category.runway.id)?.total_points ?? null,
    }))
    .sort(newestWeekFirst)

  return { queen, jury }
})

const queenLooks = computed(() => data.value?.queen ?? [])
const juryLooks = computed(() => data.value?.jury ?? [])
// Page order: queen looks first, then jury looks (the dialog steps through both)
const looks = computed(() => [...queenLooks.value, ...juryLooks.value])
const sections = computed(() => [
  { key: 'queen', title: 'Como concursante', items: queenLooks.value, ranked: true },
  { key: 'jury', title: isJury.value ? 'Looks de jurado' : 'Como jurado o invitada especial', items: juryLooks.value, ranked: false },
].filter(section => section.items.length > 0))
// A single section needs no heading
const showSectionTitles = computed(() => sections.value.length > 1)
const queenName = computed(() => participant.value?.drag_name ?? participant.value?.name ?? '')

// --- Look dialog: every photo of a look ------------------------------------
const fullLook = ref<MyLook | null>(null)

// Step through the looks in page order, wrapping around at both ends
function showAdjacentLook(step: 1 | -1): void {
  const current = looks.value.findIndex(look => look.id === fullLook.value?.id)
  if (current === -1) return
  fullLook.value = looks.value[(current + step + looks.value.length) % looks.value.length] ?? null
}

/** What to show instead of a place when the queen has none */
function pendingLabel(look: MyLook): string {
  const labels: Partial<Record<RunwayStatus, string>> = {
    runway: 'En pasarela',
    voting: 'Votación en curso',
    reveal: 'Fuera del Top 3',
    closed: 'Sin votos',
  }
  return labels[look.category.runway.status] ?? ''
}
</script>

<template>
  <main class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Mis looks' }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          {{ APP_NAME }}
        </p>
        <h1>Mis looks</h1>
      </div>
    </header>

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <template v-else-if="looks.length">
      <section v-for="section in sections" :key="section.key" class="section">
        <h2 v-if="showSectionTitles">
          {{ section.title }}
        </h2>
        <ul class="gallery">
          <li v-for="look in section.items" :key="look.id">
            <article class="look-card">
              <span v-if="look.place" class="look-card__rank">{{ look.place }}</span>
              <span v-if="look.place === 1" class="look-card__crown" role="img" aria-label="Ganadora">♛</span>
              <!-- Only the photo opens the dialog; the title below goes to the runway -->
              <button
                type="button"
                class="look-card__open"
                :aria-label="`Ver mi look de la semana ${look.category.runway.week_number}`"
                @click="fullLook = look"
              >
                <LookCardPhoto
                  :src="look.image_url"
                  :alt="`Mi look de la semana ${look.category.runway.week_number}`"
                  :count="lookPhotos(look).length"
                />
              </button>
              <NuxtLink :to="`/runways/${look.category.runway.id}`" class="look-card__body look-card__link">
                <span class="look-card__name">{{ look.category.title }}</span>
                <span class="look-card__intro">
                  Semana {{ look.category.runway.week_number }} ·
                  <template v-if="look.place">
                    Puesto {{ look.place }}<template v-if="look.totalPoints !== null"> · {{ look.totalPoints }} pts</template> ·
                  </template>
                  <template v-else-if="section.ranked">{{ pendingLabel(look) }} ·</template>
                  Ver pasarela →
                </span>
              </NuxtLink>
            </article>
          </li>
        </ul>
      </section>
    </template>

    <p v-else class="empty">
      {{ isJury ? 'Todavía no tienes looks de jurado.' : 'Todavía no has desfilado en ninguna pasarela.' }}
    </p>

    <LookGalleryDialog
      :open="fullLook !== null"
      :title="queenName"
      :photos="fullLook ? lookPhotos(fullLook) : []"
      :category-title="fullLook?.category.title"
      :intro="fullLook?.intro"
      :can-navigate="looks.length > 1"
      @previous="showAdjacentLook(-1)"
      @next="showAdjacentLook(1)"
      @close="fullLook = null"
    />
  </main>
</template>

<style scoped lang="scss">
.look-card__link {
  color: inherit;
  text-decoration: none;

  &:hover .look-card__name {
    text-decoration: underline;
  }
}
</style>
