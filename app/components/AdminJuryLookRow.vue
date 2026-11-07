<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Judge = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
type JuryLookSummary = Pick<Tables<'jury_looks'>, 'id' | 'category_id' | 'participant_id' | 'intro'> & LookImages

const props = defineProps<{
  categoryId: string
  judge: Judge
  look: JuryLookSummary | null
  /** Heading of the row; defaults to the judge's name (e.g. the category title on a guest's own page) */
  title?: string
  /** False once voting opens: looks are then read-only */
  editable: boolean
}>()

const emit = defineEmits<{ changed: [] }>()

const { saveJuryLook } = useLookUpload()

const files = ref<Partial<Record<LookSlot, File>>>({})
const removed = ref<Set<LookSlot>>(new Set())
const intro = ref(props.look?.intro ?? '')
const saving = ref(false)
const errorMessage = ref<string | null>(null)
// Bumping the key remounts the file inputs, which is the only way to clear them
const inputKey = ref(0)

const introId = useId()
const formId = useId()
const displayName = computed(() => props.judge.drag_name ?? props.judge.name)

// Previews of the chosen files, in place of the saved photos until saved
const previews = ref<Partial<Record<LookSlot, string>>>({})
function revokePreviews(): void {
  for (const url of Object.values(previews.value)) URL.revokeObjectURL(url)
  previews.value = {}
}
onBeforeUnmount(revokePreviews)

function reset(): void {
  revokePreviews()
  files.value = {}
  removed.value = new Set()
  intro.value = props.look?.intro ?? ''
  pickNotice.value = null
  inputKey.value++
}

// The saved look changed (after a save or a paste): drop the pending edits
watch(() => props.look, reset)

function srcFor(slot: LookSlot): string | null {
  if (previews.value[slot]) return previews.value[slot]!
  return removed.value.has(slot) ? null : props.look?.[slot] ?? null
}

function setFile(slot: LookSlot, file: File): void {
  if (previews.value[slot]) URL.revokeObjectURL(previews.value[slot]!)
  files.value = { ...files.value, [slot]: file }
  previews.value = { ...previews.value, [slot]: URL.createObjectURL(file) }
  removed.value.delete(slot)
}

// Replaces the photo of one slot
function onFileChange(slot: LookSlot, event: Event): void {
  const file = (event.target as HTMLInputElement).files?.[0]
  if (file) setFile(slot, file)
}

// The photos that are shown, and the slots still free (the first free one is the front until it is set)
const filledSlots = computed(() => LOOK_SLOTS.filter(slot => srcFor(slot.key)))
const freeSlots = computed(() => LOOK_SLOTS.filter(slot => !srcFor(slot.key)))
const pickNotice = ref<string | null>(null)

// The file dialog allows several files, but cannot cap them: extra ones are dropped here
function onFilesAdded(event: Event): void {
  const picked = Array.from((event.target as HTMLInputElement).files ?? [])
  const free = freeSlots.value
  picked.slice(0, free.length).forEach((file, index) => setFile(free[index]!.key, file))
  pickNotice.value = picked.length > free.length
    ? `Solo caben ${LOOK_SLOTS.length} fotos por look: se usaron las primeras ${free.length}.`
    : null
  inputKey.value++
}

function removeSlot(slot: LookSlot): void {
  if (previews.value[slot]) URL.revokeObjectURL(previews.value[slot]!)
  const { [slot]: _file, ...restFiles } = files.value
  const { [slot]: _preview, ...restPreviews } = previews.value
  files.value = restFiles
  previews.value = restPreviews
  // Nothing saved in this slot, so there is nothing to remove from the database
  if (props.look?.[slot]) removed.value.add(slot)
  inputKey.value++
}

const normalizedIntro = computed(() => intro.value.trim())
const hasFront = computed(() => srcFor('image_url') !== null)
const changed = computed(() =>
  Object.keys(files.value).length > 0 || removed.value.size > 0 || normalizedIntro.value !== (props.look?.intro ?? ''),
)
// The intro is required: the jury is shown on the homepage with it
const canSave = computed(() => hasFront.value && normalizedIntro.value !== '' && changed.value)

