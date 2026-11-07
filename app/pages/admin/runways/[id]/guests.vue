<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Guest = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name' | 'email' | 'user_id'>
interface Invitation {
  id: string
  created_at: string
  guest: Guest
}

/** Postgres unique_violation: the guest is already invited to this runway */
const UNIQUE_VIOLATION = '23505'

const supabase = useSupabaseClient()
const { runway } = useAdminRunway()

const { data, error: loadError, refresh } = await useAsyncData(`admin-runway-${runway.value.id}-guests`, async () => {
  const [invitations, guests] = await Promise.all([
    supabase
      .from('runway_guests')
      .select('id, created_at, guest:participants!runway_guests_participant_id_fkey(id, name, drag_name, email, user_id)')
      .eq('runway_id', runway.value.id)
      .order('created_at', { ascending: true }),
    supabase
      .from('participants')
      .select('id, name, drag_name, email, user_id')
      .eq('role', 'invitado')
      .order('name', { ascending: true }),
  ])
  if (invitations.error) throw invitations.error
  if (guests.error) throw guests.error

  return { invitations: invitations.data as Invitation[], guests: guests.data as Guest[] }
})

const guestName = (guest: Guest): string => guest.drag_name ?? guest.name

// Registered guests that are not invited to this runway yet
const invitable = computed(() => {
  const invited = new Set(data.value?.invitations.map(invitation => invitation.guest.id))
  return (data.value?.guests ?? []).filter(guest => !invited.has(guest.id))
})

const selectedId = ref('')
const saving = ref(false)
const errorMessage = ref<string | null>(null)

async function invite(): Promise<void> {
  if (!selectedId.value || saving.value) return

  saving.value = true
  errorMessage.value = null
  try {
    const { error } = await supabase
      .from('runway_guests')
      .insert({ runway_id: runway.value.id, participant_id: selectedId.value })
    if (error) {
      if (error.code === UNIQUE_VIOLATION) throw new Error('Esa persona ya está invitada a esta semana')
      throw error
    }
    selectedId.value = ''
    await refresh()
  }
  catch (error) {
    errorMessage.value = toErrorMessage(error)
  }
  finally {
    saving.value = false
  }
}

async function revoke(invitation: Invitation): Promise<void> {
  if (!window.confirm(`¿Quitar la invitación de ${guestName(invitation.guest)}? Perderá el acceso a esta semana.`)) return

  errorMessage.value = null
  try {
    const { error } = await supabase.from('runway_guests').delete().eq('id', invitation.id)
    if (error) throw error
    await refresh()
  }
  catch (error) {
    errorMessage.value = toErrorMessage(error)
  }
}
</script>

<template>
  <section class="section" aria-labelledby="guests-title">
    <div class="section-header">
      <h2 id="guests-title">
        Invitados especiales ({{ data?.invitations.length ?? 0 }})
      </h2>
    </div>

    <p class="hint">
      Los invitados especiales inician sesión con Google o Microsoft como el resto. Desde que los invitas hasta el final del día de la pasarela
      ({{ formatRunwayDate(runway.runway_date) }}) pueden subir su look de jurado y votar en todas las categorías de esta semana.
      Solo ven las semanas a las que están invitados, y su voto es anónimo.
    </p>

    <p v-if="loadError" class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>

    <form v-if="invitable.length" class="form" @submit.prevent="invite">
      <div class="field">
        <label for="guest-select" class="field__label">Invitar a</label>
        <select id="guest-select" v-model="selectedId" class="field__input" required>
          <option value="" disabled>
            Selecciona…
          </option>
          <option v-for="guest in invitable" :key="guest.id" :value="guest.id">
            {{ guestName(guest) }} ({{ guest.email }})
          </option>
        </select>
      </div>
      <div>
        <button type="submit" class="btn btn--primary" :disabled="!selectedId || saving">
          {{ saving ? 'Invitando…' : 'Invitar' }}
        </button>
      </div>
    </form>
    <p v-else-if="!loadError" class="hint">
      No hay más invitados registrados. Regístralos con el rol «Invitado especial» en
      <NuxtLink to="/admin/participants" class="link">Participantes</NuxtLink>.
    </p>

    <p v-if="errorMessage" class="form-error" role="alert">
      {{ errorMessage }}
    </p>

    <ul v-if="data?.invitations.length" class="row-list">
      <li v-for="invitation in data.invitations" :key="invitation.id" class="row">
        <div class="row__main">
          <strong class="row__title">{{ guestName(invitation.guest) }}</strong>
          <span class="hint">{{ invitation.guest.email }}</span>
        </div>
        <div class="row__aside">
          <span class="badge" :class="invitation.guest.user_id ? 'badge--approved' : 'badge--pending'">
            {{ invitation.guest.user_id ? 'Ya inició sesión' : 'Pendiente' }}
          </span>
          <button type="button" class="btn btn--ghost" @click="revoke(invitation)">
            Quitar
          </button>
        </div>
      </li>
    </ul>
    <p v-else-if="!loadError" class="empty">
      Nadie invitado a esta semana todavía.
    </p>
  </section>
</template>
