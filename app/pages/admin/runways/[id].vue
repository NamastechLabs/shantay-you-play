<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { RunwayStatus } from '~/utils/runwayStatus'
import type { LookKind } from '~/composables/useLookUpload'

definePageMeta({ middleware: 'jurado' })

type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'>
type Category = Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text'>
type Contestant = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
type LookSummary = Pick<Tables<'looks'>, 'id' | 'category_id' | 'participant_id' | 'image_url' | 'intro'>

interface RunwayDetail {
  runway: Runway
  categories: Category[]
  contestants: Contestant[]
  looks: LookSummary[]
  judges: Contestant[]
  juryLooks: LookSummary[]
}

/** Postgres unique_violation, raised by runways_week_number_key */
const UNIQUE_VIOLATION = '23505'

const route = useRoute()
const supabase = useSupabaseClient()
const runwayId = String(route.params.id)
const { listCategoryFiles, removeFiles } = useParticipantFiles()

const { data, error: loadError, refresh } = await useAsyncData(
  `admin-runway-${runwayId}`,
  async (): Promise<RunwayDetail | null> => {
    const runway = await supabase
      .from('runways')
      .select('id, week_number, runway_date, status')
      .eq('id', runwayId)
      .maybeSingle()
    if (runway.error) throw runway.error
    if (!runway.data) return null

    const categories = await supabase
      .from('categories')
      .select('id, title, intro_text')
      .eq('runway_id', runwayId)
      .order('created_at', { ascending: true })
    if (categories.error) throw categories.error
    const categoryIds = categories.data.map(category => category.id)

    const [contestants, looks, judges, juryLooks] = await Promise.all([
      supabase
        .from('participants')
        .select('id, name, drag_name')
        .eq('role', 'concursante')
        .order('name', { ascending: true }),
      supabase
        .from('looks')
        .select('id, category_id, participant_id, image_url, intro')
        .in('category_id', categoryIds),
      supabase
        .from('participants')
        .select('id, name, drag_name')
        .eq('role', 'jurado')
        .order('name', { ascending: true }),
      supabase
        .from('jury_looks')
        .select('id, category_id, participant_id, image_url, intro')
        .in('category_id', categoryIds),
    ])

    if (contestants.error) throw contestants.error
    if (looks.error) throw looks.error
    if (judges.error) throw judges.error
    if (juryLooks.error) throw juryLooks.error

    return {
      runway: runway.data,
      categories: categories.data,
      contestants: contestants.data,
      looks: looks.data,
      judges: judges.data,
      juryLooks: juryLooks.data,
    }
  },
)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Semana no encontrada', fatal: true })
}

const runway = computed(() => data.value?.runway ?? null)
const categories = computed(() => data.value?.categories ?? [])

const lookKey = (categoryId: string, participantId: string): string => `${categoryId}:${participantId}`
const looksByKey = computed(() => new Map(data.value?.looks.map(look => [lookKey(look.category_id, look.participant_id), look])))
const juryLooksByKey = computed(() => new Map(data.value?.juryLooks.map(look => [lookKey(look.category_id, look.participant_id), look])))

// --- Looks tabs: queens (voted) and jury (shown on the homepage) ----------
type LooksTab = 'queens' | 'jury'
const looksTab = ref<LooksTab>('queens')
const looksTabs = computed<{ id: LooksTab, label: string, done: number, total: number }[]>(() => [
  { id: 'queens', label: 'Reinas', done: data.value?.looks.length ?? 0, total: (data.value?.contestants.length ?? 0) * categories.value.length },
  { id: 'jury', label: 'Jurados', done: data.value?.juryLooks.length ?? 0, total: (data.value?.judges.length ?? 0) * categories.value.length },
])
const previousStatus = computed(() => (runway.value ? adjacentStatus(runway.value.status, -1) : null))
const nextStatus = computed(() => (runway.value ? adjacentStatus(runway.value.status, 1) : null))
const currentStatusIndex = computed(() => (runway.value ? RUNWAY_STATUSES.indexOf(runway.value.status) : -1))
const missingQueenLooks = computed(() => looksTabs.value[0]!.total - looksTabs.value[0]!.done)

