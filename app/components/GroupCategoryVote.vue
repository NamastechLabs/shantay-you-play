<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Group = Pick<Tables<'category_groups'>, 'id' | 'position' | 'name'>

interface Member {
  group_id: string
  participant_id: string
  participant: Pick<Tables<'participants'>, 'name' | 'drag_name'>
}

interface MemberLook {
  id: string
  participant_id: string
  image_url: string
}

/** A contestant that can be ranked, with her looks of the category */
interface Candidate {
  id: string
  name: string
  looks: MemberLook[]
}

/** Postgres insufficient_privilege / PostgREST "no rows": RLS or the ballot function rejected the vote (voting closed) */
const RLS_VIOLATION = '42501'
const NO_ROWS = 'PGRST116'
/** invalid_parameter_value: the ballot is not complete or not valid */
const INVALID_BALLOT = '22023'

/** Voting steps of the page: only the band and ranking steps are shown here; the Top 3 step belongs to the page */
type GroupVoteStep = 'band' | 'ranking' | 'top3'

const props = defineProps<{
  category: Pick<Tables<'categories'>, 'id' | 'title'>
  showTitle: boolean
  step: GroupVoteStep
}>()

/** Tells the page which steps apply to this voter and which are done, to build the stepper */
const emit = defineEmits<{
  progress: [state: { eligible: boolean, band: boolean, ranking: boolean, rankingIds: string[] }]
}>()

const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()

const isJury = computed(() => participant.value?.role === 'jurado')
/** Contestants rank the rival band (cross vote); judges rank everyone (jury vote) */
const stage = computed(() => isJury.value ? 'jury' : 'cross')

const { data, error: loadError } = await useAsyncData(`group-vote-${props.category.id}`, async () => {
  const participantId = participant.value?.id
  if (!participantId) throw new Error('No has iniciado sesión')

  const [groups, members, looks, groupVote, ranking] = await Promise.all([
    supabase.from('category_groups').select('id, position, name').eq('category_id', props.category.id).order('position'),
    supabase
      .from('category_group_members')
      .select('group_id, participant_id, participant:participants(name, drag_name)')
      .eq('category_id', props.category.id),
    supabase
      .from('looks')
      .select('id, participant_id, image_url')
      .eq('category_id', props.category.id)
      .order('created_at', { ascending: true }),
    supabase.from('category_group_votes').select('id, group_id').eq('category_id', props.category.id).eq('voter_id', participantId).maybeSingle(),
    supabase
      .from('category_ranking_votes')
      .select('participant_id, rank')
      .eq('category_id', props.category.id)
      .eq('voter_id', participantId)
      .eq('stage', stage.value)
      .order('rank'),
  ])
  if (groups.error) throw groups.error
  if (members.error) throw members.error
  if (looks.error) throw looks.error
  if (groupVote.error) throw groupVote.error
  if (ranking.error) throw ranking.error

  return {
    groups: groups.data as Group[],
    members: members.data as unknown as Member[],
    looks: looks.data as MemberLook[],
    groupVote: groupVote.data,
    ranking: ranking.data,
  }
})

const groups = computed(() => data.value?.groups ?? [])
const ownGroupId = computed(() => data.value?.members.find(member => member.participant_id === participant.value?.id)?.group_id ?? null)

// --- Jury: vote for the winning band ---------------------------------------------
const groupVoteId = ref<string | null>(data.value?.groupVote?.id ?? null)
const pickedGroupId = ref<string | null>(data.value?.groupVote?.group_id ?? null)

// --- Ranking ballot: cross (contestants) or jury (judges) --------------------------
/** Contestants this voter has to rank: the rival band, or everyone for the jury */
const candidates = computed<Candidate[]>(() => (data.value?.members ?? [])
  .filter(member => isJury.value || member.group_id !== ownGroupId.value)
  .map(member => ({
    id: member.participant_id,
    name: member.participant.drag_name ?? member.participant.name,
    looks: (data.value?.looks ?? []).filter(look => look.participant_id === member.participant_id),
  })))

