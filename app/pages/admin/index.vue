<script setup lang="ts">
import type { Tables } from '~/types/database.types'

definePageMeta({ middleware: 'jurado' })

type RunwaySummary = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'> & {
  categories: Pick<Tables<'categories'>, 'id' | 'title'>[]
}

/** Postgres unique_violation, raised by runways_week_number_key */
const UNIQUE_VIOLATION = '23505'

const supabase = useSupabaseClient()

const { data: runways, error: loadError, refresh } = await useAsyncData(
  'admin-runways',
  async (): Promise<RunwaySummary[]> => {
    const { data, error } = await supabase
      .from('runways')
      .select('id, week_number, runway_date, status, categories(id, title)')
      .order('week_number', { ascending: false })
      .order('created_at', { referencedTable: 'categories', ascending: true })

    if (error) throw error
    return data
  },
)

const nextWeek = computed(() => (runways.value?.[0]?.week_number ?? 0) + 1)
const now = (): string => toDatetimeLocal(new Date().toISOString())

const weekNumber = ref<number>(nextWeek.value)
const runwayDate = ref(now())
const saving = ref(false)
const errorMessage = ref<string | null>(null)
const modalOpen = ref(false)

const canCreate = computed(() => weekNumber.value > 0 && runwayDate.value !== '')

function openModal(): void {
  weekNumber.value = nextWeek.value
  runwayDate.value = now()
  errorMessage.value = null
  modalOpen.value = true
}

async function createRunway(): Promise<void> {
  if (!canCreate.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    const { data, error } = await supabase
      .from('runways')
      .insert({ week_number: weekNumber.value, runway_date: fromDatetimeLocal(runwayDate.value) })
      .select('id')
      .single()

    if (error) {
      if (error.code === UNIQUE_VIOLATION) throw new Error(`La semana ${weekNumber.value} ya existe`)
      throw error
    }
    await navigateTo(`/admin/runways/${data.id}`)
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

    <section class="section" aria-labelledby="runways-title">
      <div class="section-header">
        <h2 id="runways-title">
          Semanas
        </h2>
        <button type="button" class="btn btn--primary" @click="openModal">
          + Nueva pasarela
        </button>
      </div>

      <p v-if="loadError" class="form-error" role="alert">
        {{ toErrorMessage(loadError) }}
        <button type="button" class="btn btn--ghost" @click="refresh()">
          Reintentar
        </button>
      </p>
      <ul v-else-if="runways?.length" class="row-list">
        <li v-for="runway in runways" :key="runway.id">
          <NuxtLink :to="`/admin/runways/${runway.id}`" class="row row--link">
            <span class="row__main">
              <span class="row__title">Semana {{ runway.week_number }} · {{ runway.categories.length ? runwayTitle(runway.categories) : 'Sin categorías' }}</span>
              <span class="muted">{{ formatRunwayDate(runway.runway_date) }}</span>
            </span>
            <StatusBadge :status="runway.status" />
          </NuxtLink>
        </li>
      </ul>
      <p v-else class="empty">
        Aún no hay pasarelas.
      </p>
    </section>

    <AppModal :open="modalOpen" title="Nueva pasarela" @close="modalOpen = false">
      <form class="form" @submit.prevent="createRunway">
        <div class="field">
          <label for="runway-week" class="field__label">Semana</label>
          <input id="runway-week" v-model.number="weekNumber" class="field__input" type="number" min="1" required>
        </div>
        <div class="field">
          <label for="runway-date" class="field__label">Fecha y hora de la pasarela</label>
          <input id="runway-date" v-model="runwayDate" class="field__input" type="datetime-local" required>
        </div>
        <p class="hint">
          Después podrás añadir una o varias categorías a la semana.
        </p>
        <p v-if="errorMessage" class="form-error" role="alert">
          {{ errorMessage }}
        </p>
        <div class="form-actions">
          <button type="button" class="btn btn--ghost" @click="modalOpen = false">
            Cancelar
          </button>
          <button type="submit" class="btn btn--primary" :disabled="!canCreate || saving">
            {{ saving ? 'Creando…' : 'Crear pasarela' }}
          </button>
        </div>
      </form>
    </AppModal>
  </main>
</template>
