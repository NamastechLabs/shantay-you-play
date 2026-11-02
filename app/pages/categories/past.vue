<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type CategorySummary = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'status'>

const supabase = useSupabaseClient()

const { loadWinners } = useCategoryWinners()

const { data, error } = await useAsyncData('past-categories', async () => {
  const { data: categories, error } = await supabase
    .from('categories')
    .select('id, week_number, title, status')
    .eq('status', 'closed')
    .order('week_number', { ascending: false })

  if (error) throw error
  return { categories: categories as CategorySummary[], winners: await loadWinners(categories.map(category => category.id)) }
})
const categories = computed(() => data.value?.categories ?? [])
</script>

<template>
  <main class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Categorías pasadas' }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Drag Race Game
        </p>
        <h1>Categorías pasadas</h1>
      </div>
    </header>

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <ul v-else-if="categories.length" class="past-list">
      <li v-for="category in categories" :key="category.id">
        <PastCategoryCard :category="category" :winner="data?.winners[category.id]" />
      </li>
    </ul>

    <p v-else class="empty">
      Todavía no hay categorías cerradas.
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
