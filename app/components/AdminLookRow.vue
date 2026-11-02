<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Contestant = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
type LookSummary = Pick<Tables<'looks'>, 'id' | 'category_id' | 'participant_id' | 'image_url' | 'intro'>

const props = defineProps<{
  categoryId: string
  contestant: Contestant
  look: LookSummary | null
  /** False once voting opens: looks are then read-only */
  editable: boolean
}>()

const emit = defineEmits<{ changed: [] }>()

const supabase = useSupabaseClient()
const { uploadLook, replaceLookImage } = useLookUpload()

const file = ref<File | null>(null)
const intro = ref(props.look?.intro ?? '')
const saving = ref(false)
const errorMessage = ref<string | null>(null)
// Bumping the key remounts the file input, which is the only way to clear it
const inputKey = ref(0)

const displayName = computed(() => props.contestant.drag_name ?? props.contestant.name)
const normalizedIntro = computed(() => intro.value.trim() || null)
const introChanged = computed(() => normalizedIntro.value !== (props.look?.intro ?? null))
const canSave = computed(() => (props.look ? file.value !== null || introChanged.value : file.value !== null))

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
        await replaceLookImage(props.look, file.value)
      }
      if (introChanged.value) {
        const { error } = await supabase
          .from('looks')
          .update({ intro: normalizedIntro.value })
          .eq('id', props.look.id)
        if (error) throw error
      }
    }
    else if (file.value) {
      await uploadLook({
        categoryId: props.categoryId,
        participantId: props.contestant.id,
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
    <div>
      <img v-if="look" class="look-slot__photo" :src="look.image_url" :alt="`Look de ${displayName}`" loading="lazy">
      <span v-else class="look-slot__placeholder">Sin look</span>
    </div>

    <form class="look-slot__form" @submit.prevent="save">
      <strong class="look-slot__name">{{ displayName }}</strong>

      <template v-if="editable">
        <input
          :key="inputKey"
          class="field__input field__input--file"
          type="file"
          accept="image/*"
          :aria-label="`Foto del look de ${displayName}`"
          @change="onFileChange"
        >
        <textarea
          v-model="intro"
          class="field__input"
          rows="2"
          maxlength="500"
          :aria-label="`Intro del look de ${displayName}`"
          placeholder="Intro del look (opcional)"
        />
        <button type="submit" class="btn btn--secondary" :disabled="!canSave || saving">
          {{ saving ? 'Guardando…' : look ? 'Guardar cambios' : 'Subir look' }}
        </button>
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
