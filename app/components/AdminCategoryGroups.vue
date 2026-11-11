<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Group = Pick<Tables<'category_groups'>, 'id' | 'position' | 'name'>
type Member = Pick<Tables<'category_group_members'>, 'id' | 'group_id' | 'participant_id'>
type Contestant = Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>

const props = defineProps<{ categoryId: string }>()

const supabase = useSupabaseClient()

const { data, error: loadError, refresh } = await useAsyncData(`category-groups-${props.categoryId}`, async () => {
  const [groups, members, contestants] = await Promise.all([
    supabase.from('category_groups').select('id, position, name').eq('category_id', props.categoryId).order('position'),
    supabase.from('category_group_members').select('id, group_id, participant_id').eq('category_id', props.categoryId),
    supabase.from('participants').select('id, name, drag_name').eq('role', 'concursante').order('name'),
  ])
  if (groups.error) throw groups.error
  if (members.error) throw members.error
  if (contestants.error) throw contestants.error
  return { groups: groups.data as Group[], members: members.data as Member[], contestants: contestants.data as Contestant[] }
})

const groups = computed(() => data.value?.groups ?? [])
const contestants = computed(() => data.value?.contestants ?? [])
const contestantName = (contestant: Contestant): string => contestant.drag_name ?? contestant.name

const membersOf = (group: Group): (Member & { name: string })[] =>
  (data.value?.members ?? [])
    .filter(member => member.group_id === group.id)
    .map(member => ({
      ...member,
      name: contestantName(contestants.value.find(contestant => contestant.id === member.participant_id) ?? { id: '', name: '—', drag_name: null }),
    }))

const unassigned = computed(() => {
  const assigned = new Set((data.value?.members ?? []).map(member => member.participant_id))
  return contestants.value.filter(contestant => !assigned.has(contestant.id))
})

const busy = ref(false)
const error = ref('')

async function run(action: () => PromiseLike<{ error: unknown }>): Promise<void> {
  if (busy.value) return
  busy.value = true
  error.value = ''
  try {
    const { error: actionError } = await action()
    if (actionError) throw actionError
    await refresh()
  }
  catch (caught) {
    error.value = toErrorMessage(caught)
  }
  finally {
    busy.value = false
  }
}

// --- Create the two groups -----------------------------------------------------
const names = reactive(['', ''])

const createGroups = () => run(() => supabase.from('category_groups').insert([
  { category_id: props.categoryId, position: 1, name: names[0]!.trim() },
  { category_id: props.categoryId, position: 2, name: names[1]!.trim() },
]))

// --- Rename / delete -------------------------------------------------------------
const renames = reactive<Record<string, string>>({})
const nameOf = (group: Group): string => renames[group.id] ?? group.name

const renameGroup = (group: Group) =>
  run(() => supabase.from('category_groups').update({ name: nameOf(group).trim() }).eq('id', group.id))

const deleteGroups = async (): Promise<void> => {
  if (!window.confirm('¿Eliminar los dos grupos? También se borrarán sus integrantes y votos.')) return
  await run(() => supabase.from('category_groups').delete().eq('category_id', props.categoryId))
}

// --- Members ---------------------------------------------------------------------
const toAdd = reactive<Record<string, string>>({})

async function addMember(group: Group): Promise<void> {
  const participantId = toAdd[group.id]
  if (!participantId) return
  await run(() => supabase.from('category_group_members').insert({
    category_id: props.categoryId,
    group_id: group.id,
    participant_id: participantId,
  }))
  toAdd[group.id] = ''
}

const removeMember = (member: Member) =>
  run(() => supabase.from('category_group_members').delete().eq('id', member.id))
</script>

