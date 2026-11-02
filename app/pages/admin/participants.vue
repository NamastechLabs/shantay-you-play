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

// --- Register / edit modal --------------------------------------------------
const modalOpen = ref(false)
/** The participant being edited; null while registering a new one */
const editing = ref<ParticipantRow | null>(null)

const name = ref('')
const email = ref('')
const dragName = ref('')
const role = ref<Role>('concursante')
const saving = ref(false)
const errorMessage = ref<string | null>(null)

const modalTitle = computed(() => (editing.value ? 'Editar participante' : 'Registrar participante'))
const canSubmit = computed(() => name.value.trim().length > 0 && (editing.value !== null || email.value.includes('@')))

function openCreate(): void {
  editing.value = null
  name.value = ''
  email.value = ''
  dragName.value = ''
  role.value = 'concursante'
  errorMessage.value = null
  modalOpen.value = true
}

function openEdit(participant: ParticipantRow): void {
  editing.value = participant
  name.value = participant.name
  email.value = participant.email
  dragName.value = participant.drag_name ?? ''
  role.value = participant.role
  errorMessage.value = null
  modalOpen.value = true
}

function uniqueViolationMessage(message: string): string {
  return message.includes('drag_name') ? 'Ese nombre drag ya está en uso' : 'Ya hay alguien registrado con ese correo'
}

async function submit(): Promise<void> {
  if (!canSubmit.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    const current = editing.value
    const { error } = current
      // Judges can only change name and drag name (column grants); email and role are fixed once registered
      ? await supabase
        .from('participants')
        .update({ name: name.value.trim(), drag_name: dragName.value.trim() || null })
        .eq('id', current.id)
      : await supabase.from('participants').insert({
        name: name.value.trim(),
        // The database stores emails lowercase so first-login matching is exact
        email: email.value.trim().toLowerCase(),
        drag_name: dragName.value.trim() || null,
        role: role.value,
      })

    if (error) {
      if (error.code === UNIQUE_VIOLATION) throw new Error(uniqueViolationMessage(error.message))
      throw error
    }

    modalOpen.value = false
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
    modalOpen.value = false
    await refresh()
  }
  catch (error) {
    removeError.value = toErrorMessage(error)
  }
}
</script>

<template>
  <main class="page">
    <AppNav />
    <NuxtLink to="/admin" class="back-link">
      ← Panel
    </NuxtLink>

    <header class="page-header">
      <h1>Participantes</h1>
    </header>

    <section class="section" aria-labelledby="participants-title">
      <div class="section-header">
        <h2 id="participants-title">
          Registrados ({{ participants?.length ?? 0 }})
        </h2>
        <button type="button" class="btn btn--primary" @click="openCreate">
          + Registrar
        </button>
      </div>

      <p v-if="loadError" class="form-error" role="alert">
        {{ toErrorMessage(loadError) }}
      </p>
      <p v-if="removeError" class="form-error" role="alert">
        {{ removeError }}
      </p>

      <ul v-if="participants?.length" class="row-list">
        <li v-for="participant in participants" :key="participant.id" class="row">
          <div class="row__main">
            <strong class="row__title">{{ participant.drag_name ?? participant.name }}</strong>
            <span v-if="participant.drag_name" class="hint">{{ participant.name }}</span>
            <span class="hint">{{ participant.email }}</span>
          </div>
          <div class="row__aside">
            <span class="badge badge--draft">{{ ROLE_LABELS[participant.role] }}</span>
            <span class="badge" :class="participant.user_id ? 'badge--approved' : 'badge--pending'">
              {{ participant.user_id ? 'Ya inició sesión' : 'Pendiente' }}
            </span>
            <button type="button" class="btn btn--ghost" @click="openEdit(participant)">
              Editar
            </button>
          </div>
        </li>
      </ul>
      <p v-else-if="!loadError" class="empty">
        Aún no hay participantes.
      </p>
    </section>

    <AppModal :open="modalOpen" :title="modalTitle" @close="modalOpen = false">
      <p v-if="!editing" class="hint">
        Cuando esta persona inicie sesión con Google usando este correo, quedará vinculada automáticamente.
      </p>
      <p v-else-if="editing.user_id" class="hint">
        Solo se puede eliminar a quien aún no ha iniciado sesión. El correo y el rol no se pueden cambiar.
      </p>
      <p v-else class="hint">
        El correo y el rol no se pueden cambiar. Si te equivocaste, elimina el registro y vuelve a crearlo.
      </p>

      <form class="form" @submit.prevent="submit">
        <div class="field">
          <label for="participant-name" class="field__label">Nombre</label>
          <input
            id="participant-name"
            v-model="name"
            class="field__input"
            type="text"
            maxlength="100"
            required
            placeholder="Nombre real"
          >
        </div>
        <div class="field">
          <label for="participant-email" class="field__label">Correo (el de su cuenta de Google)</label>
          <input
            id="participant-email"
            v-model="email"
            class="field__input"
            type="email"
            required
            autocomplete="off"
            :disabled="editing !== null"
            placeholder="persona@gmail.com"
          >
        </div>
        <div class="field">
          <label for="participant-drag-name" class="field__label">Nombre drag (opcional)</label>
          <input
            id="participant-drag-name"
            v-model="dragName"
            class="field__input"
            type="text"
            minlength="2"
            maxlength="50"
            placeholder="Si lo dejas vacío, se lo pediremos al entrar"
          >
        </div>
        <div class="field">
          <label for="participant-role" class="field__label">Rol</label>
          <select id="participant-role" v-model="role" class="field__input" :disabled="editing !== null">
            <option v-for="(label, value) in ROLE_LABELS" :key="value" :value="value">
              {{ label }}
            </option>
          </select>
        </div>

        <p v-if="errorMessage" class="form-error" role="alert">
          {{ errorMessage }}
        </p>
        <div class="form-actions">
          <button
            v-if="editing && !editing.user_id"
            type="button"
            class="btn btn--danger form-actions__spacer"
            @click="removeParticipant(editing)"
          >
            Eliminar
          </button>
          <button type="button" class="btn btn--ghost" @click="modalOpen = false">
            Cancelar
          </button>
          <button type="submit" class="btn btn--primary" :disabled="!canSubmit || saving">
            <template v-if="saving">
              {{ editing ? 'Guardando…' : 'Registrando…' }}
            </template>
            <template v-else>
              {{ editing ? 'Guardar cambios' : 'Registrar' }}
            </template>
          </button>
        </div>
      </form>
    </AppModal>
  </main>
</template>
