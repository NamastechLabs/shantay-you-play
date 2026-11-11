<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Group = Pick<Tables<'category_groups'>, 'id' | 'position' | 'name'>
type Member = Pick<Tables<'category_group_members'>, 'group_id' | 'participant_id'>

interface QueenLook {
  id: string
  participant_id: string
  image_url: string
  participant: Pick<Tables<'participants'>, 'name' | 'drag_name'>
}

/** Postgres insufficient_privilege / PostgREST "no rows": RLS rejected the vote (voting closed) */
const RLS_VIOLATION = '42501'
const NO_ROWS = 'PGRST116'

const props = defineProps<{
  category: Pick<Tables<'categories'>, 'id' | 'title'>
  showTitle: boolean
}>()

const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()

const isJury = computed(() => participant.value?.role === 'jurado')

const { data, error: loadError } = await useAsyncData(`group-vote-${props.category.id}`, async () => {
  const participantId = participant.value?.id
  if (!participantId) throw new Error('No has iniciado sesión')

  const [groups, members, looks, groupVote, queenVote] = await Promise.all([
    supabase.from('category_groups').select('id, position, name').eq('category_id', props.category.id).order('position'),
    supabase.from('category_group_members').select('group_id, participant_id').eq('category_id', props.category.id),
    supabase
      .from('looks')
      .select('id, participant_id, image_url, participant:participants!looks_participant_id_fkey(name, drag_name)')
      .eq('category_id', props.category.id)
      .order('created_at', { ascending: true }),
    supabase.from('category_group_votes').select('id, group_id').eq('category_id', props.category.id).eq('voter_id', participantId).maybeSingle(),
    supabase.from('category_queen_votes').select('id, queen_id').eq('category_id', props.category.id).eq('voter_id', participantId).maybeSingle(),
  ])
  if (groups.error) throw groups.error
  if (members.error) throw members.error
  if (looks.error) throw looks.error
  if (groupVote.error) throw groupVote.error
  if (queenVote.error) throw queenVote.error

  return {
    groups: groups.data as Group[],
    members: members.data as Member[],
    looks: looks.data as QueenLook[],
    groupVote: groupVote.data,
    queenVote: queenVote.data,
  }
})

const groups = computed(() => data.value?.groups ?? [])
const ownGroupId = computed(() => data.value?.members.find(member => member.participant_id === participant.value?.id)?.group_id ?? null)
const queenName = (look: QueenLook): string => look.participant.drag_name ?? look.participant.name

// --- Jury: vote for a group -----------------------------------------------------
const groupVoteId = ref<string | null>(data.value?.groupVote?.id ?? null)
const pickedGroupId = ref<string | null>(data.value?.groupVote?.group_id ?? null)

// --- Contestant: Top 1 of the rival group ----------------------------------------
const queenVoteId = ref<string | null>(data.value?.queenVote?.id ?? null)
const pickedQueenId = ref<string | null>(data.value?.queenVote?.queen_id ?? null)

const rivalQueens = computed(() => {
  const rivalIds = new Set(
    (data.value?.members ?? [])
      .filter(member => member.group_id !== ownGroupId.value)
      .map(member => member.participant_id),
  )
  return (data.value?.looks ?? []).filter(look => rivalIds.has(look.participant_id))
})

const saving = ref(false)
const saved = ref(false)
const saveError = ref('')

async function save(action: () => PromiseLike<{ data: { id: string } | null, error: { code?: string } | null }>, onSaved: (id: string) => void): Promise<void> {
  saving.value = true
  saved.value = false
  saveError.value = ''
  const { data: row, error } = await action()
  saving.value = false

  if (error) {
    saveError.value = error.code === RLS_VIOLATION || error.code === NO_ROWS
      ? 'No se pudo guardar: la votación ya no está abierta.'
      : toErrorMessage(error)
    return
  }
  if (row) onSaved(row.id)
  saved.value = true
}

const saveGroupVote = () => {
  const groupId = pickedGroupId.value
  if (!groupId || !participant.value) return Promise.resolve()
  return save(
    () => groupVoteId.value
      ? supabase.from('category_group_votes').update({ group_id: groupId }).eq('id', groupVoteId.value).select('id').single()
      : supabase.from('category_group_votes').insert({ category_id: props.category.id, voter_id: participant.value!.id, group_id: groupId }).select('id').single(),
    (id) => { groupVoteId.value = id },
  )
}

