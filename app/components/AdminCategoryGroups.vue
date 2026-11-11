<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Group = Pick<Tables<'category_groups'>, 'id' | 'position' | 'name'>
type Member = Pick<Tables<'category_group_members'>, 'id' | 'group_id' | 'participant_id'>
type Contestant = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name' | 'avatar_url'>

/** Index into the two groups: 0 = A, 1 = B */
type Slot = 0 | 1

const props = defineProps<{
  category: { id: string, title: string }
}>()

const supabase = useSupabaseClient()
const { listGroupPhotoFiles, removeFiles } = useParticipantFiles()

const open = ref(false)
const loading = ref(false)
const saving = ref(false)
const error = ref('')

// What is stored in the database
const groups = ref<Group[]>([])
const members = ref<Member[]>([])
const contestants = ref<Contestant[]>([])

// The draft being edited: nothing is stored until "Guardar"
const names = reactive<[string, string]>(['', ''])
const assignment = reactive<Record<string, Slot>>({})
const toAdd = reactive<[string, string]>(['', ''])

const contestantName = (contestant: Contestant): string => contestant.drag_name ?? contestant.name
const SLOT_LABELS = ['A', 'B'] as const
const SLOTS: Slot[] = [0, 1]

const membersOf = (slot: Slot): { id: string, name: string, avatar: string | null }[] =>
  contestants.value
    .filter(contestant => assignment[contestant.id] === slot)
    .map(contestant => ({ id: contestant.id, name: contestantName(contestant), avatar: contestant.avatar_url }))

const unassigned = computed(() => contestants.value.filter(contestant => assignment[contestant.id] === undefined))

const storedSlot = (member: Member): Slot | undefined => {
  const position = groups.value.find(group => group.id === member.group_id)?.position
  return position === 1 ? 0 : position === 2 ? 1 : undefined
}

const hasGroups = computed(() => groups.value.length === 2)
const namesValid = computed(() => names.every(name => name.trim().length > 0))

const changed = computed(() => {
  if (!hasGroups.value) return true
  if (groups.value.some(group => group.name !== names[group.position - 1]!.trim())) return true
  const stored = new Map(members.value.map(member => [member.participant_id, storedSlot(member)]))
  const draft = Object.entries(assignment)
  return draft.length !== stored.size || draft.some(([participantId, slot]) => stored.get(participantId) !== slot)
})

async function load(): Promise<void> {
  loading.value = true
  error.value = ''
  try {
    const [groupRows, memberRows, contestantRows] = await Promise.all([
      supabase.from('category_groups').select('id, position, name').eq('category_id', props.category.id).order('position'),
      supabase.from('category_group_members').select('id, group_id, participant_id').eq('category_id', props.category.id),
      supabase.from('participants').select('id, name, drag_name, avatar_url').eq('role', 'concursante').order('name'),
    ])
    if (groupRows.error) throw groupRows.error
    if (memberRows.error) throw memberRows.error
    if (contestantRows.error) throw contestantRows.error

    groups.value = groupRows.data
    members.value = memberRows.data
    contestants.value = contestantRows.data

    names[0] = groupRows.data.find(group => group.position === 1)?.name ?? ''
    names[1] = groupRows.data.find(group => group.position === 2)?.name ?? ''
    for (const key of Object.keys(assignment)) delete assignment[key]
    for (const member of memberRows.data) {
      const slot = storedSlot(member)
      if (slot !== undefined) assignment[member.participant_id] = slot
    }
    toAdd[0] = ''
    toAdd[1] = ''
  }
  catch (caught) {
    error.value = toErrorMessage(caught)
  }
  finally {
    loading.value = false
  }
}

function openPanel(): void {
  open.value = true
  void load()
}

function addMember(slot: Slot): void {
  const participantId = toAdd[slot]
  if (!participantId) return
  assignment[participantId] = slot
  toAdd[slot] = ''
}

function removeMember(participantId: string): void {
  delete assignment[participantId]
}

async function save(): Promise<void> {
  if (saving.value || loading.value || !namesValid.value || !changed.value) return
  saving.value = true
  error.value = ''
  try {
    // 1. The groups: create both the first time, rename afterwards
    let current = groups.value
    if (!hasGroups.value) {
      const created = await supabase
        .from('category_groups')
        .insert([
          { category_id: props.category.id, position: 1, name: names[0].trim() },
          { category_id: props.category.id, position: 2, name: names[1].trim() },
        ])
        .select('id, position, name')
      if (created.error) throw created.error
      current = created.data
    }
    else {
      for (const group of groups.value) {
        const name = names[group.position - 1]!.trim()
        if (name === group.name) continue
        const renamed = await supabase.from('category_groups').update({ name }).eq('id', group.id)
        if (renamed.error) throw renamed.error
      }
    }
    const groupIdOf = (slot: Slot): string => current.find(group => group.position === slot + 1)!.id

    // 2. The members: remove the ones that left or moved first (a queen is in one group only), then add
    const leaving = members.value.filter(member => assignment[member.participant_id] !== storedSlot(member))
    if (leaving.length) {
      const removed = await supabase.from('category_group_members').delete().in('id', leaving.map(member => member.id))
      if (removed.error) throw removed.error
    }

    const stored = new Map(members.value.map(member => [member.participant_id, storedSlot(member)]))
    const joining = Object.entries(assignment)
      .filter(([participantId, slot]) => stored.get(participantId) !== slot)
      .map(([participantId, slot]) => ({ category_id: props.category.id, group_id: groupIdOf(slot), participant_id: participantId }))
    if (joining.length) {
      const added = await supabase.from('category_group_members').insert(joining)
      if (added.error) throw added.error
    }

    open.value = false
  }
  catch (caught) {
    const message = toErrorMessage(caught)
    // Show what is really stored, so a partial save is not hidden
    await load()
    error.value = message
  }
  finally {
    saving.value = false
  }
}

