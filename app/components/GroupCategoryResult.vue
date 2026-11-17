<script setup lang="ts">
import type { Tables } from '~/types/database.types'

const props = defineProps<{
  category: Pick<Tables<'categories'>, 'id' | 'title'>
  showTitle: boolean
}>()

const supabase = useSupabaseClient()
const copy = GROUP_RESULT_COPY

// Both functions return nothing until the runway reaches 'reveal'
const { data, error } = await useAsyncData(`group-result-${props.category.id}`, async () => {
  const [groupResult, ranking, groups] = await Promise.all([
    supabase.rpc('category_group_result', { p_category_id: props.category.id }),
    supabase.rpc('category_ranking_result', { p_category_id: props.category.id }),
    supabase.from('category_groups').select('id, name').eq('category_id', props.category.id),
  ])
  if (groupResult.error) throw groupResult.error
  if (ranking.error) throw ranking.error
  if (groups.error) throw groups.error

  const ids = ranking.data.map(row => row.participant_id)
  const names = ids.length
    ? await supabase.from('participants').select('id, name, drag_name, avatar_url').in('id', ids)
    : { data: [], error: null }
  if (names.error) throw names.error

  const groupName = (groupId: string): string => groups.data.find(group => group.id === groupId)?.name ?? ''
  const queenName = (id: string): string => {
    const queen = names.data.find(candidate => candidate.id === id)
    return queen ? (queen.drag_name ?? queen.name) : '—'
  }
  const queenAvatar = (id: string): string | null => names.data.find(candidate => candidate.id === id)?.avatar_url ?? null

  return {
    winningGroups: groupResult.data.filter(row => row.is_winner).map(row => groupName(row.group_id)).filter(Boolean),
    // Order and shared positions come from the database (`position`)
    rows: ranking.data.map(row => ({ ...row, name: queenName(row.participant_id), avatar: queenAvatar(row.participant_id), band: groupName(row.group_id) })),
  }
})

const hasRanking = computed(() => !!data.value?.rows.some(row => row.cross_score > 0 || row.jury_score > 0 || row.top3_score > 0))

// The results live in a modal, opened from the button at the top of the page
const open = ref(false)
const modalTitle = computed(() => `Resultados${props.showTitle ? ` · ${props.category.title}` : ''}`)
</script>