// --- Paste an image from the clipboard to assign it to a queen / judge ----
const pastedFile = ref<File | null>(null)
const pastedPreview = ref<string | null>(null)
const pasteCategoryId = ref('')
const pasteTargetId = ref('')
const pasteSaving = ref(false)
const pasteError = ref<string | null>(null)

// Composables need the Nuxt context, so both are created here rather than on paste
const queenUploads = useLookUpload('queen')
const juryUploads = useLookUpload('jury')

const pasteKind = computed<LookKind>(() => (looksTab.value === 'jury' ? 'jury' : 'queen'))
const pasteCandidates = computed(() => (pasteKind.value === 'jury' ? data.value?.judges : data.value?.contestants) ?? [])
const pasteExistingLooks = computed(() => (pasteKind.value === 'jury' ? juryLooksByKey.value : looksByKey.value))
const pasteExisting = (personId: string) => pasteExistingLooks.value.get(lookKey(pasteCategoryId.value, personId))
const pasteTargetHasLook = computed(() => !!pasteExisting(pasteTargetId.value))
// Jury looks need an intro, so a judge without a look must be filled in by hand
const pasteTargetBlocked = computed(() => pasteKind.value === 'jury' && !!pasteTargetId.value && !pasteTargetHasLook.value)

function optionLabel(person: Contestant): string {
  const name = person.drag_name ?? person.name
  return pasteExisting(person.id) ? `${name} (reemplazar look)` : name
}

function closePaste(): void {
  if (pasteSaving.value) return
  pastedFile.value = null
}

watch(pastedFile, (next) => {
  if (pastedPreview.value) URL.revokeObjectURL(pastedPreview.value)
  pastedPreview.value = next ? URL.createObjectURL(next) : null
  pasteCategoryId.value = categories.value[0]?.id ?? ''
  pasteTargetId.value = ''
  pasteError.value = null
})

function onPaste(event: ClipboardEvent): void {
  if (!runway.value || !canEditLooks(runway.value.status) || !categories.value.length || pastedFile.value) return
  const image = Array.from(event.clipboardData?.files ?? []).find(file => file.type.startsWith('image/'))
  if (!image) return
  event.preventDefault()
  pastedFile.value = image
}

onMounted(() => document.addEventListener('paste', onPaste))
onBeforeUnmount(() => {
  document.removeEventListener('paste', onPaste)
  if (pastedPreview.value) URL.revokeObjectURL(pastedPreview.value)
})

async function savePasted(): Promise<void> {
  const file = pastedFile.value
  const target = pasteCandidates.value.find(person => person.id === pasteTargetId.value)
  if (!file || !target || !pasteCategoryId.value || pasteTargetBlocked.value || pasteSaving.value) return

  const { uploadLook, replaceLookImage } = pasteKind.value === 'jury' ? juryUploads : queenUploads
  const existing = pasteExisting(target.id)

  pasteSaving.value = true
  pasteError.value = null
  try {
    if (existing) await replaceLookImage(existing, file)
    else await uploadLook({ categoryId: pasteCategoryId.value, participantId: target.id, file })
    pastedFile.value = null
    await refresh()
  }
  catch (error) {
    pasteError.value = toErrorMessage(error)
  }
  finally {
    pasteSaving.value = false
  }
}

// --- Edit week number / date ------------------------------------------------
const weekNumber = ref(runway.value?.week_number ?? 1)
const runwayDate = ref(runway.value ? toDatetimeLocal(runway.value.runway_date) : '')
const runwayDetailsSaving = ref(false)
const runwayDetailsError = ref<string | null>(null)

const runwayDetailsChanged = computed(
  () => weekNumber.value !== runway.value?.week_number
    || (!!runway.value && runwayDate.value !== toDatetimeLocal(runway.value.runway_date)),
)