<template>
  <section class="card groups" :aria-labelledby="`groups-title-${categoryId}`">
    <h3 :id="`groups-title-${categoryId}`" class="groups__title">
      Grupos
    </h3>

    <p v-if="loadError" class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>

    <form v-else-if="!groups.length" class="form" @submit.prevent="createGroups">
      <p class="hint">
        Las reinas compiten en dos grupos. Ponles nombre para empezar a asignar integrantes.
      </p>
      <div class="field">
        <label :for="`group-name-1-${categoryId}`" class="field__label">Nombre del grupo A</label>
        <input :id="`group-name-1-${categoryId}`" v-model="names[0]" class="field__input" type="text" maxlength="60" required>
      </div>
      <div class="field">
        <label :for="`group-name-2-${categoryId}`" class="field__label">Nombre del grupo B</label>
        <input :id="`group-name-2-${categoryId}`" v-model="names[1]" class="field__input" type="text" maxlength="60" required>
      </div>
      <p v-if="error" class="form-error" role="alert">
        {{ error }}
      </p>
      <div class="form-actions">
        <button type="submit" class="btn btn--primary" :disabled="busy || !names[0]!.trim() || !names[1]!.trim()">
          Crear los grupos
        </button>
      </div>
    </form>

    <template v-else>
      <div class="groups__grid">
        <div v-for="group in groups" :key="group.id" class="groups__group">
          <form class="groups__rename" @submit.prevent="renameGroup(group)">
            <label :for="`group-rename-${group.id}`" class="field__label">Grupo {{ group.position === 1 ? 'A' : 'B' }}</label>
            <input :id="`group-rename-${group.id}`" v-model="renames[group.id]" class="field__input" type="text" maxlength="60" :placeholder="group.name">
            <button type="submit" class="btn btn--ghost" :disabled="busy || nameOf(group).trim() === group.name || !nameOf(group).trim()">
              Renombrar
            </button>
          </form>

          <p v-if="!membersOf(group).length" class="hint">
            Aún no hay integrantes.
          </p>
          <ul v-else class="groups__members">
            <li v-for="member in membersOf(group)" :key="member.id" class="groups__member">
              <span>{{ member.name }}</span>
              <button type="button" class="btn btn--ghost" :disabled="busy" :aria-label="`Quitar a ${member.name} del grupo`" @click="removeMember(member)">
                Quitar
              </button>
            </li>
          </ul>

          <form class="groups__add" @submit.prevent="addMember(group)">
            <label :for="`group-add-${group.id}`" class="field__label">Añadir reina</label>
            <select :id="`group-add-${group.id}`" v-model="toAdd[group.id]" class="field__input" :disabled="!unassigned.length">
              <option value="">
                {{ unassigned.length ? 'Elige una reina' : 'No quedan reinas sin grupo' }}
              </option>
              <option v-for="contestant in unassigned" :key="contestant.id" :value="contestant.id">
                {{ contestantName(contestant) }}
              </option>
            </select>
            <button type="submit" class="btn btn--secondary" :disabled="busy || !toAdd[group.id]">
              Añadir
            </button>
          </form>
        </div>
      </div>

      <p v-if="error" class="form-error" role="alert">
        {{ error }}
      </p>
      <div class="form-actions">
        <button type="button" class="btn btn--ghost" :disabled="busy" @click="deleteGroups">
          Eliminar los grupos
        </button>
      </div>
    </template>
  </section>
</template>

<style scoped lang="scss">
.groups {
  display: grid;
  gap: var(--space-3);
}

.groups__title {
  font-size: 1.125rem;
  color: var(--color-title);
}

.groups__grid {
  display: grid;
  gap: var(--space-4);

  @media (min-width: 48rem) {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

.groups__group,
.groups__rename,
.groups__add {
  display: grid;
  gap: var(--space-2);
  align-content: start;
}

.groups__members {
  display: grid;
  gap: var(--space-1);
  padding: 0;
  margin: 0;
  list-style: none;
}

.groups__member {
  display: flex;
  gap: var(--space-2);
  align-items: center;
  justify-content: space-between;
}
</style>
