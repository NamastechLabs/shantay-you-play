<script setup lang="ts">
const route = useRoute()
const { participant, setDragName } = useCurrentParticipant()

const dragName = ref('')
const saving = ref(false)
const errorMessage = ref<string | null>(null)

const trimmed = computed(() => dragName.value.trim())
const isValid = computed(() => trimmed.value.length >= 2 && trimmed.value.length <= 50)

/** Only allow same-site paths, so ?redirect= can't send users elsewhere */
function safeRedirect(value: unknown): string {
  return typeof value === 'string' && value.startsWith('/') && !value.startsWith('//') ? value : '/'
}

async function submit(): Promise<void> {
  if (!isValid.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    await setDragName(trimmed.value)
    await navigateTo(safeRedirect(route.query.redirect), { replace: true })
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
  <main class="onboarding">
    <h1>¡Bienvenida a la competencia!</h1>
    <p>
      <template v-if="participant">
        {{ participant.name }}, antes
      </template>
      <template v-else>
        Antes
      </template>
      de pisar la pasarela necesitamos tu nombre drag.
    </p>

    <form @submit.prevent="submit">
      <label for="drag-name">Nombre drag</label>
      <input
        id="drag-name"
        v-model="dragName"
        type="text"
        autocomplete="nickname"
        minlength="2"
        maxlength="50"
        required
        autofocus
        placeholder="Ej. Miss Fierce"
      >
      <button type="submit" :disabled="!isValid || saving">
        {{ saving ? 'Guardando…' : 'Guardar' }}
      </button>
    </form>

    <p v-if="errorMessage" class="error" role="alert">
      {{ errorMessage }}
    </p>
  </main>
</template>

<style scoped>
.onboarding {
  display: grid;
  align-content: center;
  gap: 1rem;
  max-width: 24rem;
  min-height: 100dvh;
  margin: 0 auto;
  padding: 0 1rem;
  text-align: center;
}

form {
  display: grid;
  gap: 0.5rem;
  text-align: left;
}

input {
  padding: 0.75rem;
  font-size: 1rem;
  border-radius: 0.5rem;
  border: 1px solid color-mix(in srgb, currentColor 30%, transparent);
}

button {
  margin-top: 0.5rem;
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
  border-radius: 999px;
  cursor: pointer;
}

button:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.error {
  color: #d33;
}
</style>
