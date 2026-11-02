<script setup lang="ts">
import type { Tables } from '~/types/database.types'

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
}

const route = useRoute()
const supabase = useSupabaseClient()
const categoryId = String(route.params.id)

// RLS hides draft categories (and their looks) from contestants, so they get a 404
const { data, error: loadError } = await useAsyncData(
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

    return { category: category.data, looks: looks.data }
  },
)

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Categoría no encontrada', fatal: true })
}

const category = computed(() => data.value?.category ?? null)
const looks = computed(() => data.value?.looks ?? [])

const displayName = (look: RunwayLook): string => look.participant.drag_name ?? look.participant.name

// --- Enlarged view --------------------------------------------------------
const selectedLook = ref<RunwayLook | null>(null)
</script>

<template>
  <main v-if="category" class="page page--wide">
    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Semana {{ category.week_number }}
          <StatusBadge :status="category.status" />
        </p>
        <h1>{{ category.title }}</h1>
      </div>
      <nav class="page-header__actions">
        <NuxtLink to="/" class="btn btn--ghost">
          ← Inicio
        </NuxtLink>
      </nav>
    </header>

    <p v-if="category.intro_text" class="lead intro">
      {{ category.intro_text }}
    </p>

    <ul v-if="looks.length" class="gallery">
      <li v-for="look in looks" :key="look.id">
        <button type="button" class="look-card" @click="selectedLook = look">
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

    <AppModal :open="selectedLook !== null" :title="selectedLook ? displayName(selectedLook) : ''" @close="selectedLook = null">
      <figure v-if="selectedLook" class="look-full">
        <img :src="selectedLook.image_url" :alt="`Look de ${displayName(selectedLook)}`">
        <figcaption v-if="selectedLook.intro" class="look-full__intro">
          {{ selectedLook.intro }}
        </figcaption>
      </figure>
    </AppModal>
  </main>

  <main v-else class="page">
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
