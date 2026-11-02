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
const dialog = ref<HTMLDialogElement | null>(null)
const selectedLook = ref<RunwayLook | null>(null)

function openLook(look: RunwayLook): void {
  selectedLook.value = look
  dialog.value?.showModal()
}

function closeLook(): void {
  dialog.value?.close()
}
</script>

<template>
  <main v-if="category" class="runway">
    <header>
      <div>
        <p class="week">
          Semana {{ category.week_number }}
          <span class="status">{{ CATEGORY_STATUS_LABELS[category.status] }}</span>
        </p>
        <h1>{{ category.title }}</h1>
      </div>
      <NuxtLink to="/">
        ← Inicio
      </NuxtLink>
    </header>

    <p v-if="category.intro_text" class="intro">
      {{ category.intro_text }}
    </p>

    <ul v-if="looks.length" class="gallery">
      <li v-for="look in looks" :key="look.id">
        <button type="button" class="card" @click="openLook(look)">
          <img :src="look.image_url" :alt="`Look de ${displayName(look)}`" loading="lazy">
          <span class="name">{{ displayName(look) }}</span>
        </button>
      </li>
    </ul>
    <p v-else class="empty">
      Todavía no hay looks en la pasarela.
    </p>

    <dialog ref="dialog" @click.self="closeLook" @close="selectedLook = null">
      <figure v-if="selectedLook">
        <img :src="selectedLook.image_url" :alt="`Look de ${displayName(selectedLook)}`">
        <figcaption>
          <strong>{{ displayName(selectedLook) }}</strong>
          <p v-if="selectedLook.intro">
            {{ selectedLook.intro }}
          </p>
        </figcaption>
      </figure>
      <button type="button" class="close" aria-label="Cerrar" @click="closeLook">
        ✕
      </button>
    </dialog>
  </main>

  <main v-else class="runway">
    <p class="error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
  </main>
</template>

<style scoped>
.runway {
  max-width: 60rem;
  margin: 0 auto;
  padding: 1rem;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
}

.week {
  margin: 0;
  opacity: 0.8;
}

h1 {
  margin: 0.25rem 0 0;
}

.status {
  margin-left: 0.5rem;
  padding: 0.1rem 0.5rem;
  font-size: 0.8rem;
  border: 1px solid currentColor;
  border-radius: 999px;
}

.intro {
  white-space: pre-line;
}

.gallery {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(12rem, 1fr));
  gap: 1rem;
  padding: 0;
  list-style: none;
}

.card {
  display: grid;
  gap: 0.5rem;
  width: 100%;
  padding: 0;
  font: inherit;
  color: inherit;
  text-align: left;
  background: none;
  border: 0;
  cursor: pointer;
}

.card img {
  width: 100%;
  aspect-ratio: 3 / 4;
  border-radius: 0.5rem;
  object-fit: cover;
}

.name {
  font-weight: 600;
}

dialog {
  max-width: min(90vw, 40rem);
  max-height: 90dvh;
  padding: 1rem;
  border: 0;
  border-radius: 0.75rem;
}

dialog::backdrop {
  background: rgb(0 0 0 / 0.7);
}

dialog img {
  max-width: 100%;
  max-height: 70dvh;
  border-radius: 0.5rem;
}

figure {
  display: grid;
  justify-items: center;
  gap: 0.5rem;
  margin: 0;
}

.close {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  cursor: pointer;
}

.empty {
  opacity: 0.7;
}

.error {
  color: #d33;
}
</style>
