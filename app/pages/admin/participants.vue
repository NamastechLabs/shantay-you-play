<script setup lang="ts">
import type { Enums, Tables } from '~/types/database.types'

definePageMeta({ middleware: 'jurado' })

type ParticipantRow = Pick<Tables<'participants'>, 'id' | 'user_id' | 'name' | 'drag_name' | 'email' | 'role'>
type Role = Enums<'participant_role'>

const ROLE_LABELS: Record<Role, string> = { concursante: 'Concursante', jurado: 'Jurado' }

/** Postgres unique_violation: duplicate email or drag name */
const UNIQUE_VIOLATION = '23505'

const supabase = useSupabaseClient()

const { data: participants, error: loadError, refresh } = await useAsyncData(
  'admin-participants',
  async (): Promise<ParticipantRow[]> => {
    const { data, error } = await supabase
      .from('participants')
      .select('id, user_id, name, drag_name, email, role')
      .order('name', { ascending: true })

    if (error) throw error
    return data
  },
)

// --- Register -------------------------------------------------------------
const name = ref('')
const email = ref('')
const dragName = ref('')
const role = ref<Role>('concursante')
const saving = ref(false)
const errorMessage = ref<string | null>(null)

const canCreate = computed(() => name.value.trim().length > 0 && email.value.includes('@'))

async function createParticipant(): Promise<void> {
  if (!canCreate.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase.from('participants').insert({
      name: name.value.trim(),
      // The database stores emails lowercase so first-login matching is exact
      email: email.value.trim().toLowerCase(),
      drag_name: dragName.value.trim() || null,
      role: role.value,
    })

    if (error) {
      if (error.code === UNIQUE_VIOLATION) {
        throw new Error(error.message.includes('drag_name') ? 'Ese nombre drag ya está en uso' : 'Ya hay alguien registrado con ese correo')
      }
      throw error
    }

    name.value = ''
    email.value = ''
    dragName.value = ''
    role.value = 'concursante'
    await refresh()
  }
  catch (error) {
    errorMessage.value = toErrorMessage(error)
  }
  finally {
    saving.value = false
  }
}

// --- Remove (only people who haven't signed in yet) -----------------------
const removeError = ref<string | null>(null)

async function removeParticipant(participant: ParticipantRow): Promise<void> {
  const confirmed = window.confirm(
    `¿Eliminar a ${participant.drag_name ?? participant.name}? También se borrarán sus looks.`,
  )
  if (!confirmed) return

  removeError.value = null
  try {
    const { data, error } = await supabase
      .from('participants')
      .delete()
      .eq('id', participant.id)
      .select('id')

    if (error) throw error
    if (!data.length) throw new Error('No se pudo eliminar: esa persona ya inició sesión')
    await refresh()
  }
  catch (error) {
    removeError.value = toErrorMessage(error)
  }
}
</script>

<template>
  <main class="participants">
    <header>
      <h1>Participantes</h1>
      <NuxtLink to="/admin">
        ← Panel
      </NuxtLink>
    </header>

    <section>
      <h2>Registrar participante</h2>
      <p class="hint">
        Cuando esta persona inicie sesión con Google usando este correo, quedará vinculada automáticamente.
      </p>
      <form @submit.prevent="createParticipant">
        <label>
          Nombre
          <input v-model="name" type="text" maxlength="100" required placeholder="Nombre real">
        </label>
        <label>
          Correo (el de su cuenta de Google)
          <input v-model="email" type="email" required autocomplete="off" placeholder="persona@gmail.com">
        </label>
        <label>
          Nombre drag (opcional)
          <input v-model="dragName" type="text" minlength="2" maxlength="50" placeholder="Si lo dejas vacío, se lo pediremos al entrar">
        </label>
        <label>
          Rol
          <select v-model="role">
            <option v-for="(label, value) in ROLE_LABELS" :key="value" :value="value">
              {{ label }}
            </option>
          </select>
        </label>
        <button type="submit" :disabled="!canCreate || saving">
          {{ saving ? 'Registrando…' : 'Registrar' }}
        </button>
        <p v-if="errorMessage" class="error" role="alert">
          {{ errorMessage }}
        </p>
      </form>
    </section>

    <section>
      <h2>Registrados ({{ participants?.length ?? 0 }})</h2>
      <p v-if="loadError" class="error" role="alert">
        {{ toErrorMessage(loadError) }}
      </p>
      <p v-if="removeError" class="error" role="alert">
        {{ removeError }}
      </p>
      <ul v-if="participants?.length" class="list">
        <li v-for="participant in participants" :key="participant.id">
          <div>
            <strong>{{ participant.drag_name ?? participant.name }}</strong>
            <span v-if="participant.drag_name" class="real-name">{{ participant.name }}</span>
            <small>{{ participant.email }}</small>
          </div>
          <div class="badges">
            <span class="badge">{{ ROLE_LABELS[participant.role] }}</span>
            <span class="badge" :class="{ pending: !participant.user_id }">
              {{ participant.user_id ? 'Ya inició sesión' : 'Pendiente' }}
            </span>
            <button v-if="!participant.user_id" type="button" @click="removeParticipant(participant)">
              Eliminar
            </button>
          </div>
        </li>
      </ul>
      <p v-else-if="!loadError">
        Aún no hay participantes.
      </p>
    </section>
  </main>
</template>

<style scoped>
.participants {
  max-width: 40rem;
  margin: 0 auto;
  padding: 1rem;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

form {
  display: grid;
  gap: 0.75rem;
}

label {
  display: grid;
  gap: 0.25rem;
}

input,
select {
  padding: 0.5rem;
  font: inherit;
  border-radius: 0.5rem;
  border: 1px solid color-mix(in srgb, currentColor 30%, transparent);
}

button {
  justify-self: start;
  padding: 0.4rem 1rem;
  border-radius: 999px;
  cursor: pointer;
}

button:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.hint {
  opacity: 0.7;
}

.list {
  display: grid;
  gap: 0.5rem;
  padding: 0;
  list-style: none;
}

.list li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1rem;
  border: 1px solid color-mix(in srgb, currentColor 20%, transparent);
  border-radius: 0.5rem;
}

.list li > div:first-child {
  display: grid;
}

.real-name,
small {
  opacity: 0.7;
}

.badges {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.badge {
  padding: 0.1rem 0.5rem;
  font-size: 0.8rem;
  border: 1px solid currentColor;
  border-radius: 999px;
}

.badge.pending {
  border-style: dashed;
  opacity: 0.7;
}

.error {
  color: #d33;
}
</style>
