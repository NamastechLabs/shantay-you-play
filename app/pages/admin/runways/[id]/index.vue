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

// Groups of the group categories with no photo yet: they block the move from Werk Room to Pasarela
const { data: groupsWithoutPhotos, refresh: refreshGroupsWithoutPhotos } = await useAsyncData(`admin-runway-${runway.value.id}-group-photos`, async () => {
  const groupCategoryIds = categories.value.filter(category => category.kind === 'group').map(category => category.id)
  if (!groupCategoryIds.length) return []
  const [groups, photos] = await Promise.all([
    supabase.from('category_groups').select('id, name').in('category_id', groupCategoryIds).order('position'),
    supabase.from('category_group_photos').select('group_id, image_url, image2_url, image3_url, image4_url').in('category_id', groupCategoryIds),
  ])
  if (groups.error) throw groups.error
  if (photos.error) throw photos.error
  const withPhotos = new Set(photos.data.filter(row => groupPhotoUrls(row).length).map(row => row.group_id))
  return groups.data.filter(group => !withPhotos.has(group.id)).map(group => group.name)
})
// The cached result can be stale after uploading photos in the "Grupos" tab and coming back
onMounted(() => refreshGroupsWithoutPhotos())
const blockedByGroupPhotos =computed(() => runway.value.status === 'werk_room' && (groupsWithoutPhotos.value?.length ?? 0) > 0)
const groupPhotosMessage = computed(() => {
  const names = groupsWithoutPhotos.value ?? []
  return `Para pasar a Pasarela, ${names.length === 1 ? 'el grupo' : 'los grupos'} ${names.join(' y ')} ${names.length === 1 ? 'necesita' : 'necesitan'} al menos una foto. Súbela${names.length === 1 ? '' : 's'} en la pestaña «Grupos» de Looks.`
})

// --- Download for the commentary ----------------------------------------------
const { exporting, download: downloadRunway } = useRunwayExport()
const snackbar = useSnackbar()

async function exportRunway(): Promise<void> {
  if (exporting.value) return
  try {
    await downloadRunway(runway.value.id)
    snackbar.success('Pasarela exportada.')
  }
  catch (error) {
    snackbar.error(toErrorMessage(error))
  }
}

const previousStatus = computed(() => adjacentStatus(runway.value.status, -1))
const nextStatus = computed(() => adjacentStatus(runway.value.status, 1))
const currentStatusIndex = computed(() => RUNWAY_STATUSES.indexOf(runway.value.status))

// --- Edit week number / date ------------------------------------------------
const weekNumber = ref(runway.value.week_number)
const runwayDate = ref(toDatetimeLocal(runway.value.runway_date))
const runwayDetailsSaving = ref(false)

const runwayDetailsChanged = computed(
  () => weekNumber.value !== runway.value.week_number || runwayDate.value !== toDatetimeLocal(runway.value.runway_date),
)

async function saveRunwayDetails(): Promise<void> {
  if (!runwayDetailsChanged.value || !(weekNumber.value > 0) || !runwayDate.value || runwayDetailsSaving.value) return

  runwayDetailsSaving.value = true
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
    snackbar.success('Semana actualizada.')
  }
  catch (error) {
    snackbar.error(toErrorMessage(error))
  }
  finally {
    runwayDetailsSaving.value = false
  }
}

// --- Status changes -------------------------------------------------------
const statusSaving = ref(false)

async function changeStatus(status: RunwayStatus): Promise<void> {
  if (statusSaving.value) return

  await Promise.all([refreshLookCounts(), refreshGroupsWithoutPhotos()])
  if (status === 'runway' && blockedByGroupPhotos.value) {
    snackbar.error(groupPhotosMessage.value)
    return
  }
  const confirmation = status === 'voting' && missingQueenLooks.value > 0
    ? `Faltan ${missingQueenLooks.value} looks de reinas. Al abrir la votación ya no se podrán subir. ¿Continuar?`
    : status === 'reveal'
      ? 'Al pasar a Revelación, la votación se cierra y la portada muestra el Top 3. ¿Continuar?'
      : status === 'closed'
        ? 'Al cerrar la semana se revelan todos los votos. ¿Continuar?'
        : null
  if (confirmation && !window.confirm(confirmation)) return

  statusSaving.value = true
  try {
    const { error } = await supabase.from('runways').update({ status }).eq('id', runway.value.id)
    if (error) throw error
    await refresh()
    snackbar.success(`Estado cambiado a «${RUNWAY_STATUS_LABELS[status]}».`)
  }
  catch (error) {
    snackbar.error(toErrorMessage(error))
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
          :disabled="statusSaving || (status === 'runway' && blockedByGroupPhotos)"
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
    <p v-if="blockedByGroupPhotos" class="muted" role="status">
      {{ groupPhotosMessage }}
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

  <section class="section" aria-labelledby="export-title">
    <h2 id="export-title">
      Comentarios con IA
    </h2>
    <div class="card form">
      <p class="muted">
        Descarga un ZIP con los datos de la semana (categorías, intros y looks de las reinas y del jurado) en <code>runway.json</code> y todas las fotos, listo para subirlo a la IA que escribe los comentarios.
      </p>
      <button type="button" class="btn btn--secondary" :disabled="exporting" @click="exportRunway">
        {{ exporting ? 'Preparando ZIP…' : 'Descargar ZIP de la semana' }}
      </button>
    </div>
  </section>
</template>
