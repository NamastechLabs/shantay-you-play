<script setup lang="ts">
const MAX_LENGTH = 1000

const props = defineProps<{
  groupId: string
  /** The saved presentation of the group */
  intro: string | null
}>()

const emit = defineEmits<{ changed: [] }>()

const supabase = useSupabaseClient()

const draft = ref(props.intro ?? '')
const saving = ref(false)
const saved = ref(false)
const errorMessage = ref<string | null>(null)

const textareaId = useId()
const changed = computed(() => draft.value.trim() !== (props.intro ?? ''))

// The saved text changed (after saving): the draft matches it again
watch(() => props.intro, (next) => {
  draft.value = next ?? ''
})

async function save(): Promise<void> {
  if (!changed.value || saving.value) return

  saving.value = true
  saved.value = false
  errorMessage.value = null
  // set_group_intro only lets the members of the group write, and only during the Werk Room
  const { error } = await supabase.rpc('set_group_intro', { p_group_id: props.groupId, p_intro: draft.value })
  saving.value = false

  if (error) {
    errorMessage.value = error.code === '42501'
      ? 'No se pudo guardar: el Werk Room ya no está abierto.'
      : toErrorMessage(error)
    return
  }
  saved.value = true
  emit('changed')
}
</script>

<template>
  <section class="group-intro" :aria-labelledby="`${textareaId}-title`">
    <h3 :id="`${textareaId}-title`">
      Presentación del grupo
    </h3>
    <textarea
      :id="textareaId"
      v-model="draft"
      class="field__input"
      rows="4"
      :maxlength="MAX_LENGTH"
      placeholder="Cuenta de qué va vuestro grupo"
      :aria-labelledby="`${textareaId}-title`"
      @input="saved = false"
    />
    <p v-if="errorMessage" class="form-error" role="alert">
      {{ errorMessage }}
    </p>
    <div class="group-intro__footer">
      <p v-if="saved" class="group-intro__saved" role="status">
        ¡Guardado!
      </p>
      <button type="button" class="btn btn--primary" :disabled="!changed || saving" @click="save">
        {{ saving ? 'Guardando…' : 'Guardar presentación' }}
      </button>
    </div>
  </section>
</template>

<style scoped lang="scss">
.group-intro {
  display: grid;
  gap: var(--space-2);
}

.group-intro__footer {
  display: flex;
  gap: var(--space-3);
  align-items: center;
  justify-content: flex-end;
}

.group-intro__saved {
  color: var(--color-success);
}
</style>
