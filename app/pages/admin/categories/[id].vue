<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { CategoryStatus } from '~/utils/categoryStatus'

definePageMeta({ middleware: 'jurado' })

type Category = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'intro_text' | 'status'>
type Contestant = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
type LookSummary = Pick<Tables<'looks'>, 'id' | 'category_id' | 'participant_id' | 'image_url' | 'intro'>

interface CategoryDetail {
  category: Category
  contestants: Contestant[]
  looks: LookSummary[]
}

const route = useRoute()
const supabase = useSupabaseClient()
const categoryId = String(route.params.id)

const { data, error: loadError, refresh } = await useAsyncData(
  `admin-category-${categoryId}`,
  async (): Promise<CategoryDetail | null> => {
    const [category, contestants, looks] = await Promise.all([
      supabase
        .from('categories')
        .select('id, week_number, title, intro_text, status')
        .eq('id', categoryId)
        .maybeSingle(),
      supabase
        .from('participants')
        .select('id, name, drag_name')
        .eq('role', 'concursante')
        .order('name', { ascending: true }),
      supabase
        .from('looks')
        .select('id, category_id, participant_id, image_url, intro')
        .eq('category_id', categoryId),
    ])

    if (category.error) throw category.error
    if (contestants.error) throw contestants.error
    if (looks.error) throw looks.error
    if (!category.data) return null

    return { category: category.data, contestants: contestants.data, looks: looks.data }
  },
)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Categoría no encontrada', fatal: true })
}

const category = computed(() => data.value?.category ?? null)
const looksByParticipant = computed(() => new Map(data.value?.looks.map(look => [look.participant_id, look])))
const previousStatus = computed(() => (category.value ? adjacentStatus(category.value.status, -1) : null))
const nextStatus = computed(() => (category.value ? adjacentStatus(category.value.status, 1) : null))

// --- Edit title / intro ---------------------------------------------------
const title = ref(category.value?.title ?? '')
const introText = ref(category.value?.intro_text ?? '')
const detailsSaving = ref(false)
const detailsError = ref<string | null>(null)

const detailsChanged = computed(
  () => title.value.trim() !== category.value?.title
    || (introText.value.trim() || null) !== category.value?.intro_text,
)

async function saveDetails(): Promise<void> {
  if (!detailsChanged.value || !title.value.trim() || detailsSaving.value) return

  detailsSaving.value = true
  detailsError.value = null
  try {
    const { error } = await supabase
      .from('categories')
      .update({ title: title.value.trim(), intro_text: introText.value.trim() || null })
      .eq('id', categoryId)
    if (error) throw error
    await refresh()
  }
  catch (error) {
    detailsError.value = toErrorMessage(error)
  }
  finally {
    detailsSaving.value = false
  }
}

// --- Status changes -------------------------------------------------------
const statusSaving = ref(false)
const statusError = ref<string | null>(null)

async function changeStatus(status: CategoryStatus): Promise<void> {
  if (statusSaving.value) return

  const closing = status === 'closed'
  if (closing && !window.confirm('Al cerrar la categoría se revelan todos los votos. ¿Continuar?')) return

  statusSaving.value = true
  statusError.value = null
  try {
    const { error } = await supabase.from('categories').update({ status }).eq('id', categoryId)
    if (error) throw error
    await refresh()
  }
  catch (error) {
    statusError.value = toErrorMessage(error)
  }
  finally {
    statusSaving.value = false
  }
}
</script>

<template>
  <main v-if="category" class="category">
    <header>
      <h1>Semana {{ category.week_number }}</h1>
      <NuxtLink to="/admin">
        ← Panel
      </NuxtLink>
    </header>

    <section>
      <h2>Estado: {{ CATEGORY_STATUS_LABELS[category.status] }}</h2>
      <ol class="steps">
        <li
          v-for="status in CATEGORY_STATUSES"
          :key="status"
          :class="{ current: status === category.status }"
        >
          {{ CATEGORY_STATUS_LABELS[status] }}
        </li>
      </ol>
      <div class="actions">
        <button v-if="previousStatus" type="button" :disabled="statusSaving" @click="changeStatus(previousStatus)">
          ← Volver a {{ CATEGORY_STATUS_LABELS[previousStatus] }}
        </button>
        <button v-if="nextStatus" type="button" :disabled="statusSaving" @click="changeStatus(nextStatus)">
          Pasar a {{ CATEGORY_STATUS_LABELS[nextStatus] }} →
        </button>
      </div>
      <p v-if="statusError" class="error" role="alert">
        {{ statusError }}
      </p>
    </section>

    <section>
      <h2>Detalles</h2>
      <form @submit.prevent="saveDetails">
        <label>
          Título
          <input v-model="title" type="text" maxlength="100" required>
        </label>
        <label>
          Introducción
          <textarea v-model="introText" rows="3" />
        </label>
        <button type="submit" :disabled="!detailsChanged || detailsSaving">
          {{ detailsSaving ? 'Guardando…' : 'Guardar' }}
        </button>
        <p v-if="detailsError" class="error" role="alert">
          {{ detailsError }}
        </p>
      </form>
    </section>

    <section>
      <h2>Looks ({{ data?.looks.length ?? 0 }} / {{ data?.contestants.length ?? 0 }})</h2>
      <p v-if="!canEditLooks(category.status)" class="hint">
        La votación ya abrió: los looks no se pueden modificar.
      </p>
      <ul v-if="data?.contestants.length" class="looks">
        <AdminLookRow
          v-for="contestant in data.contestants"
          :key="contestant.id"
          :category-id="category.id"
          :contestant="contestant"
          :look="looksByParticipant.get(contestant.id) ?? null"
          :editable="canEditLooks(category.status)"
          @changed="refresh()"
        />
      </ul>
      <p v-else>
        Aún no hay concursantes. Aparecerán cuando inicien sesión y tengan el rol <code>concursante</code>.
      </p>
    </section>
  </main>

  <main v-else class="category">
    <p class="error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
  </main>
</template>

<style scoped>
.category {
  max-width: 40rem;
  margin: 0 auto;
  padding: 1rem;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: center;
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

.steps {
  display: flex;
  gap: 0.5rem;
  padding: 0;
  list-style: none;
}

.steps li {
  padding: 0.25rem 0.75rem;
  font-size: 0.85rem;
  border: 1px solid color-mix(in srgb, currentColor 30%, transparent);
  border-radius: 999px;
  opacity: 0.6;
}

.steps li.current {
  font-weight: 600;
  border-color: currentColor;
  opacity: 1;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.looks {
  display: grid;
  gap: 0.75rem;
  padding: 0;
}

.hint {
  opacity: 0.7;
}

.error {
  color: #d33;
}
</style>
