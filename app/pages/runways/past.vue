<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type RunwaySummary = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date'> & {
  categories: Pick<Tables<'categories'>, 'id' | 'title'>[]
}

const supabase = useSupabaseClient()

const { loadWinners } = useRunwayResults()

const { data, error } = await useAsyncData('past-runways', async () => {
  const { data: runways, error } = await supabase
    .from('runways')
    .select('id, week_number, runway_date, categories(id, title)')
    .eq('status', 'closed')
    .order('week_number', { ascending: false })
    .order('created_at', { referencedTable: 'categories', ascending: true })

  if (error) throw error
  return { runways: runways as RunwaySummary[], winners: await loadWinners(runways.map(runway => runway.id)) }
})
const runways = computed(() => data.value?.runways ?? [])
</script>

<template>
  <main class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Semanas pasadas' }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          {{ APP_NAME }}
        </p>
        <h1>Semanas pasadas</h1>
      </div>
    </header>

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <ul v-else-if="runways.length" class="past-list">
      <li v-for="runway in runways" :key="runway.id">
        <PastRunwayCard :runway="runway" :winner="data?.winners[runway.id]" />
      </li>
    </ul>

    <p v-else class="empty">
      Todavía no hay semanas cerradas.
    </p>
  </main>
</template>

<style scoped lang="scss">
.past-list {
  display: grid;
  gap: var(--space-4);
  padding: 0;
  margin: 0;
  list-style: none;
}
</style>
