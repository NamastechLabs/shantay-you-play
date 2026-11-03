<script setup lang="ts">
import type { Look } from '~/composables/useLookUpload'
import type { Tables } from '~/types/database.types'

type Contestant = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
type LookSummary = Pick<Look, 'id' | 'category_id' | 'participant_id' | 'intro'> & LookImages

const props = defineProps<{
  categoryId: string
  contestant: Contestant
  look: LookSummary | null
  /** False once voting opens: looks are then read-only */
  editable: boolean
  /** Heading of the row; defaults to the queen's name (e.g. the category title on the queen's own page) */
  title?: string
}>()

const emit = defineEmits<{ changed: [] }>()

const { saveLook, deleteLook } = useLookUpload()

const files = ref<Partial<Record<LookSlot, File>>>({})
const removed = ref<Set<LookSlot>>(new Set())
const intro = ref(props.look?.intro ?? '')
const saving = ref(false)
const errorMessage = ref<string | null>(null)
// Bumping the key remounts the file inputs, which is the only way to clear them
const inputKey = ref(0)

const introId = useId()
const formId = useId()
const displayName = computed(() => props.contestant.drag_name ?? props.contestant.name)

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
  inputKey.value++
}

// The saved look changed (after a save or a paste): drop the pending edits
watch(() => props.look, reset)

function srcFor(slot: LookSlot): string | null {
  if (previews.value[slot]) return previews.value[slot]!
  return removed.value.has(slot) ? null : props.look?.[slot] ?? null
}

function onFileChange(slot: LookSlot, event: Event): void {
  const file = (event.target as HTMLInputElement).files?.[0]
  if (!file) return
  if (previews.value[slot]) URL.revokeObjectURL(previews.value[slot]!)
  files.value = { ...files.value, [slot]: file }
  previews.value = { ...previews.value, [slot]: URL.createObjectURL(file) }
  removed.value.delete(slot)
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

const normalizedIntro = computed(() => intro.value.trim() || null)
const hasFront = computed(() => srcFor('image_url') !== null)
const changed = computed(() =>
  Object.keys(files.value).length > 0 || removed.value.size > 0 || normalizedIntro.value !== (props.look?.intro ?? null),
)
const canSave = computed(() => hasFront.value && changed.value)

// Deletes the look (photos and intro) straight away
async function resetLook(): Promise<void> {
  if (!props.look || saving.value) return
  if (!window.confirm(`¿Borrar las fotos y la intro del look de ${displayName.value}?`)) return

  saving.value = true
  errorMessage.value = null
  try {
    await deleteLook(props.look)
    emit('changed')
  }
  catch (error) {
    errorMessage.value = toErrorMessage(error)
  }
  finally {
    saving.value = false
  }
}

async function save(): Promise<void> {
  if (!canSave.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    await saveLook({
      look: props.look,
      categoryId: props.categoryId,
      participantId: props.contestant.id,
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

    <ul class="look-slot__grid" :aria-label="`Fotos del look de ${displayName}`">
      <li v-for="slot in LOOK_SLOTS" :key="slot.key" class="look-slot__cell">
        <component :is="editable ? 'label' : 'div'" class="look-slot__picture" :class="{ 'look-slot__picture--editable': editable }">
          <img v-if="srcFor(slot.key)" class="look-slot__photo" :src="srcFor(slot.key)!" :alt="`${slot.label} del look de ${displayName}`">
          <span v-else class="look-slot__placeholder">{{ slot.label }}{{ slot.key === 'image_url' ? ' *' : '' }}</span>
          <template v-if="editable">
            <span class="look-slot__change" aria-hidden="true">{{ srcFor(slot.key) ? 'Cambiar' : 'Añadir' }}</span>
            <input
              :key="`${slot.key}-${inputKey}`"
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
        <label :for="introId" class="field__label">Intro del look</label>
        <textarea
          :id="introId"
          v-model="intro"
          class="field__input"
          rows="2"
          maxlength="1000"
          placeholder="Opcional"
        />
      </template>
      <p v-else-if="look?.intro" class="muted">
        {{ look.intro }}
      </p>
      <p v-else-if="!look" class="muted">
        Sin look
      </p>

      <p v-if="errorMessage" class="form-error" role="alert">
        {{ errorMessage }}
      </p>
    </form>

    <div v-if="editable" class="form-actions">
      <button v-if="look" type="button" class="btn btn--ghost" :disabled="saving" @click="resetLook()">
        Reset
      </button>
      <button type="submit" class="btn btn--primary" :form="formId" :disabled="!canSave || saving">
        {{ saving ? 'Guardando…' : 'Guardar' }}
      </button>
    </div>
  </li>
</template>
