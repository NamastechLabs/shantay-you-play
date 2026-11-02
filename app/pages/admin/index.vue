<script setup lang="ts">
import type { Tables } from '~/types/database.types'

definePageMeta({ middleware: 'jurado' })

type CategorySummary = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'status'>

/** Postgres unique_violation, raised by categories_week_number_key */
const UNIQUE_VIOLATION = '23505'

const supabase = useSupabaseClient()

const { data: categories, error: loadError, refresh } = await useAsyncData(
  'admin-categories',
  async (): Promise<CategorySummary[]> => {
    const { data, error } = await supabase
      .from('categories')
      .select('id, week_number, title, status')
      .order('week_number', { ascending: false })

    if (error) throw error
    return data
  },
)

const nextWeek = computed(() => (categories.value?.[0]?.week_number ?? 0) + 1)

const weekNumber = ref<number>(nextWeek.value)
const title = ref('')
const introText = ref('')
const saving = ref(false)
const errorMessage = ref<string | null>(null)

const canCreate = computed(() => title.value.trim().length > 0 && weekNumber.value > 0)

async function createCategory(): Promise<void> {
  if (!canCreate.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('categories')
      .insert({
        week_number: weekNumber.value,
        title: title.value.trim(),
        intro_text: introText.value.trim() || null,
      })
      .select('id')
      .single()

    if (error) {
      if (error.code === UNIQUE_VIOLATION) throw new Error(`La semana ${weekNumber.value} ya existe`)
      throw error
    }
    await navigateTo(`/admin/categories/${data.id}`)
  }
  catch (error) {
    errorMessage.value = toErrorMessage(error)
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <main class="admin">
    <header>
      <h1>Panel del jurado</h1>
      <nav class="links">
        <NuxtLink to="/admin/participants">
          Participantes
        </NuxtLink>
        <NuxtLink to="/">
          ← Inicio
        </NuxtLink>
      </nav>
    </header>

    <section>
      <h2>Nueva categoría</h2>
      <form @submit.prevent="createCategory">
        <label>
          Semana
          <input v-model.number="weekNumber" type="number" min="1" required>
        </label>
        <label>
          Título
          <input v-model="title" type="text" maxlength="100" required placeholder="Ej. Alta costura espacial">
        </label>
        <label>
          Introducción
          <textarea v-model="introText" rows="3" placeholder="Describe el tema de la semana (opcional)" />
        </label>
        <button type="submit" :disabled="!canCreate || saving">
          {{ saving ? 'Creando…' : 'Crear categoría' }}
        </button>
        <p v-if="errorMessage" class="error" role="alert">
          {{ errorMessage }}
        </p>
      </form>
    </section>

    <section>
      <h2>Categorías</h2>
      <p v-if="loadError" class="error" role="alert">
        {{ toErrorMessage(loadError) }}
        <button type="button" @click="refresh()">
          Reintentar
        </button>
      </p>
      <ul v-else-if="categories?.length" class="categories">
        <li v-for="category in categories" :key="category.id">
          <NuxtLink :to="`/admin/categories/${category.id}`">
            Semana {{ category.week_number }} · {{ category.title }}
          </NuxtLink>
          <span class="status">{{ CATEGORY_STATUS_LABELS[category.status] }}</span>
        </li>
      </ul>
      <p v-else>
        Aún no hay categorías.
      </p>
    </section>
  </main>
</template>

<style scoped>
.admin {
  max-width: 40rem;
  margin: 0 auto;
  padding: 1rem;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.links {
  display: flex;
  gap: 1rem;
}

form {
  display: grid;
  gap: 0.75rem;
}

label {
  display: grid;
  gap: 0.25rem;
}

input,
textarea {
  padding: 0.5rem;
  font: inherit;
  border-radius: 0.5rem;
  border: 1px solid color-mix(in srgb, currentColor 30%, transparent);
}

button {
  justify-self: start;
  padding: 0.5rem 1.25rem;
  border-radius: 999px;
  cursor: pointer;
}

button:disabled {
  cursor: not-allowed;
  opacity: 0.6;
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

.status {
  padding: 0.1rem 0.5rem;
  font-size: 0.8rem;
  border: 1px solid currentColor;
  border-radius: 999px;
}

.error {
  color: #d33;
}
</style>
