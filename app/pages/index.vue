<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type CategorySummary = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'status'>

const supabase = useSupabaseClient()
const { participant, isJurado, clear } = useCurrentParticipant()

// RLS already hides drafts from contestants
const { data: categories, error } = await useAsyncData('categories', async (): Promise<CategorySummary[]> => {
  const { data, error } = await supabase
    .from('categories')
    .select('id, week_number, title, status')
    .order('week_number', { ascending: true })

  if (error) throw error
  return data
})

async function signOut(): Promise<void> {
  await supabase.auth.signOut()
  clear()
  await navigateTo('/login')
}
</script>

<template>
  <main class="page">
    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Drag Race Game
        </p>
        <h1>{{ participant ? `Hola, ${participant.drag_name ?? participant.name}` : 'Inicio' }}</h1>
      </div>
      <div class="page-header__actions">
        <ThemeSwitcher />
        <span v-if="participant" class="badge badge--draft">{{ isJurado ? 'Jurado' : 'Concursante' }}</span>
        <NuxtLink v-if="isJurado" to="/admin" class="btn btn--secondary">
          Panel del jurado
        </NuxtLink>
        <button type="button" class="btn btn--ghost" @click="signOut">
          Salir
        </button>
      </div>
    </header>

    <section class="section" aria-labelledby="categories-title">
      <h2 id="categories-title">
        Categorías semanales
      </h2>

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
        Aún no hay categorías.
      </p>
    </section>
  </main>
</template>
