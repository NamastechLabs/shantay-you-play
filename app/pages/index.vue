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
  <main class="home">
    <header>
      <div>
        <h1>Drag Race</h1>
        <p v-if="participant">
          Hola, {{ participant.drag_name ?? participant.name }}
          <span class="role">{{ isJurado ? 'Jurado' : 'Concursante' }}</span>
        </p>
      </div>
      <div class="actions">
        <NuxtLink v-if="isJurado" to="/admin">
          Panel del jurado
        </NuxtLink>
        <button type="button" @click="signOut">
          Salir
        </button>
      </div>
    </header>

    <p v-if="error" class="error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <ul v-else-if="categories?.length" class="categories">
      <li v-for="category in categories" :key="category.id">
        <NuxtLink :to="`/categories/${category.id}`">
          Semana {{ category.week_number }} · {{ category.title }}
        </NuxtLink>
        <span class="status">{{ CATEGORY_STATUS_LABELS[category.status] }}</span>
      </li>
    </ul>

    <p v-else>
      Aún no hay categorías.
    </p>
  </main>
</template>

<style scoped>
.home {
  max-width: 40rem;
  margin: 0 auto;
  padding: 1rem;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
}

.actions {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.role,
.status {
  margin-left: 0.5rem;
  padding: 0.1rem 0.5rem;
  font-size: 0.8rem;
  border: 1px solid currentColor;
  border-radius: 999px;
}

.categories {
  display: grid;
  gap: 0.5rem;
  padding: 0;
  list-style: none;
}

.categories li {
  display: flex;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  border: 1px solid color-mix(in srgb, currentColor 20%, transparent);
  border-radius: 0.5rem;
}

.error {
  color: #d33;
}
</style>