<template>
  <div v-if="data && (data.winningGroups.length || data.rows.length)" class="group-result">
    <button type="button" class="btn btn--primary" @click="open = true">
      Ver resultados
    </button>

    <AppModal wide :open="open" :title="modalTitle" @close="open = false">
      <div class="group-result__content">
        <NuxtLink :to="GROUP_VOTING_HELP_PATH" class="group-result__help">
          {{ GROUP_VOTING_COPY.helpLink }}
        </NuxtLink>

        <dl v-if="data.winningGroups.length" class="group-result__list">
          <div class="group-result__item">
            <dt>{{ data.winningGroups.length > 1 ? copy.winningBands : copy.winningBand }}</dt>
            <dd>{{ data.winningGroups.join(' y ') }}</dd>
          </div>
        </dl>

        <template v-if="data.rows.length">
          <h3 class="group-result__subtitle">
            {{ copy.title }}
          </h3>
          <p v-if="!hasRanking" class="hint">
            {{ copy.empty }}
          </p>
          <!-- Phones: a card per queen with her scores -->
          <ul class="group-cards" :aria-label="copy.title">
            <li v-for="row in data.rows" :key="row.participant_id" class="group-cards__item" :class="{ 'group-result__first': row.position === 1 }">
              <div class="group-cards__head">
                <span class="group-result__position">{{ row.position }}.º</span>
                <span class="avatar">
                  <img v-if="row.avatar" :src="row.avatar" alt="" class="avatar__img">
                  <span v-else class="avatar__initial" aria-hidden="true">{{ row.name.charAt(0).toUpperCase() }}</span>
                </span>
                <span class="group-cards__who">
                  <span class="group-cards__name">{{ row.name }}</span>
                  <span class="group-result__band">{{ row.band }}</span>
                </span>
                <span class="group-cards__total">
                  <span class="group-cards__label">{{ copy.headers.total }}</span>
                  {{ formatScore(row.total) }}
                </span>
              </div>
              <dl class="group-cards__scores">
                <div>
                  <dt>
                    {{ copy.headers.bonus }}
                  </dt>
                  <dd>{{ row.band_bonus ? formatScore(row.band_bonus, 1) : '0' }}</dd>
                </div>
                <div>
                  <dt>{{ copy.headers.cross }}</dt>
                  <dd>{{ formatScore(row.cross_score) }}</dd>
                </div>
                <div>
                  <dt>{{ copy.headers.jury }}</dt>
                  <dd>{{ formatScore(row.jury_score) }}</dd>
                </div>
                <div>
                  <dt>{{ copy.headers.top3 }}</dt>
                  <dd>{{ formatScore(row.top3_score) }}</dd>
                </div>
              </dl>
            </li>
          </ul>

          <!-- Desktop: table -->
          <div class="group-result__table-wrap" tabindex="0" role="region" :aria-label="copy.title">
            <table class="group-result__table">
              <thead>
                <tr>
                  <th scope="col">
                    {{ copy.headers.position }}
                  </th>
                  <th scope="col">
                    {{ copy.headers.name }}
                  </th>
                  <th scope="col">
                    {{ copy.headers.bonus }}
                  </th>
                  <th scope="col">
                    {{ copy.headers.cross }}
                  </th>
                  <th scope="col">
                    {{ copy.headers.jury }}
                  </th>
                  <th scope="col">
                    {{ copy.headers.top3 }}
                  </th>
                  <th scope="col">
                    {{ copy.headers.total }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in data.rows" :key="row.participant_id" :class="{ 'group-result__first': row.position === 1 }">
                  <td class="group-result__position">
                    {{ row.position }}.º
                  </td>
                  <th scope="row">
                    <span class="group-result__queen">
                      <span class="avatar">
                        <img v-if="row.avatar" :src="row.avatar" alt="" class="avatar__img">
                        <span v-else class="avatar__initial" aria-hidden="true">{{ row.name.charAt(0).toUpperCase() }}</span>
                      </span>
                      <span>
                        {{ row.name }}
                        <span class="group-result__band">{{ row.band }}</span>
                      </span>
                    </span>
                  </th>
                  <td>{{ row.band_bonus ? formatScore(row.band_bonus, 1) : '0' }}</td>
                  <td>{{ formatScore(row.cross_score) }}</td>
                  <td>{{ formatScore(row.jury_score) }}</td>
                  <td>{{ formatScore(row.top3_score) }}</td>
                  <td class="group-result__total">
                    {{ formatScore(row.total) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
      </div>
    </AppModal>
  </div>
  <p v-else-if="error" class="form-error" role="alert">
    {{ toErrorMessage(error) }}
  </p>
</template>

<style scoped lang="scss">
// The button sits at the top left of the page, above the group photos
.group-result {
  display: flex;
  justify-content: flex-start;
}

.group-result__content {
  display: grid;
  gap: var(--space-3);
}

.group-result__help {
  justify-self: start;
  font-size: 0.875rem;
  color: var(--color-title);
}

.group-result__subtitle {
  font-size: 1rem;
}

.group-result__list {
  display: grid;
  gap: var(--space-2);
  margin: 0;
}

.group-result__item dt {
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.group-result__item dd {
  margin: 0;
  font-weight: 600;
}

// The table scrolls on its own so the modal never scrolls sideways on phones
.group-result__table-wrap {
  display: none;
  overflow-x: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.group-result__table {
  width: 100%;
  min-width: 34rem;
  border-collapse: collapse;
  font-variant-numeric: tabular-nums;

  th,
  td {
    padding: var(--space-2) var(--space-3);
    text-align: right;
  }

  th:first-child,
  td:first-child,
  th:nth-child(2) {
    text-align: left;
  }

  thead th {
    font-size: 0.75rem;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--color-text-muted);
  }

  tbody tr + tr > * {
    border-top: 1px solid var(--color-border);
  }

  tbody th {
    font-weight: 600;
  }
}

.group-result__position {
  font-weight: 800;
  color: var(--color-title);
}

.group-result__queen {
  display: flex;
  gap: var(--space-3);
  align-items: center;

  .avatar {
    width: 2rem;
    height: 2rem;
  }

  .avatar__initial {
    font-size: 0.9rem;
  }
}

.group-result__band {
  display: block;
  font-size: 0.8125rem;
  font-weight: 400;
  color: var(--color-text-muted);
}

.group-result__total {
  font-weight: 800;
}

.group-result__first > * {
  background-color: color-mix(in srgb, var(--color-highlight) 25%, var(--color-surface));
}

.group-cards {
  display: grid;
  gap: var(--space-3);
  padding: 0;
  margin: 0;
  list-style: none;
  font-variant-numeric: tabular-nums;
}

.group-cards__item {
  display: grid;
  gap: var(--space-3);
  padding: var(--space-3) var(--space-4);
  background-color: var(--color-surface-raised);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

// The winner's tint goes on the whole card, not on its children
.group-cards__item.group-result__first {
  background-color: color-mix(in srgb, var(--color-highlight) 25%, var(--color-surface));
}

.group-cards__item.group-result__first > * {
  background-color: transparent;
}

.group-cards__head {
  display: flex;
  gap: var(--space-3);
  align-items: center;
}

.group-cards__who {
  flex: 1;
  min-width: 0;
  overflow-wrap: anywhere;
}

.group-cards__name {
  display: block;
  font-weight: 700;
}

.group-cards__total {
  display: grid;
  justify-items: end;
  font-size: 1.25rem;
  font-weight: 800;
}

.group-cards__label,
.group-cards__scores dt {
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.group-cards__scores {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--space-2);
  margin: 0;
  text-align: center;
}

.group-cards__scores dd {
  margin: 0;
  font-weight: 600;
}

.group-cards .avatar {
  width: 2rem;
  height: 2rem;
}

.group-cards .avatar__initial {
  font-size: 0.9rem;
}

// Wide screens swap the cards for the table
@media (min-width: 48rem) {
  .group-cards {
    display: none;
  }

  .group-result__table-wrap {
    display: block;
  }
}
</style>
