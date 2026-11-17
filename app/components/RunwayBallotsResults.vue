<script setup lang="ts">
import type { BallotPerson, RunwayBallot } from '~/composables/useRunwayBallots'

const props = defineProps<{
  runwayId: string
  weekNumber: number
}>()

const { loadBallots } = useRunwayBallots()

const open = ref(false)
const loading = ref(false)
const failed = ref<unknown>(null)
const ballots = ref<RunwayBallot[] | null>(null)

const modalTitle = computed(() => `Resultados · Semana ${props.weekNumber}`)
const PLACE_LABELS = ['Top 1', 'Top 2', 'Top 3']
const POINTS = [3, 2, 1]

// Cross table: a row per voter, a column per queen who got at least one vote, ordered by points
const queens = computed(() => {
  const totals = new Map<string, { person: BallotPerson, points: number }>()
  for (const ballot of ballots.value ?? []) {
    ballot.picks.forEach((pick, index) => {
      const entry = totals.get(pick.id) ?? { person: pick, points: 0 }
      entry.points += POINTS[index] ?? 0
      totals.set(pick.id, entry)
    })
  }
  return [...totals.values()].sort((a, b) => b.points - a.points || a.person.name.localeCompare(b.person.name, 'es'))
})

/** Place (1-3) the voter gave to the queen, or null */
function placeOf(ballot: RunwayBallot, queenId: string): number | null {
  const index = ballot.picks.findIndex(pick => pick.id === queenId)
  return index === -1 ? null : index + 1
}

