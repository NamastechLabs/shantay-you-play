<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { BreadcrumbItem } from '~/components/AppBreadcrumb.vue'

type Category = Pick<Tables<'categories'>, 'id' | 'week_number' | 'title' | 'intro_text' | 'status'>

interface RunwayLook {
  id: string
  image_url: string
  intro: string | null
  participant: Pick<Tables<'participants'>, 'id' | 'name' | 'drag_name'>
}

interface RunwayData {
  category: Category
  looks: RunwayLook[]
  /** Final place per look id; only filled once the category is closed */
  placeByLook: Record<string, number>
}

const route = useRoute()
const supabase = useSupabaseClient()
const categoryId = String(route.params.id)

// RLS hides draft categories (and their looks) from contestants, so they get a 404
const { data, error: loadError, refresh } = await useAsyncData(
  `runway-${categoryId}`,
  async (): Promise<RunwayData | null> => {
    const [category, looks] = await Promise.all([
      supabase
        .from('categories')
        .select('id, week_number, title, intro_text, status')
        .eq('id', categoryId)
        .maybeSingle(),
      supabase
        .from('looks')
        .select('id, image_url, intro, participant:participants!looks_participant_id_fkey(id, name, drag_name)')
        .eq('category_id', categoryId)
        .order('created_at', { ascending: true }),
    ])

    if (category.error) throw category.error
    if (looks.error) throw looks.error
    if (!category.data) return null

    let placeByLook: Record<string, number> = {}
    if (category.data.status === 'closed') {
      const ranking = await supabase.rpc('category_ranking', { p_category_id: categoryId })
      if (ranking.error) throw ranking.error
      placeByLook = Object.fromEntries(ranking.data.map(row => [row.look_id, row.place]))
    }

    return { category: category.data, looks: looks.data, placeByLook }
  },
)

// The final ranking appears as soon as the jurado closes the category
useCategoriesRealtime(refresh, categoryId)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Categoría no encontrada', fatal: true })
}

const category = computed(() => data.value?.category ?? null)
const placeByLook = computed(() => data.value?.placeByLook ?? {})

// Closed categories list the final ranking first; looks nobody voted for keep their runway order
const looks = computed(() => {
  const all = data.value?.looks ?? []
  if (category.value?.status !== 'closed') return all
  const place = (look: RunwayLook): number => placeByLook.value[look.id] ?? Infinity
  return [...all].sort((a, b) => place(a) - place(b))
})

// Closed categories are reached from "Categorías pasadas", so the trail goes back through it
const breadcrumb = computed<BreadcrumbItem[]>(() => {
  const current = { label: `Semana ${category.value?.week_number}` }
  return category.value?.status === 'closed'
    ? [{ label: 'Inicio', to: '/' }, { label: 'Categorías pasadas', to: '/categories/past' }, current]
    : [{ label: 'Inicio', to: '/' }, current]
})

const displayName = (look: RunwayLook): string => look.participant.drag_name ?? look.participant.name

// --- Enlarged view --------------------------------------------------------
const selectedLook = ref<RunwayLook | null>(null)

// Step through the queens in gallery order, wrapping around at both ends
function showAdjacentLook(step: 1 | -1): void {
  const current = looks.value.findIndex(look => look.id === selectedLook.value?.id)
  if (current === -1) return
  selectedLook.value = looks.value[(current + step + looks.value.length) % looks.value.length] ?? null
}
</script>

<template>
  <main v-if="category" class="page page--wide">
    <AppNav />
    <AppBreadcrumb :items="breadcrumb" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Semana {{ category.week_number }}
          <StatusBadge :status="category.status" />
        </p>
        <h1>{{ category.title }}</h1>
      </div>
      <nav class="page-header__actions">
        <NuxtLink v-if="category.status === 'voting'" :to="`/categories/${category.id}/vote`" class="btn btn--primary">
          Votar los mejores looks
        </NuxtLink>
      </nav>
    </header>

    <p v-if="category.intro_text" class="lead intro">
      {{ category.intro_text }}
    </p>

    <ul v-if="looks.length" class="gallery">
      <li v-for="look in looks" :key="look.id">
        <button type="button" class="look-card" @click="selectedLook = look">
          <span v-if="placeByLook[look.id]" class="look-card__rank">{{ placeByLook[look.id] }}</span>
          <span v-if="placeByLook[look.id] === 1" class="look-card__crown" role="img" aria-label="Ganadora">♛</span>
          <img
            class="look-card__photo"
            :src="look.image_url"
            :alt="`Look de ${displayName(look)}`"
            loading="lazy"
          >
          <span class="look-card__body">
            <span class="look-card__name">{{ displayName(look) }}</span>
            <span v-if="look.intro" class="look-card__intro">{{ look.intro }}</span>
          </span>
        </button>
      </li>
    </ul>
    <p v-else class="empty">
      Todavía no hay looks en la pasarela.
    </p>

    <AppModal wide :open="selectedLook !== null" :title="selectedLook ? displayName(selectedLook) : ''" @close="selectedLook = null">
      <figure v-if="selectedLook" class="look-full">
        <img :src="selectedLook.image_url" :alt="`Look de ${displayName(selectedLook)}`">
        <figcaption v-if="selectedLook.intro" class="look-full__intro">
          {{ selectedLook.intro }}
        </figcaption>
        <nav v-if="looks.length > 1" class="look-full__nav" aria-label="Navegar entre reinas">
          <button type="button" class="btn btn--secondary" @click="showAdjacentLook(-1)">
            ← Reina anterior
          </button>
          <button type="button" class="btn btn--secondary" @click="showAdjacentLook(1)">
            Reina siguiente →
          </button>
        </nav>
      </figure>
    </AppModal>
  </main>

  <main v-else class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }]" />
    <p class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
  </main>
</template>

<style scoped>
.intro {
  max-width: 44rem;
  white-space: pre-line;
}
</style>
