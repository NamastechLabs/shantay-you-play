<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Person = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
type QueenLook = Pick<Tables<'looks'>, 'id' | 'category_id' | 'participant_id' | 'intro'> & LookImages
type JuryLookSummary = Pick<Tables<'jury_looks'>, 'id' | 'category_id' | 'participant_id' | 'image_url' | 'intro'>

const supabase = useSupabaseClient()
const { runway, categories, refresh: refreshRunway } = useAdminRunway()

const { data, error: loadError, refresh } = await useAsyncData(`admin-runway-${runway.value.id}-looks`, async () => {
  const categoryIds = categories.value.map(category => category.id)
  const [contestants, looks, judges, juryLooks] = await Promise.all([
    supabase.from('participants').select('id, name, drag_name').eq('role', 'concursante').order('name', { ascending: true }),
    supabase
      .from('looks')
      .select('id, category_id, participant_id, image_url, image2_url, image3_url, image4_url, intro')
      .in('category_id', categoryIds),
    supabase.from('participants').select('id, name, drag_name').eq('role', 'jurado').order('name', { ascending: true }),
    supabase.from('jury_looks').select('id, category_id, participant_id, image_url, intro').in('category_id', categoryIds),
  ])
  if (contestants.error) throw contestants.error
  if (looks.error) throw looks.error
  if (judges.error) throw judges.error
  if (juryLooks.error) throw juryLooks.error

  return {
    contestants: contestants.data as Person[],
    looks: looks.data as QueenLook[],
    judges: judges.data as Person[],
    juryLooks: juryLooks.data as JuryLookSummary[],
  }
})

const editable = computed(() => canEditLooks(runway.value.status))
const personName = (person: Person): string => person.drag_name ?? person.name

const lookKey = (categoryId: string, participantId: string): string => `${categoryId}:${participantId}`
const looksByKey = computed(() => new Map(data.value?.looks.map(look => [lookKey(look.category_id, look.participant_id), look])))
const juryLooksByKey = computed(() => new Map(data.value?.juryLooks.map(look => [lookKey(look.category_id, look.participant_id), look])))

// --- Tabs (queens are voted, the jury is shown on the homepage) and category ----
type LooksTab = 'queens' | 'jury'
const looksTab = ref<LooksTab>('queens')
const looksTabs = computed<{ id: LooksTab, label: string, done: number, total: number }[]>(() => [
  { id: 'queens', label: 'Reinas', done: data.value?.looks.length ?? 0, total: (data.value?.contestants.length ?? 0) * categories.value.length },
  { id: 'jury', label: 'Jurados', done: data.value?.juryLooks.length ?? 0, total: (data.value?.judges.length ?? 0) * categories.value.length },
])

const categoryId = ref(categories.value[0]?.id ?? '')
const category = computed(() => categories.value.find(item => item.id === categoryId.value) ?? null)

async function refreshAll(): Promise<void> {
  await Promise.all([refresh(), refreshRunway()])
}

// --- Paste an image from the clipboard to assign it to a queen / judge ----
const pastedFile = ref<File | null>(null)
const pastedPreview = ref<string | null>(null)
const pasteCategoryId = ref('')
const pasteTargetId = ref('')
const pasteSlot = ref<LookSlot>('image_url')
const pasteSaving = ref(false)
const pasteError = ref<string | null>(null)

// Composables need the Nuxt context, so it is created here rather than on paste
const { saveLook, replaceJuryImage } = useLookUpload()

const pasteIsJury = computed(() => looksTab.value === 'jury')
const pasteCandidates = computed(() => (pasteIsJury.value ? data.value?.judges : data.value?.contestants) ?? [])
const pasteExisting = (personId: string) =>
  (pasteIsJury.value ? juryLooksByKey.value : looksByKey.value).get(lookKey(pasteCategoryId.value, personId))
const pasteTargetLook = computed(() => pasteExisting(pasteTargetId.value))
// Jury looks need an intro and queens need a front photo, so a new look must be filled in by hand / at the front
const pasteTargetBlocked = computed(() => pasteIsJury.value && !!pasteTargetId.value && !pasteTargetLook.value)
const pasteSlotLocked = computed(() => !pasteIsJury.value && !pasteTargetLook.value)

function optionLabel(person: Person): string {
  return pasteExisting(person.id) ? `${personName(person)} (ya tiene look)` : personName(person)
}

function closePaste(): void {
  if (pasteSaving.value) return
  pastedFile.value = null
}

watch(pastedFile, (next) => {
  if (pastedPreview.value) URL.revokeObjectURL(pastedPreview.value)
  pastedPreview.value = next ? URL.createObjectURL(next) : null
  pasteCategoryId.value = categoryId.value
  pasteTargetId.value = ''
  pasteSlot.value = 'image_url'
  pasteError.value = null
})

// Picking a queen preselects the first empty slot of her look (a new look starts at the front)
watch(pasteTargetId, () => {
  const look = pasteTargetLook.value as QueenLook | undefined
  pasteSlot.value = !pasteIsJury.value && look ? LOOK_SLOTS.find(slot => !look[slot.key])?.key ?? 'image_url' : 'image_url'
})

