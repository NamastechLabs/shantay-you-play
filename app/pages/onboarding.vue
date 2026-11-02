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
  <main class="auth-center">
    <div class="auth-center__card">
      <p class="auth-center__brand">
        Drag Race Game
      </p>
      <h1>¡Bienvenida a la competencia!</h1>
      <span class="rule" />
      <p class="lead">
        <template v-if="participant">
          {{ participant.name }}, antes
        </template>
        <template v-else>
          Antes
        </template>
        de pisar la pasarela necesitamos tu nombre drag.
      </p>

      <form class="form" @submit.prevent="submit">
        <div class="field">
          <label for="drag-name" class="field__label">Nombre drag</label>
          <input
            id="drag-name"
            v-model="dragName"
            class="field__input"
            type="text"
            autocomplete="nickname"
            minlength="2"
            maxlength="50"
            required
            autofocus
            placeholder="Ej. Miss Fierce"
          >
        </div>
        <button type="submit" class="btn btn--primary btn--block" :disabled="!isValid || saving">
          {{ saving ? 'Guardando…' : 'Guardar' }}
        </button>
      </form>

      <p v-if="errorMessage" class="form-error" role="alert">
        {{ errorMessage }}
      </p>
    </div>
  </main>
</template>
