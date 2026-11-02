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
const modalOpen = ref(false)

const canCreate = computed(() => title.value.trim().length > 0 && weekNumber.value > 0)

function openModal(): void {
  weekNumber.value = nextWeek.value
  title.value = ''
  introText.value = ''
  errorMessage.value = null
  modalOpen.value = true
}

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
  <main class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Panel del jurado' }]" />

    <header class="page-header">
      <h1>Panel del jurado</h1>
    </header>

    <section class="section" aria-labelledby="categories-title">
      <div class="section-header">
        <h2 id="categories-title">
          Categorías
        </h2>
        <button type="button" class="btn btn--primary" @click="openModal">
          + Nueva categoría
        </button>
      </div>

      <p v-if="loadError" class="form-error" role="alert">
        {{ toErrorMessage(loadError) }}
        <button type="button" class="btn btn--ghost" @click="refresh()">
          Reintentar
        </button>
      </p>
      <ul v-else-if="categories?.length" class="row-list">
        <li v-for="category in categories" :key="category.id">
          <NuxtLink :to="`/admin/categories/${category.id}`" class="row row--link">
            <span>Semana {{ category.week_number }} · {{ category.title }}</span>
            <StatusBadge :status="category.status" />
          </NuxtLink>
        </li>
      </ul>
      <p v-else class="empty">
        Aún no hay categorías.
      </p>
    </section>

    <AppModal :open="modalOpen" title="Nueva categoría" @close="modalOpen = false">
      <form class="form" @submit.prevent="createCategory">
        <div class="field">
          <label for="category-week" class="field__label">Semana</label>
          <input id="category-week" v-model.number="weekNumber" class="field__input" type="number" min="1" required>
        </div>
        <div class="field">
          <label for="category-title" class="field__label">Título</label>
          <input
            id="category-title"
            v-model="title"
            class="field__input"
            type="text"
            maxlength="100"
            required
            placeholder="Ej. Alta costura espacial"
          >
        </div>
        <div class="field">
          <label for="category-intro" class="field__label">Introducción</label>
          <textarea
            id="category-intro"
            v-model="introText"
            class="field__input"
            rows="3"
            placeholder="Describe el tema de la semana (opcional)"
          />
        </div>
        <p v-if="errorMessage" class="form-error" role="alert">
          {{ errorMessage }}
        </p>
        <div class="form-actions">
          <button type="button" class="btn btn--ghost" @click="modalOpen = false">
            Cancelar
          </button>
          <button type="submit" class="btn btn--primary" :disabled="!canCreate || saving">
            {{ saving ? 'Creando…' : 'Crear categoría' }}
          </button>
        </div>
      </form>
    </AppModal>
  </main>
</template>
