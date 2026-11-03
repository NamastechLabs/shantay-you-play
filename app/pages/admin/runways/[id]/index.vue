<script setup lang="ts">
import type { RunwayStatus } from '~/utils/runwayStatus'

/** Postgres unique_violation, raised by runways_week_number_key */
const UNIQUE_VIOLATION = '23505'

const supabase = useSupabaseClient()
const { runway, categories, refresh } = useAdminRunway()

// Looks done / expected, to warn before voting opens
const { data: lookCounts, refresh: refreshLookCounts } = await useAsyncData(`admin-runway-${runway.value.id}-counts`, async () => {
  const categoryIds = categories.value.map(category => category.id)
  const [contestants, looks] = await Promise.all([
    supabase.from('participants').select('id', { count: 'exact', head: true }).eq('role', 'concursante'),
    supabase.from('looks').select('id', { count: 'exact', head: true }).in('category_id', categoryIds),
  ])
  if (contestants.error) throw contestants.error
  if (looks.error) throw looks.error
  return { expected: (contestants.count ?? 0) * categoryIds.length, done: looks.count ?? 0 }
})
const missingQueenLooks = computed(() => (lookCounts.value ? lookCounts.value.expected - lookCounts.value.done : 0))

const previousStatus = computed(() => adjacentStatus(runway.value.status, -1))
const nextStatus = computed(() => adjacentStatus(runway.value.status, 1))
const currentStatusIndex = computed(() => RUNWAY_STATUSES.indexOf(runway.value.status))

// --- Edit week number / date ------------------------------------------------
const weekNumber = ref(runway.value.week_number)
const runwayDate = ref(toDatetimeLocal(runway.value.runway_date))
const runwayDetailsSaving = ref(false)
const runwayDetailsError = ref<string | null>(null)

const runwayDetailsChanged = computed(
  () => weekNumber.value !== runway.value.week_number || runwayDate.value !== toDatetimeLocal(runway.value.runway_date),
)

async function saveRunwayDetails(): Promise<void> {
  if (!runwayDetailsChanged.value || !(weekNumber.value > 0) || !runwayDate.value || runwayDetailsSaving.value) return

  runwayDetailsSaving.value = true
  runwayDetailsError.value = null
  try {
    const { error } = await supabase
      .from('runways')
      .update({ week_number: weekNumber.value, runway_date: fromDatetimeLocal(runwayDate.value) })
      .eq('id', runway.value.id)
    if (error) {
      if (error.code === UNIQUE_VIOLATION) throw new Error(`La semana ${weekNumber.value} ya existe`)
      throw error
    }
    await refresh()
  }
  catch (error) {
    runwayDetailsError.value = toErrorMessage(error)
  }
  finally {
    runwayDetailsSaving.value = false
  }
}

// --- Status changes -------------------------------------------------------
const statusSaving = ref(false)
const statusError = ref<string | null>(null)

async function changeStatus(status: RunwayStatus): Promise<void> {
  if (statusSaving.value) return

  await refreshLookCounts()
  const confirmation = status === 'voting' && missingQueenLooks.value > 0
    ? `Faltan ${missingQueenLooks.value} looks de reinas. Al abrir la votación ya no se podrán subir. ¿Continuar?`
    : status === 'reveal'
      ? 'Al pasar a Revelación, la votación se cierra y la portada muestra el Top 3. ¿Continuar?'
      : status === 'closed'
        ? 'Al cerrar la semana se revelan todos los votos. ¿Continuar?'
        : null
  if (confirmation && !window.confirm(confirmation)) return

  statusSaving.value = true
  statusError.value = null
  try {
    const { error } = await supabase.from('runways').update({ status }).eq('id', runway.value.id)
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
  <section class="section" aria-labelledby="status-title">
    <h2 id="status-title" class="sr-only">
      Estado: {{ RUNWAY_STATUS_LABELS[runway.status] }}
    </h2>
    <!-- Only the steps next to the current one are clickable (mirrors the workflow) -->
    <ol class="stepper">
      <li v-for="(status, index) in RUNWAY_STATUSES" :key="status">
        <button
          v-if="status === previousStatus || status === nextStatus"
          type="button"
          class="stepper__step"
          :class="status === nextStatus ? 'stepper__step--next' : 'stepper__step--previous'"
          :disabled="statusSaving"
          :title="status === nextStatus ? `Pasar a ${RUNWAY_STATUS_LABELS[status]}` : `Volver a ${RUNWAY_STATUS_LABELS[status]}`"
          @click="changeStatus(status)"
        >
          <span class="stepper__index" aria-hidden="true">{{ index + 1 }}</span>
          <span class="sr-only">{{ status === nextStatus ? 'Pasar a' : 'Volver a' }}</span>
          {{ RUNWAY_STATUS_LABELS[status] }}
        </button>
        <span
          v-else
          class="stepper__step"
          :class="status === runway.status ? 'stepper__step--current' : index < currentStatusIndex ? 'stepper__step--done' : null"
          :aria-current="status === runway.status ? 'step' : undefined"
        >
          <span class="stepper__index" aria-hidden="true">{{ index < currentStatusIndex ? '✓' : index + 1 }}</span>
          {{ RUNWAY_STATUS_LABELS[status] }}
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
    <form class="card form" @submit.prevent="saveRunwayDetails">
      <div class="field">
        <label for="detail-week" class="field__label">Semana</label>
        <input id="detail-week" v-model.number="weekNumber" class="field__input" type="number" min="1" required>
      </div>
      <div class="field">
        <label for="detail-date" class="field__label">Fecha y hora de la pasarela</label>
        <input id="detail-date" v-model="runwayDate" class="field__input" type="datetime-local" required>
      </div>
      <p v-if="runwayDetailsError" class="form-error" role="alert">
        {{ runwayDetailsError }}
      </p>
      <div>
        <button type="submit" class="btn btn--primary" :disabled="!runwayDetailsChanged || runwayDetailsSaving">
          {{ runwayDetailsSaving ? 'Guardando…' : 'Guardar' }}
        </button>
      </div>
    </form>
  </section>

  <section class="section" aria-labelledby="progress-title">
    <h2 id="progress-title">
      Preparación
    </h2>
    <ul class="row-list">
      <li>
        <NuxtLink :to="`/admin/runways/${runway.id}/categories`" class="row row--link">
          <span class="row__main">
            <span class="row__title">Categorías</span>
            <span class="muted">{{ categories.length ? categories.map(category => category.title).join(' · ') : 'Aún no hay categorías' }}</span>
          </span>
        </NuxtLink>
      </li>
      <li>
        <NuxtLink :to="`/admin/runways/${runway.id}/looks`" class="row row--link">
          <span class="row__main">
            <span class="row__title">Looks</span>
            <span class="muted">
              {{ lookCounts ? `${lookCounts.done} de ${lookCounts.expected} looks de reinas` : '' }}
            </span>
          </span>
        </NuxtLink>
      </li>
    </ul>
  </section>
</template>