async function save(): Promise<void> {
  if (!canSave.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    await saveJuryLook({
      look: props.look,
      categoryId: props.categoryId,
      participantId: props.judge.id,
      files: files.value,
      removed: [...removed.value],
      intro: normalizedIntro.value,
    })
    emit('changed')
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
  <li class="look-slot look-slot--queen">
    <strong class="look-slot__name">{{ title ?? displayName }}</strong>

    <!-- Tablet portrait and smaller: the photos plus one stacked placeholder -->
    <ul class="look-slot__grid look-slot__grid--stacked" :aria-label="`Fotos del look de ${displayName}`">
      <li v-for="slot in filledSlots" :key="slot.key" class="look-slot__cell">
        <component :is="editable ? 'label' : 'div'" class="look-slot__picture" :class="{ 'look-slot__picture--editable': editable }">
          <img class="look-slot__photo" :src="srcFor(slot.key)!" :alt="`${slot.label} del look de ${displayName}`">
          <span class="look-slot__tag">{{ slot.label }}</span>
          <template v-if="editable">
            <span class="look-slot__change" aria-hidden="true">Cambiar</span>
            <input
              :key="`${slot.key}-${inputKey}`"
              class="sr-only"
              type="file"
              accept="image/*"
              :aria-label="`${slot.label}: cambiar la foto del look de ${displayName}`"
              @change="onFileChange(slot.key, $event)"
            >
          </template>
        </component>
        <button
          v-if="editable && slot.key !== 'image_url'"
          type="button"
          class="look-slot__remove"
          :aria-label="`Quitar la foto ${slot.label}`"
          @click="removeSlot(slot.key)"
        >
          ×
        </button>
      </li>

      <!-- One placeholder, stacked like several photos, that takes up to as many files as there are free slots -->
      <li v-if="editable && freeSlots.length" class="look-slot__cell">
        <label class="look-slot__add">
          <span class="look-slot__add-title">{{ filledSlots.length ? '+ Añadir' : 'Añadir fotos' }}</span>
          <span class="look-slot__add-hint">
            {{ filledSlots.length ? `Caben ${freeSlots.length} más` : `Hasta ${LOOK_SLOTS.length} · la primera es el frente` }}
          </span>
          <input
            :key="`add-${inputKey}`"
            class="sr-only"
            type="file"
            accept="image/*"
            multiple
            :aria-label="`Añadir fotos al look de ${displayName} (hasta ${freeSlots.length})`"
            @change="onFilesAdded"
          >
        </label>
      </li>
    </ul>
    <p v-if="pickNotice" class="hint" role="status">
      {{ pickNotice }}
    </p>

    <!-- Tablet landscape and larger: the four slots side by side, each with its own placeholder -->
    <ul class="look-slot__grid look-slot__grid--slots" :aria-label="`Fotos del look de ${displayName}`">
      <li v-for="slot in LOOK_SLOTS" :key="slot.key" class="look-slot__cell">
        <component :is="editable ? 'label' : 'div'" class="look-slot__picture" :class="{ 'look-slot__picture--editable': editable }">
          <img v-if="srcFor(slot.key)" class="look-slot__photo" :src="srcFor(slot.key)!" :alt="`${slot.label} del look de ${displayName}`">
          <span v-else class="look-slot__placeholder">{{ editable ? slot.label : 'Sin foto' }}{{ editable && slot.key === 'image_url' ? ' *' : '' }}</span>
          <template v-if="editable">
            <span class="look-slot__change" aria-hidden="true">{{ srcFor(slot.key) ? 'Cambiar' : 'Añadir' }}</span>
            <input
              :key="`slot-${slot.key}-${inputKey}`"
              class="sr-only"
              type="file"
              accept="image/*"
              :aria-label="`${slot.label}: foto del look de ${displayName}`"
              @change="onFileChange(slot.key, $event)"
            >
          </template>
        </component>
        <button
          v-if="editable && slot.key !== 'image_url' && srcFor(slot.key)"
          type="button"
          class="look-slot__remove"
          :aria-label="`Quitar la foto ${slot.label}`"
          @click="removeSlot(slot.key)"
        >
          ×
        </button>
      </li>
    </ul>

    <form :id="formId" class="look-slot__form" @submit.prevent="save">
      <template v-if="editable">
        <label :for="introId" class="field__label">Presentación del jurado</label>
        <textarea
          :id="introId"
          v-model="intro"
          class="field__input"
          rows="2"
          maxlength="1000"
          required
          placeholder="Obligatoria"
        />
      </template>
      <p v-else-if="look?.intro" class="muted">
        {{ look.intro }}
      </p>
      <p v-else class="muted">
        Sin look
      </p>

      <p v-if="errorMessage" class="form-error" role="alert">
        {{ errorMessage }}
      </p>
    </form>

    <div v-if="editable" class="form-actions">
      <button type="submit" class="btn btn--primary" :form="formId" :disabled="!canSave || saving">
        {{ saving ? 'Guardando…' : 'Guardar' }}
      </button>
    </div>
  </li>
</template>
