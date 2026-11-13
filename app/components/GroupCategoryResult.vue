<script setup lang="ts">
import type { Tables } from '~/types/database.types'

const props = defineProps<{
  category: Pick<Tables<'categories'>, 'id' | 'title'>
  showTitle: boolean
}>()

const supabase = useSupabaseClient()

// Both functions return nothing until the runway reaches 'reveal'
const { data, error } = await useAsyncData(`group-result-${props.category.id}`, async () => {
  const [groupResult, queenResult, groups] = await Promise.all([
    supabase.rpc('category_group_result', { p_category_id: props.category.id }),
    supabase.rpc('category_queen_result', { p_category_id: props.category.id }),
    supabase.from('category_groups').select('id, name').eq('category_id', props.category.id),
  ])
  if (groupResult.error) throw groupResult.error
  if (queenResult.error) throw queenResult.error
  if (groups.error) throw groups.error

  const queenIds = queenResult.data.map(row => row.participant_id)
  const queens = queenIds.length
    ? await supabase.from('participants').select('id, name, drag_name').in('id', queenIds)
    : { data: [], error: null }
  if (queens.error) throw queens.error

  return {
    winningGroups: groupResult.data
      .filter(row => row.is_winner)
      .map(row => groups.data.find(group => group.id === row.group_id)?.name)
      .filter((name): name is string => !!name),
    winningQueens: queens.data.map(queen => queen.drag_name ?? queen.name),
  }
})
</script>

<template>
  <section v-if="data && (data.winningGroups.length || data.winningQueens.length)" class="group-result" :aria-labelledby="`group-result-${category.id}`">
    <h2 :id="`group-result-${category.id}`" class="group-result__title">
      Resultados{{ showTitle ? ` · ${category.title}` : '' }}
    </h2>
    <dl class="group-result__list">
      <div v-if="data.winningGroups.length" class="group-result__item">
        <dt>{{ data.winningGroups.length > 1 ? 'Grupos ganadores (empate)' : 'Grupo ganador' }}</dt>
        <dd>{{ data.winningGroups.join(' y ') }}</dd>
      </div>
      <div v-if="data.winningQueens.length" class="group-result__item">
        <dt>{{ data.winningQueens.length > 1 ? 'Reinas top 1 (empate)' : 'Reina top 1' }}</dt>
        <dd>{{ data.winningQueens.join(' y ') }}</dd>
      </div>
    </dl>
  </section>
  <p v-else-if="error" class="form-error" role="alert">
    {{ toErrorMessage(error) }}
  </p>
</template>

<style scoped lang="scss">
.group-result {
  display: grid;
  gap: var(--space-2);
  max-width: 40rem;
  padding: var(--space-3);
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);
}

.group-result__title {
  font-size: 1.125rem;
  color: var(--color-title);
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
</style>
