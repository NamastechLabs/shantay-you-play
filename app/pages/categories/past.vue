<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type CategorySummary = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'status'>

const supabase = useSupabaseClient()

const { data: categories, error } = await useAsyncData('past-categories', async (): Promise<CategorySummary[]> => {
  const { data, error } = await supabase
    .from('categories')
    .select('id, week_number, title, status')
    .eq('status', 'closed')
    .order('week_number', { ascending: false })

  if (error) throw error
  return data
})
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

    <ul v-else-if="categories?.length" class="row-list">
      <li v-for="category in categories" :key="category.id">
        <NuxtLink :to="`/categories/${category.id}`" class="row row--link">
          <span>Semana {{ category.week_number }} · {{ category.title }}</span>
          <StatusBadge :status="category.status" />
        </NuxtLink>
      </li>
    </ul>

    <p v-else class="empty">
      Todavía no hay categorías cerradas.
    </p>
  </main>
</template>
