<script setup lang="ts">
import type { Tables } from '~/types/database.types'

definePageMeta({ middleware: 'jurado' })

type RunwaySummary = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'> & {
  categories: Pick<Tables<'categories'>, 'id' | 'title'>[]
}

/** Postgres unique_violation, raised by runways_week_number_key */
const UNIQUE_VIOLATION = '23505'

const supabase = useSupabaseClient()

const TABS = [
  { id: 'weeks', label: 'Semanas' },
  { id: 'intro', label: 'Vídeo de intro' },
] as const
const tab = ref<(typeof TABS)[number]['id']>('weeks')

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
const snackbar = useSnackbar()
const modalOpen = ref(false)

const canCreate = computed(() => weekNumber.value > 0 && runwayDate.value !== '')

function openModal(): void {
  weekNumber.value = nextWeek.value
  runwayDate.value = now()
  modalOpen.value = true
}

function openRunway(id: string): void {
  void navigateTo(`/admin/runways/${id}`)
}

async function createRunway(): Promise<void> {
  if (!canCreate.value || saving.value) return

  saving.value = true
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
    snackbar.error(toErrorMessage(error))
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <main class="page page--admin">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Panel del jurado' }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <h1>Panel del jurado</h1>
        <p class="hint">
          Gestiona las semanas y el vídeo de introducción de tu pasarela.
        </p>
      </div>
    </header>

    <div class="tabs" role="tablist" aria-label="Secciones del panel">
      <button
        v-for="item in TABS"
        :id="`admin-tab-${item.id}`"
        :key="item.id"
        type="button"
        role="tab"
        class="tabs__tab"
        :class="{ 'tabs__tab--active': tab === item.id }"
        :aria-selected="tab === item.id"
        :aria-controls="`admin-panel-${item.id}`"
        :tabindex="tab === item.id ? 0 : -1"
        @click="tab = item.id"
      >
        {{ item.label }}
        <span v-if="item.id === 'weeks' && runways" class="tabs__count">{{ runways.length }}</span>
      </button>
    </div>

    <section
      v-show="tab === 'weeks'"
      id="admin-panel-weeks"
      class="section"
      role="tabpanel"
      aria-labelledby="admin-tab-weeks"
    >
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
      <div v-else-if="runways?.length" class="table-card">
        <table class="table table--stack">
          <thead>
            <tr>
              <th scope="col">
                Semana
              </th>
              <th scope="col">
                Temática
              </th>
              <th scope="col">
                Fecha
              </th>
              <th scope="col">
                Estado
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="runway in runways"
              :key="runway.id"
              class="table__row--link"
              @click="openRunway(runway.id)"
            >
              <td>
                <NuxtLink :to="`/admin/runways/${runway.id}`" class="table__link">
                  Semana {{ runway.week_number }}
                </NuxtLink>
              </td>
              <td>{{ runway.categories.length ? runwayTitle(runway.categories) : 'Sin categorías' }}</td>
              <td>
                <span class="table__stack">
                  <span>{{ formatRunwayDay(runway.runway_date) }}</span>
                  <span class="muted">{{ formatRunwayTime(runway.runway_date) }}</span>
                </span>
              </td>
              <td>
                <StatusBadge :status="runway.status" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else class="empty">
        Aún no hay pasarelas.
      </p>
    </section>

    <div
      v-if="tab === 'intro'"
      id="admin-panel-intro"
      role="tabpanel"
      aria-labelledby="admin-tab-intro"
    >
      <AdminIntroVideo />
    </div>

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
