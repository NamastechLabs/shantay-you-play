<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { CategoryStatus } from '~/utils/categoryStatus'
import type { LookKind } from '~/composables/useLookUpload'

definePageMeta({ middleware: 'jurado' })

type Category = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'intro_text' | 'status'>
type Contestant = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
type LookSummary = Pick<Tables<'looks'>, 'id' | 'category_id' | 'participant_id' | 'image_url' | 'intro'>

interface CategoryDetail {
  category: Category
  contestants: Contestant[]
  looks: LookSummary[]
  judges: Contestant[]
  juryLooks: LookSummary[]
}

const route = useRoute()
const supabase = useSupabaseClient()
const categoryId = String(route.params.id)

const { data, error: loadError, refresh } = await useAsyncData(
  `admin-category-${categoryId}`,
  async (): Promise<CategoryDetail | null> => {
    const [category, contestants, looks, judges, juryLooks] = await Promise.all([
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
      supabase
        .from('participants')
        .select('id, name, drag_name')
        .eq('role', 'jurado')
        .order('name', { ascending: true }),
      supabase
        .from('jury_looks')
        .select('id, category_id, participant_id, image_url, intro')
        .eq('category_id', categoryId),
    ])

    if (category.error) throw category.error
    if (contestants.error) throw contestants.error
    if (looks.error) throw looks.error
    if (judges.error) throw judges.error
    if (juryLooks.error) throw juryLooks.error
    if (!category.data) return null

    return {
      category: category.data,
      contestants: contestants.data,
      looks: looks.data,
      judges: judges.data,
      juryLooks: juryLooks.data,
    }
  },
)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Categoría no encontrada', fatal: true })
}

const category = computed(() => data.value?.category ?? null)
const looksByParticipant = computed(() => new Map(data.value?.looks.map(look => [look.participant_id, look])))
const juryLooksByParticipant = computed(() => new Map(data.value?.juryLooks.map(look => [look.participant_id, look])))

// --- Looks tabs: queens (voted) and jury (shown on the homepage) ----------
type LooksTab = 'queens' | 'jury'
const looksTab = ref<LooksTab>('queens')
const looksTabs = computed<{ id: LooksTab, label: string, done: number, total: number }[]>(() => [
  { id: 'queens', label: 'Reinas', done: data.value?.looks.length ?? 0, total: data.value?.contestants.length ?? 0 },
  { id: 'jury', label: 'Jurados', done: data.value?.juryLooks.length ?? 0, total: data.value?.judges.length ?? 0 },
])
const previousStatus = computed(() => (category.value ? adjacentStatus(category.value.status, -1) : null))
const nextStatus = computed(() => (category.value ? adjacentStatus(category.value.status, 1) : null))
const currentStatusIndex = computed(() => (category.value ? CATEGORY_STATUSES.indexOf(category.value.status) : -1))

// --- Paste an image from the clipboard to assign it to a queen / judge ----
const pastedFile = ref<File | null>(null)
const pastedPreview = ref<string | null>(null)
const pasteTargetId = ref('')
const pasteSaving = ref(false)
const pasteError = ref<string | null>(null)

// Composables need the Nuxt context, so both are created here rather than on paste
const queenUploads = useLookUpload('queen')
const juryUploads = useLookUpload('jury')

const pasteKind = computed<LookKind>(() => (looksTab.value === 'jury' ? 'jury' : 'queen'))
const pasteCandidates = computed(() => (pasteKind.value === 'jury' ? data.value?.judges : data.value?.contestants) ?? [])
const pasteExistingLooks = computed(() => (pasteKind.value === 'jury' ? juryLooksByParticipant.value : looksByParticipant.value))
const pasteTargetHasLook = computed(() => pasteExistingLooks.value.has(pasteTargetId.value))
// Jury looks need an intro, so a judge without a look must be filled in by hand
const pasteTargetBlocked = computed(() => pasteKind.value === 'jury' && !!pasteTargetId.value && !pasteTargetHasLook.value)

function optionLabel(person: Contestant): string {
  const name = person.drag_name ?? person.name
  return pasteExistingLooks.value.has(person.id) ? `${name} (reemplazar look)` : name
}

function closePaste(): void {
  if (pasteSaving.value) return
  pastedFile.value = null
}

watch(pastedFile, (next) => {
  if (pastedPreview.value) URL.revokeObjectURL(pastedPreview.value)
  pastedPreview.value = next ? URL.createObjectURL(next) : null
  pasteTargetId.value = ''
  pasteError.value = null
})

function onPaste(event: ClipboardEvent): void {
  if (!category.value || !canEditLooks(category.value.status) || pastedFile.value) return
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
  if (!file || !target || pasteTargetBlocked.value || pasteSaving.value) return

  const { uploadLook, replaceLookImage } = pasteKind.value === 'jury' ? juryUploads : queenUploads
  const existing = pasteExistingLooks.value.get(target.id)

  pasteSaving.value = true
  pasteError.value = null
  try {
    if (existing) await replaceLookImage(existing, file)
    else await uploadLook({ categoryId, participantId: target.id, file })
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

  const confirmation = status === 'reveal'
    ? 'Al pasar a Revelación, la votación se cierra y la portada muestra el Top 3. ¿Continuar?'
    : status === 'closed'
      ? 'Al cerrar la categoría se revelan todos los votos. ¿Continuar?'
      : null
  if (confirmation && !window.confirm(confirmation)) return

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
    <AppBreadcrumb
      :items="[
        { label: 'Inicio', to: '/' },
        { label: 'Panel del jurado', to: '/admin' },
        { label: `Semana ${category.week_number}` },
      ]"
    />

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

      <p v-if="!canEditLooks(category.status)" class="hint">
        La votación ya abrió: los looks no se pueden modificar.
      </p>
      <p v-else class="hint">
        Haz clic en la foto para elegir una imagen, o pega una imagen del portapapeles (Ctrl+V) para asignarla.
      </p>

      <div
        v-show="looksTab === 'queens'"
        id="looks-panel-queens"
        role="tabpanel"
        aria-labelledby="looks-tab-queens"
      >
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
      </div>

      <div
        v-show="looksTab === 'jury'"
        id="looks-panel-jury"
        role="tabpanel"
        aria-labelledby="looks-tab-jury"
      >
        <p class="hint">
          Cada jurado sube su foto y una presentación: se muestran en la portada mientras la categoría está en Pasarela.
        </p>
        <ul v-if="data?.judges.length" class="row-list">
          <AdminLookRow
            v-for="judge in data.judges"
            :key="judge.id"
            kind="jury"
            :category-id="category.id"
            :contestant="judge"
            :look="juryLooksByParticipant.get(judge.id) ?? null"
            :editable="canEditLooks(category.status)"
            @changed="refresh()"
          />
        </ul>
        <p v-else class="empty">
          Aún no hay jurados. Asigna el rol en <NuxtLink to="/admin/participants" class="link">Participantes</NuxtLink>.
        </p>
      </div>
    </section>

    <AppModal
      :open="pastedFile !== null"
      :title="pasteKind === 'jury' ? 'Asignar imagen a un jurado' : 'Asignar imagen a una reina'"
      @close="closePaste"
    >
      <form class="form" @submit.prevent="savePasted">
        <img v-if="pastedPreview" class="paste-preview" :src="pastedPreview" alt="Imagen pegada">
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
