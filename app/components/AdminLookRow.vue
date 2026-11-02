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
  <li class="look-row">
    <div class="photo">
      <img v-if="look" :src="look.image_url" :alt="`Look de ${displayName}`" loading="lazy">
      <span v-else class="placeholder">Sin look</span>
    </div>

    <form @submit.prevent="save">
      <strong>{{ displayName }}</strong>

      <template v-if="editable">
        <input :key="inputKey" type="file" accept="image/*" @change="onFileChange">
        <textarea v-model="intro" rows="2" maxlength="500" placeholder="Intro del look (opcional)" />
        <button type="submit" :disabled="!canSave || saving">
          {{ saving ? 'Guardando…' : look ? 'Guardar cambios' : 'Subir look' }}
        </button>
      </template>
      <p v-else-if="look?.intro">
        {{ look.intro }}
      </p>

      <p v-if="errorMessage" class="error" role="alert">
        {{ errorMessage }}
      </p>
    </form>
  </li>
</template>

<style scoped>
.look-row {
  display: grid;
  grid-template-columns: 8rem 1fr;
  gap: 1rem;
  padding: 0.75rem;
  border: 1px solid color-mix(in srgb, currentColor 20%, transparent);
  border-radius: 0.5rem;
  list-style: none;
}

.photo img,
.placeholder {
  width: 100%;
  aspect-ratio: 3 / 4;
  border-radius: 0.5rem;
  object-fit: cover;
}

.placeholder {
  display: grid;
  place-items: center;
  font-size: 0.8rem;
  opacity: 0.6;
  border: 1px dashed currentColor;
}

form {
  display: grid;
  align-content: start;
  gap: 0.5rem;
}

button {
  justify-self: start;
  padding: 0.5rem 1.25rem;
  border-radius: 999px;
  cursor: pointer;
}

button:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.error {
  margin: 0;
  color: #d33;
}
</style>
