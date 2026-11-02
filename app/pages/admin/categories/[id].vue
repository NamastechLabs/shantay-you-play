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
const currentStatusIndex = computed(() => (category.value ? CATEGORY_STATUSES.indexOf(category.value.status) : -1))

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
  <main v-if="category" class="page">
    <AppNav />
    <NuxtLink to="/admin" class="back-link">
      ← Panel
    </NuxtLink>

    <header class="page-header">
      <h1>Semana {{ category.week_number }}</h1>
    </header>

    <section class="section" aria-labelledby="status-title">
      <h2 id="status-title" class="sr-only">
        Estado: {{ CATEGORY_STATUS_LABELS[category.status] }}
      </h2>
      <!-- Only the steps next to the current one are clickable (mirrors the workflow) -->
      <ol class="stepper">
        <li v-for="(status, index) in CATEGORY_STATUSES" :key="status">
          <button
            v-if="status === previousStatus || status === nextStatus"
            type="button"
            class="stepper__step"
            :class="status === nextStatus ? 'stepper__step--next' : 'stepper__step--previous'"
            :disabled="statusSaving"
            :title="status === nextStatus ? `Pasar a ${CATEGORY_STATUS_LABELS[status]}` : `Volver a ${CATEGORY_STATUS_LABELS[status]}`"
            @click="changeStatus(status)"
          >
            <span class="stepper__index" aria-hidden="true">{{ index + 1 }}</span>
            <span class="sr-only">{{ status === nextStatus ? 'Pasar a' : 'Volver a' }}</span>
            {{ CATEGORY_STATUS_LABELS[status] }}
          </button>
          <span
            v-else
            class="stepper__step"
            :class="status === category.status ? 'stepper__step--current' : index < currentStatusIndex ? 'stepper__step--done' : null"
            :aria-current="status === category.status ? 'step' : undefined"
          >
            <span class="stepper__index" aria-hidden="true">{{ index < currentStatusIndex ? '✓' : index + 1 }}</span>
            {{ CATEGORY_STATUS_LABELS[status] }}
          </span>
        </li>
      </ol>
      <p v-if="statusError" class="form-error" role="alert">
        {{ statusError }}
      </p>
    </section>

    <section class="section" aria-labelledby="details-title">
      <h2 id="details-title">
        Detalles
      </h2>
      <form class="card form" @submit.prevent="saveDetails">
        <div class="field">
          <label for="detail-title" class="field__label">Título</label>
          <input id="detail-title" v-model="title" class="field__input" type="text" maxlength="100" required>
        </div>
        <div class="field">
          <label for="detail-intro" class="field__label">Introducción</label>
          <textarea id="detail-intro" v-model="introText" class="field__input" rows="3" />
        </div>
        <p v-if="detailsError" class="form-error" role="alert">
          {{ detailsError }}
        </p>
        <div>
          <button type="submit" class="btn btn--primary" :disabled="!detailsChanged || detailsSaving">
            {{ detailsSaving ? 'Guardando…' : 'Guardar' }}
          </button>
        </div>
      </form>
    </section>

    <section class="section" aria-labelledby="looks-title">
      <h2 id="looks-title">
        Looks ({{ data?.looks.length ?? 0 }} / {{ data?.contestants.length ?? 0 }})
      </h2>
      <p v-if="!canEditLooks(category.status)" class="hint">
        La votación ya abrió: los looks no se pueden modificar.
      </p>
      <ul v-if="data?.contestants.length" class="row-list">
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
      <p v-else class="empty">
        Aún no hay concursantes. Regístralos en <NuxtLink to="/admin/participants" class="link">Participantes</NuxtLink>.
      </p>
    </section>
  </main>

  <main v-else class="page">
    <AppNav />
    <NuxtLink to="/admin" class="back-link">
      ← Panel
    </NuxtLink>
    <p class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
  </main>
</template>