async function saveRunwayDetails(): Promise<void> {
  if (!runwayDetailsChanged.value || !(weekNumber.value > 0) || !runwayDate.value || runwayDetailsSaving.value) return

  runwayDetailsSaving.value = true
  runwayDetailsError.value = null
  try {
    const { error } = await supabase
      .from('runways')
      .update({ week_number: weekNumber.value, runway_date: fromDatetimeLocal(runwayDate.value) })
      .eq('id', runwayId)
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

// --- Categories: add, edit title / intro, delete -----------------------------
const categoryDrafts = reactive<Record<string, { title: string, intro: string }>>({})
watch(categories, (list) => {
  for (const category of list) {
    categoryDrafts[category.id] ??= { title: category.title, intro: category.intro_text ?? '' }
  }
}, { immediate: true })

const categorySavingId = ref<string | null>(null)
const categoryErrors = reactive<Record<string, string>>({})

const categoryChanged = (category: Category): boolean => {
  const draft = categoryDrafts[category.id]
  return !!draft && (draft.title.trim() !== category.title || (draft.intro.trim() || null) !== category.intro_text)
}

async function saveCategory(category: Category): Promise<void> {
  const draft = categoryDrafts[category.id]
  if (!draft || !categoryChanged(category) || !draft.title.trim() || categorySavingId.value) return

  categorySavingId.value = category.id
  delete categoryErrors[category.id]
  try {
    const { error } = await supabase
      .from('categories')
      .update({ title: draft.title.trim(), intro_text: draft.intro.trim() || null })
      .eq('id', category.id)
    if (error) throw error
    await refresh()
  }
  catch (error) {
    categoryErrors[category.id] = toErrorMessage(error)
  }
  finally {
    categorySavingId.value = null
  }
}

async function deleteCategory(category: Category): Promise<void> {
  if (categorySavingId.value) return
  if (!window.confirm(`¿Eliminar la categoría «${category.title}»? También se borrarán sus looks.`)) return

  categorySavingId.value = category.id
  delete categoryErrors[category.id]
  try {
    // The looks cascade with the row; list their files first so they can be removed from Storage
    const files = await listCategoryFiles(category.id)
    const { error } = await supabase.from('categories').delete().eq('id', category.id)
    if (error) throw error
    await removeFiles(files)
    await refresh()
  }
  catch (error) {
    categoryErrors[category.id] = toErrorMessage(error)
  }
  finally {
    categorySavingId.value = null
  }
}

const newCategoryOpen = ref(false)
const newTitle = ref('')
const newIntro = ref('')
const newCategorySaving = ref(false)
const newCategoryError = ref<string | null>(null)

function openNewCategory(): void {
  newTitle.value = ''
  newIntro.value = ''
  newCategoryError.value = null
  newCategoryOpen.value = true
}

async function createCategory(): Promise<void> {
  if (!newTitle.value.trim() || newCategorySaving.value) return

  newCategorySaving.value = true
  newCategoryError.value = null
  try {
    const { error } = await supabase
      .from('categories')
      .insert({ runway_id: runwayId, title: newTitle.value.trim(), intro_text: newIntro.value.trim() || null })
    if (error) throw error
    newCategoryOpen.value = false
    await refresh()
  }
  catch (error) {
    newCategoryError.value = toErrorMessage(error)
  }
  finally {
    newCategorySaving.value = false
  }
}

// --- Status changes -------------------------------------------------------
const statusSaving = ref(false)
const statusError = ref<string | null>(null)

async function changeStatus(status: RunwayStatus): Promise<void> {
  if (statusSaving.value) return

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
    const { error } = await supabase.from('runways').update({ status }).eq('id', runwayId)
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
  <main v-if="runway" class="page">
    <AppNav />
    <AppBreadcrumb
      :items="[
        { label: 'Inicio', to: '/' },
        { label: 'Panel del jurado', to: '/admin' },
        { label: `Semana ${runway.week_number}` },
      ]"
    />

    <header class="page-header">
      <h1>Semana {{ runway.week_number }}</h1>
    </header>

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

    <section class="section" aria-labelledby="categories-title">
      <div class="section-header">
        <h2 id="categories-title">
          Categorías
        </h2>
        <button type="button" class="btn btn--primary" @click="openNewCategory">
          + Nueva categoría
        </button>
      </div>

      <p v-if="!categories.length" class="empty">
        Añade al menos una categoría para poder subir los looks.
      </p>

      <form
        v-for="category in categories"
        :key="category.id"
        class="card form"
        @submit.prevent="saveCategory(category)"
      >
        <div class="field">
          <label :for="`category-title-${category.id}`" class="field__label">Título</label>
          <input
            :id="`category-title-${category.id}`"
            v-model="categoryDrafts[category.id]!.title"
            class="field__input"
            type="text"
            maxlength="100"
            required
          >
        </div>
        <div class="field">
          <label :for="`category-intro-${category.id}`" class="field__label">Introducción</label>
          <textarea
            :id="`category-intro-${category.id}`"
            v-model="categoryDrafts[category.id]!.intro"
            class="field__input"
            rows="3"
          />
        </div>
        <p v-if="categoryErrors[category.id]" class="form-error" role="alert">
          {{ categoryErrors[category.id] }}
        </p>
        <div class="form-actions">
          <button
            v-if="canEditLooks(runway.status)"
            type="button"
            class="btn btn--ghost"
            :disabled="categorySavingId !== null"
            @click="deleteCategory(category)"
          >
            Eliminar
          </button>
          <button type="submit" class="btn btn--primary" :disabled="!categoryChanged(category) || categorySavingId !== null">
            {{ categorySavingId === category.id ? 'Guardando…' : 'Guardar' }}
          </button>
        </div>
      </form>
    </section>

    <section v-if="categories.length" class="section" aria-labelledby="looks-title">
      <h2 id="looks-title">
        Looks
      </h2>

      <div class="tabs" role="tablist" aria-labelledby="looks-title">
        <button
          v-for="tab in looksTabs"
          :id="`looks-tab-${tab.id}`"
          :key="tab.id"
          type="button"
          role="tab"
          class="tabs__tab"
          :class="{ 'tabs__tab--active': looksTab === tab.id }"
          :aria-selected="looksTab === tab.id"
          :aria-controls="`looks-panel-${tab.id}`"
          :tabindex="looksTab === tab.id ? 0 : -1"
          @click="looksTab = tab.id"
        >
          {{ tab.label }} ({{ tab.done }} / {{ tab.total }})
        </button>
      </div>

      <p v-if="!canEditLooks(runway.status)" class="hint">
        La votación ya abrió: los looks no se pueden modificar.
      </p>
      <p v-else class="hint">
        Cada reina tiene un look por categoría. Haz clic en la foto para elegir una imagen, o pega una imagen del portapapeles (Ctrl+V) para asignarla.
      </p>

      <div
        v-show="looksTab === 'queens'"
        id="looks-panel-queens"
        role="tabpanel"
        aria-labelledby="looks-tab-queens"
      >
        <template v-if="data?.contestants.length">
          <div v-for="category in categories" :key="category.id" class="looks-group">
            <h3 v-if="categories.length > 1" class="looks-group__title">
              {{ category.title }}
            </h3>
            <ul class="row-list">
              <AdminLookRow
                v-for="contestant in data.contestants"
                :key="contestant.id"
                :category-id="category.id"
                :contestant="contestant"
                :look="looksByKey.get(lookKey(category.id, contestant.id)) ?? null"
                :editable="canEditLooks(runway.status)"
                @changed="refresh()"
              />
            </ul>
          </div>
        </template>
        <p v-else class="empty">
          Aún no hay concursantes. Regístralos en <NuxtLink to="/admin/participants" class="link">Participantes</NuxtLink>.
        </p>
      </div>

      <div
        v-show="looksTab === 'jury'"
        id="looks-panel-jury"
        role="tabpanel"
        aria-labelledby="looks-tab-jury"
      >
        <p class="hint">
          Cada jurado sube su foto y una presentación por categoría: se muestran en la portada mientras la semana está en Pasarela.
        </p>
        <template v-if="data?.judges.length">
          <div v-for="category in categories" :key="category.id" class="looks-group">
            <h3 v-if="categories.length > 1" class="looks-group__title">
              {{ category.title }}
            </h3>
            <ul class="row-list">
              <AdminLookRow
                v-for="judge in data.judges"
                :key="judge.id"
                kind="jury"
                :category-id="category.id"
                :contestant="judge"
                :look="juryLooksByKey.get(lookKey(category.id, judge.id)) ?? null"
                :editable="canEditLooks(runway.status)"
                @changed="refresh()"
              />
            </ul>
          </div>
        </template>
        <p v-else class="empty">
          Aún no hay jurados. Asigna el rol en <NuxtLink to="/admin/participants" class="link">Participantes</NuxtLink>.
        </p>
      </div>
    </section>

    <AppModal :open="newCategoryOpen" title="Nueva categoría" @close="newCategoryOpen = false">
      <form class="form" @submit.prevent="createCategory">
        <div class="field">
          <label for="new-category-title" class="field__label">Título</label>
          <input
            id="new-category-title"
            v-model="newTitle"
            class="field__input"
            type="text"
            maxlength="100"
            required
            placeholder="Ej. Alta costura espacial"
          >
        </div>
        <div class="field">
          <label for="new-category-intro" class="field__label">Introducción</label>
          <textarea
            id="new-category-intro"
            v-model="newIntro"
            class="field__input"
            rows="3"
            placeholder="Describe el tema (opcional)"
          />
        </div>
        <p v-if="newCategoryError" class="form-error" role="alert">
          {{ newCategoryError }}
        </p>
        <div class="form-actions">
          <button type="button" class="btn btn--ghost" @click="newCategoryOpen = false">
            Cancelar
          </button>
          <button type="submit" class="btn btn--primary" :disabled="!newTitle.trim() || newCategorySaving">
            {{ newCategorySaving ? 'Creando…' : 'Crear categoría' }}
          </button>
        </div>
      </form>
    </AppModal>

    <AppModal
      :open="pastedFile !== null"
      :title="pasteKind === 'jury' ? 'Asignar imagen a un jurado' : 'Asignar imagen a una reina'"
      @close="closePaste"
    >
      <form class="form" @submit.prevent="savePasted">
        <img v-if="pastedPreview" class="paste-preview" :src="pastedPreview" alt="Imagen pegada">
        <div v-if="categories.length > 1" class="field">
          <label for="paste-category" class="field__label">Categoría</label>
          <select id="paste-category" v-model="pasteCategoryId" class="field__input" required @change="pasteTargetId = ''">
            <option v-for="category in categories" :key="category.id" :value="category.id">
              {{ category.title }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="paste-target" class="field__label">{{ pasteKind === 'jury' ? 'Jurado' : 'Reina' }}</label>
          <select id="paste-target" v-model="pasteTargetId" class="field__input" required>
            <option value="" disabled>
              Selecciona…
            </option>
            <option v-for="person in pasteCandidates" :key="person.id" :value="person.id">
              {{ optionLabel(person) }}
            </option>
          </select>
        </div>
        <p v-if="pasteTargetBlocked" class="hint">
          Los jurados necesitan una presentación: sube su primera foto desde su fila.
        </p>
        <p v-if="pasteError" class="form-error" role="alert">
          {{ pasteError }}
        </p>
        <div>
          <button type="submit" class="btn btn--primary" :disabled="!pasteTargetId || pasteTargetBlocked || pasteSaving">
            {{ pasteSaving ? 'Guardando…' : 'Asignar' }}
          </button>
        </div>
      </form>
    </AppModal>
  </main>

  <main v-else class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Panel del jurado', to: '/admin' }]" />
    <p class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
  </main>
</template>

<style scoped lang="scss">
.looks-group {
  display: grid;
  gap: var(--space-3);
  margin-top: var(--space-4);
}

.looks-group__title {
  font-size: 1.125rem;
  color: var(--color-title);
}
</style>
