<script setup lang="ts">
// Dev-only widget (rendered from app.vue under `import.meta.dev`): sign in as any participant
// who already has a login, and go back to your own account afterwards
interface DevParticipant {
  id: string
  name: string
  drag_name: string | null
  email: string
  role: string
  /** Null until the person signs in for the first time: there is no account to impersonate yet */
  user_id: string | null
}

/** The real participant, remembered before the first switch so the widget can go back to them */
const ORIGIN_KEY = 'dev-impersonation-origin'

const supabase = useSupabaseClient()
const { participant, clear } = useCurrentParticipant()

const participants = ref<DevParticipant[]>([])
const selectedId = ref('')
const originId = ref<string | null>(null)
const busy = ref(false)
const errorMessage = ref<string | null>(null)

onMounted(async () => {
  originId.value = window.localStorage.getItem(ORIGIN_KEY)
  try {
    participants.value = await $fetch<DevParticipant[]>('/api/dev/participants')
  }
  catch (error) {
    errorMessage.value = `${toErrorMessage(error)} (¿falta NUXT_SUPABASE_SECRET_KEY en .env?)`
  }
})

const origin = computed(() => participants.value.find(person => person.id === originId.value) ?? null)
const impersonating = computed(() => !!origin.value && participant.value?.id !== originId.value)

const label = (person: DevParticipant): string =>
  `${person.drag_name ?? person.name} · ${person.role}${person.user_id ? '' : ' (sin cuenta)'}${person.id === participant.value?.id ? ' (tú)' : ''}`

async function signInAs(participantId: string): Promise<void> {
  if (busy.value) return

  busy.value = true
  errorMessage.value = null
  try {
    const { tokenHash } = await $fetch<{ tokenHash: string }>('/api/dev/impersonate', {
      method: 'POST',
      body: { participantId },
    })
    const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: 'magiclink' })
    if (error) throw error
    clear()
    // A full reload, so the server renders with the new session cookie
    window.location.reload()
  }
  catch (error) {
    errorMessage.value = toErrorMessage(error)
    busy.value = false
  }
}

function impersonate(): void {
  if (!selectedId.value) return
  // Remember who you really are, only on the first switch
  if (!originId.value && participant.value) window.localStorage.setItem(ORIGIN_KEY, participant.value.id)
  void signInAs(selectedId.value)
}

function stopImpersonating(): void {
  if (!originId.value) return
  window.localStorage.removeItem(ORIGIN_KEY)
  void signInAs(originId.value)
}
</script>

<template>
  <details class="dev-impersonate" :open="impersonating || undefined">
    <summary>{{ impersonating ? `Dev: eres ${participant?.drag_name ?? participant?.name}` : 'Dev: entrar como…' }}</summary>
    <form class="dev-impersonate__form" @submit.prevent="impersonate">
      <button v-if="impersonating" type="button" class="btn btn--primary" :disabled="busy" @click="stopImpersonating">
        Volver a mi cuenta ({{ origin?.drag_name ?? origin?.name }})
      </button>
      <select v-model="selectedId" class="field__input" aria-label="Participante">
        <option value="" disabled>
          Elige una participante…
        </option>
        <option v-for="person in participants" :key="person.id" :value="person.id" :disabled="!person.user_id">
          {{ label(person) }}
        </option>
      </select>
      <button type="submit" class="btn btn--secondary" :disabled="!selectedId || busy">
        {{ busy ? 'Entrando…' : 'Entrar' }}
      </button>
      <p v-if="errorMessage" class="form-error" role="alert">
        {{ errorMessage }}
      </p>
    </form>
  </details>
</template>

<style scoped lang="scss">
.dev-impersonate {
  position: fixed;
  bottom: var(--space-3);
  left: var(--space-3);
  z-index: 100;
  max-width: min(22rem, calc(100vw - var(--space-6)));
  padding: var(--space-2) var(--space-3);
  font-size: 0.875rem;
  background-color: var(--color-surface);
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);

  summary {
    font-weight: 600;
    cursor: pointer;
  }
}

.dev-impersonate__form {
  display: grid;
  gap: var(--space-2);
  margin-top: var(--space-2);
}
</style>