/** Picked contestant ids in rank order (index 0 = favourite) */
const picks = ref<string[]>((data.value?.ranking ?? []).map(row => row.participant_id))
const hasBallot = ref(picks.value.length > 0)
/** The saved ranking, in order: the jury's Top 3 step is pre-filled from it */
const savedRankingIds = ref<string[]>([...picks.value])

const isComplete = computed(() => candidates.value.length > 0 && picks.value.length === candidates.value.length)
const rankOf = (candidate: Candidate): number | null => {
  const index = picks.value.indexOf(candidate.id)
  return index === -1 ? null : index + 1
}
const candidateName = (id: string): string => candidates.value.find(candidate => candidate.id === id)?.name ?? '—'

const saving = ref(false)
const saved = ref(false)
const saveError = ref('')

/** Tapping adds the contestant to the next free rank; tapping again removes her and moves the rest up. */
function togglePick(candidate: Candidate): void {
  saved.value = false
  saveError.value = ''
  picks.value = picks.value.includes(candidate.id)
    ? picks.value.filter(id => id !== candidate.id)
    : [...picks.value, candidate.id]
}

async function saveRanking(): Promise<void> {
  if (!isComplete.value) return
  saving.value = true
  saved.value = false
  saveError.value = ''

  const { error } = await supabase.rpc('submit_ranking_ballot', {
    p_category_id: props.category.id,
    p_stage: stage.value,
    p_participant_ids: picks.value,
  })
  saving.value = false

  if (error) {
    saveError.value = error.code === RLS_VIOLATION
      ? 'No se pudo guardar: la votación ya no está abierta o no te corresponde votar aquí.'
      : error.code === INVALID_BALLOT
        ? 'Tu voto debe ordenar a todas las concursantes, una sola vez cada una.'
        : toErrorMessage(error)
    return
  }
  hasBallot.value = true
  savedRankingIds.value = [...picks.value]
  saved.value = true
}

async function saveGroupVote(): Promise<void> {
  const groupId = pickedGroupId.value
  if (!groupId || !participant.value) return
  saving.value = true
  saved.value = false
  saveError.value = ''

  const { data: row, error } = await (groupVoteId.value
    ? supabase.from('category_group_votes').update({ group_id: groupId }).eq('id', groupVoteId.value).select('id').single()
    : supabase.from('category_group_votes').insert({ category_id: props.category.id, voter_id: participant.value.id, group_id: groupId }).select('id').single())
  saving.value = false

  if (error) {
    saveError.value = error.code === RLS_VIOLATION || error.code === NO_ROWS
      ? 'No se pudo guardar: la votación ya no está abierta.'
      : toErrorMessage(error)
    return
  }
  groupVoteId.value = row.id
  saved.value = true
}

// A message belongs to the step where it happened
watch(() => props.step, () => {
  saved.value = false
  saveError.value = ''
})

watch(
  [ownGroupId, groupVoteId, hasBallot, savedRankingIds, groups],
  () => emit('progress', {
    eligible: groups.value.length >= 2 && (isJury.value || !!ownGroupId.value),
    band: !!groupVoteId.value,
    ranking: hasBallot.value,
    rankingIds: savedRankingIds.value,
  }),
  { immediate: true },
)
</script>