// Ballots are read the first time the dialog opens, and again after an error
async function show(): Promise<void> {
  open.value = true
  if (ballots.value || loading.value) return
  loading.value = true
  failed.value = null
  try {
    ballots.value = await loadBallots(props.runwayId)
  }
  catch (error) {
    failed.value = error
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <button type="button" class="btn btn--primary" @click="show">
    Resultados
  </button>

  <AppModal wide :open="open" :title="modalTitle" @close="open = false">
    <p v-if="loading" class="hint">
      Cargando los votos…
    </p>
    <p v-else-if="failed" class="form-error" role="alert">
      {{ toErrorMessage(failed) }}
    </p>
    <p v-else-if="!ballots?.length" class="empty">
      Todavía no hay votos en esta pasarela.
    </p>
    <template v-else>
      <p class="hint">
        A quién votó cada persona. En la tabla, cada fila es quien votó, cada columna una reina y el número el puesto que le dio. Los votos de las invitadas especiales son anónimos.
      </p>
      <!-- Phones: a card per voter with her three picks -->
      <ul class="ballots-cards">
        <li v-for="ballot in ballots" :key="ballot.voter.id" class="ballots-cards__item">
          <div class="ballots-cards__voter">
            <span class="avatar">
              <img v-if="ballot.voter.avatar" :src="ballot.voter.avatar" alt="" class="avatar__img">
              <span v-else class="avatar__initial" aria-hidden="true">{{ ballot.voter.name.charAt(0).toUpperCase() }}</span>
            </span>
            <span class="ballots-cards__name">{{ ballot.voter.name }}</span>
          </div>
          <ol class="ballots-cards__picks">
            <li v-for="(pick, index) in ballot.picks" :key="pick.id" class="ballots-cards__pick">
              <span class="ballots-cards__place">{{ PLACE_LABELS[index] }}</span>
              <span class="avatar">
                <img v-if="pick.avatar" :src="pick.avatar" alt="" class="avatar__img">
                <span v-else class="avatar__initial" aria-hidden="true">{{ pick.name.charAt(0).toUpperCase() }}</span>
              </span>
              <span class="ballots-cards__name">{{ pick.name }}</span>
            </li>
          </ol>
        </li>
      </ul>

      <!-- Desktop: cross table -->
      <div class="table-card ballots" tabindex="0" role="region" aria-label="Tabla de votos">
        <table class="table ballots__table">
          <thead>
            <tr>
              <th scope="col">
                Vota
              </th>
              <th v-for="queen in queens" :key="queen.person.id" scope="col" class="ballots__cell">
                <span class="ballots__head">
                  <span class="avatar">
                    <img v-if="queen.person.avatar" :src="queen.person.avatar" alt="" class="avatar__img">
                    <span v-else class="avatar__initial" aria-hidden="true">{{ queen.person.name.charAt(0).toUpperCase() }}</span>
                  </span>
                  <span class="ballots__queen">{{ queen.person.name }}</span>
                </span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="ballot in ballots" :key="ballot.voter.id">
              <th scope="row" class="ballots__voter">
                <span class="ballots__head ballots__head--row">
                  <span class="avatar">
                    <img v-if="ballot.voter.avatar" :src="ballot.voter.avatar" alt="" class="avatar__img">
                    <span v-else class="avatar__initial" aria-hidden="true">{{ ballot.voter.name.charAt(0).toUpperCase() }}</span>
                  </span>
                  <span>{{ ballot.voter.name }}</span>
                </span>
              </th>
              <td v-for="queen in queens" :key="queen.person.id" class="ballots__cell">
                <span
                  v-if="placeOf(ballot, queen.person.id)"
                  class="ballots__place"
                  :class="`ballots__place--${placeOf(ballot, queen.person.id)}`"
                  :aria-label="PLACE_LABELS[placeOf(ballot, queen.person.id)! - 1]"
                >{{ placeOf(ballot, queen.person.id) }}</span>
                <span v-else class="ballots__none" aria-hidden="true">·</span>
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr>
              <th scope="row" class="ballots__voter">
                Puntos
              </th>
              <td v-for="queen in queens" :key="queen.person.id" class="ballots__cell ballots__total">
                {{ queen.points }}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>
    </template>
  </AppModal>
</template>

<style scoped>
.ballots {
  display: none;
  margin-top: var(--space-3);
}

.ballots-cards {
  display: grid;
  gap: var(--space-3);
  padding: 0;
  margin: var(--space-3) 0 0;
  list-style: none;
}

.ballots-cards__item {
  display: grid;
  gap: var(--space-3);
  padding: var(--space-3) var(--space-4);
  background-color: var(--color-surface-raised);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.ballots-cards__voter,
.ballots-cards__pick {
  display: flex;
  gap: var(--space-3);
  align-items: center;
}

.ballots-cards__voter {
  font-weight: 700;
}

.ballots-cards__picks {
  display: grid;
  gap: var(--space-2);
  padding: 0;
  margin: 0;
  list-style: none;
}

.ballots-cards__place {
  min-width: 3.5rem;
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.ballots-cards__name {
  min-width: 0;
  overflow-wrap: anywhere;
}

.ballots-cards .avatar {
  width: 2rem;
  height: 2rem;
}

.ballots-cards .avatar__initial {
  font-size: 0.9rem;
}

/* Wide screens swap the cards for the cross table */
@media (min-width: 48rem) {
  .ballots-cards {
    display: none;
  }

  .ballots {
    display: block;
  }
}

.ballots__table {
  width: max-content;
  min-width: 100%;
}

.ballots__cell {
  text-align: center;
}

.ballots__head {
  display: inline-flex;
  flex-direction: column;
  gap: var(--space-2);
  align-items: center;
}

.ballots__head--row {
  flex-direction: row;
  gap: var(--space-3);
}

.ballots__queen {
  max-width: 6rem;
  overflow-wrap: anywhere;
  letter-spacing: normal;
  text-transform: none;
}

/* The voter column stays in view while the table scrolls sideways */
.ballots__voter {
  position: sticky;
  left: 0;
  z-index: 1;
  min-width: 9rem;
  text-align: left;
  background-color: var(--color-surface-raised);
}

.ballots__voter .ballots__head {
  text-transform: none;
  letter-spacing: normal;
}

.ballots .avatar {
  width: 2rem;
  height: 2rem;
}

.ballots .avatar__initial {
  font-size: 0.9rem;
}

.ballots__place {
  display: inline-grid;
  place-items: center;
  width: 1.75rem;
  height: 1.75rem;
  font-weight: 700;
  color: var(--color-text-muted);
  background-color: var(--color-surface-raised);
  border: 1px solid var(--color-border);
  border-radius: 50%;
}

.ballots__place--1 {
  color: var(--color-on-primary);
  background-color: var(--color-primary);
  border-color: var(--color-primary);
}

.ballots__none {
  color: var(--color-text-muted);
}

.ballots__total {
  font-weight: 700;
}

tfoot .ballots__cell,
tfoot .ballots__voter {
  border-top: 2px solid var(--color-border);
}
</style>