async function deleteGroups(): Promise<void> {
  if (saving.value || !window.confirm('¿Eliminar los dos grupos? También se borrarán sus integrantes, fotos y votos.')) return
  saving.value = true
  error.value = ''
  try {
    // The photo rows cascade with the groups; list their files first so they can be removed from Storage
    const files = await listGroupPhotoFiles(props.category.id)
    const { error: deleteError } = await supabase.from('category_groups').delete().eq('category_id', props.category.id)
    if (deleteError) throw deleteError
    await removeFiles(files)
    open.value = false
  }
  catch (caught) {
    error.value = toErrorMessage(caught)
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <button type="button" class="btn btn--secondary" @click="openPanel">
    Editar grupos
  </button>

  <!-- Teleported: the panel must not live inside the category <form> -->
  <Teleport to="body">
    <AppDrawer :open="open" :title="category.title" @close="open = false">
      <p v-if="loading" class="hint" role="status">
        Cargando…
      </p>

      <template v-else>
        <p v-if="!hasGroups" class="hint">
          Las reinas compiten en dos grupos. Ponles nombre y asigna a las integrantes.
        </p>

        <fieldset v-for="slot in SLOTS" :key="slot" class="group">
          <legend class="field__label">
            Grupo {{ SLOT_LABELS[slot] }}
          </legend>

          <input
            v-model="names[slot]"
            class="field__input"
            type="text"
            maxlength="60"
            required
            placeholder="Nombre del grupo"
            :aria-label="`Nombre del grupo ${SLOT_LABELS[slot]}`"
          >

          <p v-if="!membersOf(slot).length" class="hint">
            Aún no hay integrantes.
          </p>
          <ul v-else class="group__members">
            <li v-for="member in membersOf(slot)" :key="member.id" class="group__member">
              <span class="avatar group__avatar">
                <img v-if="member.avatar" :src="member.avatar" alt="" class="avatar__img">
                <span v-else class="avatar__initial" aria-hidden="true">{{ member.name.charAt(0).toUpperCase() }}</span>
              </span>
              <span class="group__name">{{ member.name }}</span>
              <button
                type="button"
                class="btn btn--ghost btn--danger group__remove"
                :aria-label="`Quitar a ${member.name} del grupo ${SLOT_LABELS[slot]}`"
                :title="`Quitar a ${member.name}`"
                @click="removeMember(member.id)"
              >
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v6M14 11v6" />
                </svg>
              </button>
            </li>
          </ul>

          <div class="group__add">
            <select v-model="toAdd[slot]" class="field__input" :aria-label="`Añadir reina al grupo ${SLOT_LABELS[slot]}`" :disabled="!unassigned.length">
              <option value="">
                {{ unassigned.length ? 'Añadir reina…' : 'No quedan reinas sin grupo' }}
              </option>
              <option v-for="contestant in unassigned" :key="contestant.id" :value="contestant.id">
                {{ contestantName(contestant) }}
              </option>
            </select>
            <button type="button" class="btn btn--secondary" :disabled="!toAdd[slot]" @click="addMember(slot)">
              Añadir
            </button>
          </div>
        </fieldset>

        <p v-if="error" class="form-error" role="alert">
          {{ error }}
        </p>
      </template>

      <template #footer>
        <button v-if="hasGroups" type="button" class="btn btn--ghost group__delete" :disabled="saving" @click="deleteGroups">
          Eliminar grupos
        </button>
        <button type="button" class="btn btn--ghost" :disabled="saving" @click="open = false">
          Cancelar
        </button>
        <button type="button" class="btn btn--primary" :disabled="loading || saving || !namesValid || !changed" @click="save">
          {{ saving ? 'Guardando…' : 'Guardar' }}
        </button>
      </template>
    </AppDrawer>
  </Teleport>
</template>

<style scoped lang="scss">
.group {
  display: grid;
  gap: var(--space-3);
  padding: var(--space-3);
  margin: 0;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.group__members {
  display: grid;
  gap: var(--space-1);
  padding: 0;
  margin: 0;
  list-style: none;
}

.group__member {
  display: flex;
  gap: var(--space-3);
  align-items: center;
}

.group__avatar .avatar__initial {
  font-size: 1rem;
}

.group__name {
  flex: 1;
  min-width: 0;
  overflow-wrap: anywhere;
}

.group__remove {
  padding: var(--space-2);
}

.group__add {
  display: flex;
  gap: var(--space-2);
  align-items: center;

  select {
    flex: 1;
    min-width: 0;
  }

  .btn {
    flex-shrink: 0;
  }
}

.group__delete {
  margin-right: auto;
}
</style>