const saveQueenVote = () => {
  const queenId = pickedQueenId.value
  if (!queenId || !participant.value) return Promise.resolve()
  return save(
    () => queenVoteId.value
      ? supabase.from('category_queen_votes').update({ queen_id: queenId }).eq('id', queenVoteId.value).select('id').single()
      : supabase.from('category_queen_votes').insert({ category_id: props.category.id, voter_id: participant.value!.id, queen_id: queenId }).select('id').single(),
    (id) => { queenVoteId.value = id },
  )
}
</script>

<template>
  <section class="group-vote" :aria-labelledby="`group-vote-${category.id}`">
    <header class="group-vote__header">
      <span class="badge">Categoría grupal</span>
      <h2 :id="`group-vote-${category.id}`">
        {{ showTitle ? category.title : 'Votación por grupos' }}
      </h2>
    </header>

    <p v-if="loadError" class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>

    <p v-else-if="groups.length < 2" class="empty">
      Los grupos de esta categoría aún no están listos.
    </p>

    <template v-else>
      <CategoryGroupPhotos :category-id="category.id" :level="3" />

      <!-- Jury: the winning group -->
      <form v-if="isJury" class="group-vote__block" @submit.prevent="saveGroupVote">
        <p class="lead">
          ¿Qué grupo gana esta categoría? Solo vota el jurado. Si hay empate, ganan los dos grupos.
        </p>
        <div class="group-vote__choices" role="radiogroup" :aria-label="`Grupo ganador de ${category.title}`">
          <button
            v-for="group in groups"
            :key="group.id"
            type="button"
            class="btn"
            :class="pickedGroupId === group.id ? 'btn--primary' : 'btn--secondary'"
            role="radio"
            :aria-checked="pickedGroupId === group.id"
            @click="pickedGroupId = group.id; saved = false"
          >
            {{ group.name }}
          </button>
        </div>
        <div class="group-vote__actions">
          <p v-if="saveError" class="form-error" role="alert">
            {{ saveError }}
          </p>
          <p v-else-if="saved" class="group-vote__saved" role="status">
            ¡Voto guardado!
          </p>
          <button type="submit" class="btn btn--primary" :disabled="!pickedGroupId || saving">
            {{ saving ? 'Guardando…' : groupVoteId ? 'Actualizar mi voto' : 'Enviar mi voto' }}
          </button>
        </div>
      </form>

      <!-- Contestant: Top 1 of the rival group -->
      <form v-else-if="ownGroupId" class="group-vote__block" @submit.prevent="saveQueenVote">
        <p class="lead">
          Eliges tu Top 1 entre las reinas del grupo rival. Solo cuenta un voto por categoría.
        </p>
        <p v-if="!rivalQueens.length" class="empty">
          El grupo rival aún no tiene looks.
        </p>
        <ul v-else class="gallery">
          <li v-for="look in rivalQueens" :key="look.id">
            <button
              type="button"
              class="look-card"
              :class="{ 'look-card--picked': pickedQueenId === look.participant_id }"
              :aria-pressed="pickedQueenId === look.participant_id"
              @click="pickedQueenId = look.participant_id; saved = false"
            >
              <span v-if="pickedQueenId === look.participant_id" class="look-card__rank">1</span>
              <img class="group-vote__photo" :src="look.image_url" :alt="`Look de ${queenName(look)}`" loading="lazy">
              <span class="look-card__body">
                <span class="look-card__name">{{ queenName(look) }}</span>
              </span>
            </button>
          </li>
        </ul>
        <div class="group-vote__actions">
          <p v-if="saveError" class="form-error" role="alert">
            {{ saveError }}
          </p>
          <p v-else-if="saved" class="group-vote__saved" role="status">
            ¡Voto guardado!
          </p>
          <button type="submit" class="btn btn--primary" :disabled="!pickedQueenId || saving">
            {{ saving ? 'Guardando…' : queenVoteId ? 'Actualizar mi voto' : 'Enviar mi voto' }}
          </button>
        </div>
      </form>

      <p v-else class="empty">
        Esta categoría la votan el jurado y las reinas de los dos grupos.
      </p>
    </template>
  </section>
</template>

<style scoped lang="scss">
.group-vote {
  display: grid;
  gap: var(--space-3);
}

.group-vote__header {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: center;
}

.group-vote__block {
  display: grid;
  gap: var(--space-3);
}

.group-vote__choices,
.group-vote__actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: center;
}

.group-vote__saved {
  color: var(--color-success);
}

.group-vote__photo {
  width: 100%;
  aspect-ratio: 3 / 4;
  object-fit: cover;
}
</style>
