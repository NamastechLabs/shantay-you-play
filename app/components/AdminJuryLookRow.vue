<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Judge = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
type JuryLookSummary = Pick<Tables<'jury_looks'>, 'id' | 'category_id' | 'participant_id' | 'image_url' | 'intro'>

const props = defineProps<{
  categoryId: string
  judge: Judge
  look: JuryLookSummary | null
  /** False once voting opens: looks are then read-only */
  editable: boolean
}>()

const emit = defineEmits<{ changed: [] }>()

const supabase = useSupabaseClient()
const { uploadJuryLook, replaceJuryImage } = useLookUpload()

const file = ref<File | null>(null)
const intro = ref(props.look?.intro ?? '')
const saving = ref(false)
const errorMessage = ref<string | null>(null)
// Bumping the key remounts the file input, which is the only way to clear it
const inputKey = ref(0)

const displayName = computed(() => props.judge.drag_name ?? props.judge.name)
const normalizedIntro = computed(() => intro.value.trim())
const introChanged = computed(() => normalizedIntro.value !== (props.look?.intro ?? ''))
// The intro is required: the jury is shown on the homepage with it
const canSave = computed(() => {
  if (!normalizedIntro.value) return false
  return props.look ? file.value !== null || introChanged.value : file.value !== null
})

// Shows the chosen file in place of the saved photo until it is saved
const previewUrl = ref<string | null>(null)
watch(file, (next) => {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
  previewUrl.value = next ? URL.createObjectURL(next) : null
})
onBeforeUnmount(() => {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
})

const photoSrc = computed(() => previewUrl.value ?? props.look?.image_url ?? null)

function onFileChange(event: Event): void {
  file.value = (event.target as HTMLInputElement).files?.[0] ?? null
}

async function save(): Promise<void> {
  if (!canSave.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    if (props.look) {
      if (file.value) {
        await replaceJuryImage(props.look, file.value)
      }
      if (introChanged.value) {
        const { error } = await supabase.from('jury_looks').update({ intro: normalizedIntro.value }).eq('id', props.look.id)
        if (error) throw error
      }
    }
    else if (file.value) {
      await uploadJuryLook({
        categoryId: props.categoryId,
        participantId: props.judge.id,
        file: file.value,
        intro: normalizedIntro.value,
      })
    }

    file.value = null
    inputKey.value++
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
  <li class="look-slot">
    <component :is="editable ? 'label' : 'div'" class="look-slot__picture" :class="{ 'look-slot__picture--editable': editable }">
      <img v-if="photoSrc" class="look-slot__photo" :src="photoSrc" :alt="`Look de ${displayName}`">
      <span v-else class="look-slot__placeholder">{{ editable ? 'Añadir foto' : 'Sin look' }}</span>
      <template v-if="editable">
        <span v-if="photoSrc" class="look-slot__change" aria-hidden="true">Cambiar foto</span>
        <input
          :key="inputKey"
          class="sr-only"
          type="file"
          accept="image/*"
          :aria-label="`Foto del look de ${displayName}`"
          @change="onFileChange"
        >
      </template>
    </component>

    <form class="look-slot__form" @submit.prevent="save">
      <strong class="look-slot__name">{{ displayName }}</strong>

      <template v-if="editable">
        <textarea
          v-model="intro"
          class="field__input"
          rows="2"
          maxlength="1000"
          required
          :aria-label="`Presentación de ${displayName}`"
          placeholder="Presentación del jurado (obligatoria)"
        />
        <div class="form-actions">
          <button type="submit" class="btn btn--primary" :disabled="!canSave || saving">
            {{ saving ? 'Guardando…' : 'Guardar' }}
          </button>
        </div>
      </template>
      <p v-else-if="look?.intro" class="muted">
        {{ look.intro }}
      </p>

      <p v-if="errorMessage" class="form-error" role="alert">
        {{ errorMessage }}
      </p>
    </form>
  </li>
</template>