function onPaste(event: ClipboardEvent): void {
  if (!editable.value || !categories.value.length || pastedFile.value) return
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

  pasteSaving.value = true
  pasteError.value = null
  try {
    if (pasteIsJury.value) {
      await replaceJuryImage(pasteTargetLook.value as JuryLookSummary, file)
    }
    else {
      const existing = pasteTargetLook.value as QueenLook | undefined
      await saveLook({
        look: existing ?? null,
        categoryId: pasteCategoryId.value,
        participantId: target.id,
        files: { [pasteSlot.value]: file },
        removed: [],
        intro: existing?.intro ?? null,
      })
    }
    pastedFile.value = null
    await refreshAll()
  }
  catch (error) {
    pasteError.value = toErrorMessage(error)
  }
  finally {
    pasteSaving.value = false
  }
}
</script>

<template>
  <section v-if="!categories.length" class="section">
    <p class="empty">
      Antes de subir looks, añade una categoría en <NuxtLink :to="`/admin/runways/${runway.id}/categories`" class="link">Categorías</NuxtLink>.
    </p>
  </section>

  <section v-else class="section" aria-labelledby="looks-title">
    <h2 id="looks-title" class="sr-only">
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

    <div v-if="categories.length > 1" class="field">
      <label for="looks-category" class="field__label">Categoría</label>
      <select id="looks-category" v-model="categoryId" class="field__input">
        <option v-for="item in categories" :key="item.id" :value="item.id">
          {{ item.title }}
        </option>
      </select>
    </div>

    <p v-if="loadError" class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
    <p v-else-if="!editable" class="hint">
      La votación ya abrió: los looks no se pueden modificar.
    </p>

    <div
      v-show="looksTab === 'queens'"
      id="looks-panel-queens"
      role="tabpanel"
      aria-labelledby="looks-tab-queens"
    >
      <p v-if="editable" class="hint">
        Cada reina tiene un look por categoría, con hasta 4 fotos. Haz clic en una foto para elegirla, o pega una imagen del portapapeles (Ctrl+V) para asignarla.
      </p>
      <ul v-if="data?.contestants.length && category" class="row-list">
        <LookEditRow
          v-for="contestant in data.contestants"
          :key="`${category.id}:${contestant.id}`"
          :category-id="category.id"
          :contestant="contestant"
          :look="looksByKey.get(lookKey(category.id, contestant.id)) ?? null"
          :editable="editable"
          @changed="refreshAll()"
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
        Cada jurado sube su foto y una presentación por categoría: se muestran en la portada mientras la semana está en Pasarela.
      </p>
      <ul v-if="data?.judges.length && category" class="row-list">
        <AdminJuryLookRow
          v-for="judge in data.judges"
          :key="`${category.id}:${judge.id}`"
          :category-id="category.id"
          :judge="judge"
          :look="juryLooksByKey.get(lookKey(category.id, judge.id)) ?? null"
          :editable="editable"
          @changed="refreshAll()"
        />
      </ul>
      <p v-else class="empty">
        Aún no hay jurados. Asigna el rol en <NuxtLink to="/admin/participants" class="link">Participantes</NuxtLink>.
      </p>
    </div>
  </section>

  <AppModal
    :open="pastedFile !== null"
    :title="pasteIsJury ? 'Asignar imagen a un jurado' : 'Asignar imagen a una reina'"
    @close="closePaste"
  >
    <form class="form" @submit.prevent="savePasted">
      <img v-if="pastedPreview" class="paste-preview" :src="pastedPreview" alt="Imagen pegada">
      <div v-if="categories.length > 1" class="field">
        <label for="paste-category" class="field__label">Categoría</label>
        <select id="paste-category" v-model="pasteCategoryId" class="field__input" required @change="pasteTargetId = ''">
          <option v-for="item in categories" :key="item.id" :value="item.id">
            {{ item.title }}
          </option>
        </select>
      </div>
      <div class="field">
        <label for="paste-target" class="field__label">{{ pasteIsJury ? 'Jurado' : 'Reina' }}</label>
        <select id="paste-target" v-model="pasteTargetId" class="field__input" required>
          <option value="" disabled>
            Selecciona…
          </option>
          <option v-for="person in pasteCandidates" :key="person.id" :value="person.id">
            {{ optionLabel(person) }}
          </option>
        </select>
      </div>
      <div v-if="!pasteIsJury" class="field">
        <label for="paste-slot" class="field__label">Foto</label>
        <select id="paste-slot" v-model="pasteSlot" class="field__input" :disabled="pasteSlotLocked">
          <option v-for="slot in LOOK_SLOTS" :key="slot.key" :value="slot.key">
            {{ slot.label }}
          </option>
        </select>
      </div>
      <p v-if="pasteTargetBlocked" class="hint">
        Los jurados necesitan una presentación: sube su primera foto desde su fila.
      </p>
      <p v-else-if="pasteSlotLocked && pasteTargetId" class="hint">
        Un look nuevo empieza con la foto de frente.
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
</template>
