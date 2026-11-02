<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { RunwayStatus } from '~/utils/runwayStatus'

interface MyLook {
  id: string
  image_url: string
  intro: string | null
  category: Pick<Tables<'categories'>, 'id' | 'title'> & {
    runway: Pick<Tables<'runways'>, 'id' | 'week_number' | 'status'>
  }
  /** Final place of the queen in the runway; null while it is not public or she got no votes */
  place: number | null
  totalPoints: number | null
}

const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()

// Only the signed-in participant's own looks; draft runways stay hidden by RLS
const { data, error } = await useAsyncData('my-looks', async (): Promise<MyLook[]> => {
  const participantId = participant.value?.id
  if (!participantId) return []

  const { data: rows, error: looksError } = await supabase
    .from('looks')
    .select('id, image_url, intro, category:categories!looks_category_id_fkey(id, title, runway:runways!categories_runway_id_fkey(id, week_number, status))')
    .eq('participant_id', participantId)

  if (looksError) throw looksError

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

  return rows
    .map(row => ({
      ...row,
      place: resultByRunway.get(row.category.runway.id)?.place ?? null,
      totalPoints: resultByRunway.get(row.category.runway.id)?.total_points ?? null,
    }))
    .sort((a, b) => b.category.runway.week_number - a.category.runway.week_number)
})

const looks = computed(() => data.value ?? [])

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
  <main class="page page--wide">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Mis looks' }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Drag Race Game
        </p>
        <h1>Mis looks</h1>
      </div>
    </header>

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <ul v-else-if="looks.length" class="gallery">
      <li v-for="look in looks" :key="look.id">
        <NuxtLink :to="`/runways/${look.category.runway.id}`" class="look-card">
          <span v-if="look.place" class="look-card__rank">{{ look.place }}</span>
          <span v-if="look.place === 1" class="look-card__crown" role="img" aria-label="Ganadora">♛</span>
          <img
            class="look-card__photo"
            :src="look.image_url"
            :alt="`Mi look de la semana ${look.category.runway.week_number}`"
            loading="lazy"
          >
          <span class="look-card__body">
            <span class="look-card__name">{{ look.category.title }}</span>
            <span class="look-card__intro">
              Semana {{ look.category.runway.week_number }} ·
              <template v-if="look.place">
                Puesto {{ look.place }}<template v-if="look.totalPoints !== null"> · {{ look.totalPoints }} pts</template>
              </template>
              <template v-else>{{ pendingLabel(look) }}</template>
            </span>
          </span>
        </NuxtLink>
      </li>
    </ul>

    <p v-else class="empty">
      Todavía no has desfilado en ninguna pasarela.
    </p>
  </main>
</template>