<template>
  <section v-show="step !== 'top3'" class="group-vote" :aria-labelledby="`group-vote-${category.id}`">
    <header class="group-vote__header">
      <span class="badge">Categoría grupal</span>
      <h2 :id="`group-vote-${category.id}`">
        {{ showTitle ? category.title : 'Votación por bandas' }}
      </h2>
      <NuxtLink :to="GROUP_VOTING_HELP_PATH" class="group-vote__help">
        {{ GROUP_VOTING_COPY.helpLink }}
      </NuxtLink>
    </header>

    <p v-if="loadError" class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>

    <p v-else-if="groups.length < 2" class="empty">
      Las bandas de esta categoría aún no están listas.
    </p>

    <template v-else>
      <CategoryGroupPhotos :category-id="category.id" :level="3" />

      <!-- Jury, step 1: the winning band -->
      <form v-if="isJury" v-show="step === 'band'" class="group-vote__block" @submit.prevent="saveGroupVote">
        <p class="lead">
          ¿Qué banda ha trabajado mejor? Solo vota el jurado. Si hay empate, las dos bandas reciben el regalo.
        </p>
        <div class="group-vote__choices" role="radiogroup" :aria-label="`Banda ganadora de ${category.title}`">
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
          <button type="submit" class="btn btn--primary" :disabled="!pickedGroupId || saving">
            {{ saving ? 'Guardando…' : groupVoteId ? 'Actualizar mi voto' : 'Enviar mi voto' }}
          </button>
        </div>
      </form>

      <!-- Ranking ballot: step 2 for the jury, step 1 for the contestants -->
      <form v-if="isJury || ownGroupId" v-show="step === 'ranking'" class="group-vote__block" @submit.prevent="saveRanking">
        <p class="lead">
          <template v-if="isJury">
            Ordena los looks de todas las concursantes, de mejor a peor. Toca en orden: la primera será tu favorita. Tócala otra vez para quitarla.
          </template>
          <template v-else>
            Ordena a todas las reinas de la banda rival, de mejor a peor, según sus looks. Toca en orden: la primera será tu favorita. Tócala otra vez para quitarla.
          </template>
          {{ hasBallot ? 'Puedes cambiar tu voto mientras la votación siga abierta.' : '' }}
        </p>

        <p v-if="!candidates.length" class="empty">
          {{ isJury ? 'Todavía no hay concursantes en las bandas.' : 'La banda rival aún no tiene integrantes.' }}
        </p>

        <template v-else>
          <ul class="gallery">
            <li v-for="candidate in candidates" :key="candidate.id">
              <button
                type="button"
                class="look-card"
                :class="{ 'look-card--picked': rankOf(candidate) }"
                :aria-pressed="rankOf(candidate) !== null"
                @click="togglePick(candidate)"
              >
                <span v-if="rankOf(candidate)" class="look-card__rank">{{ rankOf(candidate) }}</span>
                <span
                  v-if="candidate.looks.length"
                  class="group-vote__photos"
                  :style="{ gridTemplateColumns: `repeat(${candidate.looks.length}, minmax(0, 1fr))` }"
                >
                  <img
                    v-for="look in candidate.looks"
                    :key="look.id"
                    class="group-vote__photo"
                    :src="look.image_url"
                    :alt="`Look de ${candidate.name}`"
                    loading="lazy"
                  >
                </span>
                <span class="look-card__body">
                  <span class="look-card__name">{{ candidate.name }}</span>
                </span>
              </button>
            </li>
          </ul>

          <ol v-if="picks.length" class="group-vote__order" aria-label="Tu orden">
            <li v-for="id in picks" :key="id">
              {{ candidateName(id) }}
            </li>
          </ol>

          <div class="group-vote__actions">
            <p v-if="!isComplete" class="hint">
              Faltan por ordenar {{ candidates.length - picks.length }} de {{ candidates.length }}: el voto debe estar completo.
            </p>
            <button type="submit" class="btn btn--primary" :disabled="!isComplete || saving">
              {{ saving ? 'Guardando…' : hasBallot ? 'Actualizar mi voto' : 'Enviar mi voto' }}
            </button>
          </div>
        </template>
      </form>

      <p v-if="saveError" class="form-error" role="alert">
        {{ saveError }}
      </p>
      <p v-else-if="saved" class="group-vote__saved" role="status">
        ¡Voto guardado!
      </p>

      <p v-if="!isJury && !ownGroupId && step === 'ranking'" class="empty">
        Esta categoría la votan el jurado y las reinas de las dos bandas.
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

.group-vote__help {
  margin-left: auto;
  font-size: 0.875rem;
  color: var(--color-title);
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

.group-vote__photos {
  display: grid;
  gap: 2px;
}

.group-vote__photo {
  width: 100%;
  aspect-ratio: 3 / 4;
  object-fit: cover;
}

.group-vote__order {
  display: grid;
  gap: var(--space-1);
  padding-left: var(--space-5);
  list-style: decimal;
  color: var(--color-text-muted);
}
</style>
