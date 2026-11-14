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
    ? await supabase.from('participants').select('id, name, drag_name').in('id', ids)
    : { data: [], error: null }
  if (names.error) throw names.error

  const groupName = (groupId: string): string => groups.data.find(group => group.id === groupId)?.name ?? ''
  const queenName = (id: string): string => {
    const queen = names.data.find(candidate => candidate.id === id)
    return queen ? (queen.drag_name ?? queen.name) : '—'
  }

  return {
    winningGroups: groupResult.data.filter(row => row.is_winner).map(row => groupName(row.group_id)).filter(Boolean),
    // Order and shared positions come from the database (`position`)
    rows: ranking.data.map(row => ({ ...row, name: queenName(row.participant_id), band: groupName(row.group_id) })),
  }
})

const hasRanking = computed(() => !!data.value?.rows.some(row => row.total > row.band_bonus))
</script>

<template>
  <section v-if="data && (data.winningGroups.length || data.rows.length)" class="group-result" :aria-labelledby="`group-result-${category.id}`">
    <header class="group-result__header">
      <h2 :id="`group-result-${category.id}`" class="group-result__title">
        Resultados{{ showTitle ? ` · ${category.title}` : '' }}
      </h2>
      <NuxtLink :to="GROUP_VOTING_HELP_PATH" class="group-result__help">
        {{ GROUP_VOTING_COPY.helpLink }}
      </NuxtLink>
    </header>

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
                {{ copy.headers.cross }}
              </th>
              <th scope="col">
                {{ copy.headers.jury }}
              </th>
              <th scope="col">
                {{ copy.headers.bonus }}
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
                {{ row.name }}
                <span class="group-result__band">{{ row.band }}</span>
              </th>
              <td>{{ formatScore(row.cross_score) }}</td>
              <td>{{ formatScore(row.jury_score) }}</td>
              <td>{{ row.band_bonus ? formatScore(row.band_bonus, 1) : '0' }}</td>
              <td class="group-result__total">
                {{ formatScore(row.total) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </section>
  <p v-else-if="error" class="form-error" role="alert">
    {{ toErrorMessage(error) }}
  </p>
</template>

<style scoped lang="scss">
.group-result {
  display: grid;
  gap: var(--space-3);
  max-width: 40rem;
  padding: var(--space-3);
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);
}

.group-result__header {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: baseline;
  justify-content: space-between;
}

.group-result__title {
  font-size: 1.125rem;
  color: var(--color-title);
}

.group-result__help {
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

// The table scrolls on its own so the page never scrolls sideways on phones
.group-result__table-wrap {
  overflow-x: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.group-result__table {
  width: 100%;
  min-width: 30rem;
  border-collapse: collapse;
  font-variant-numeric: tabular-nums;

  th,
  td {
    padding: var(--space-2) var(--space-3);
    text-align: right;
  }

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
</style>
