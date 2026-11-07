<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'>
type Category = Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text'>
type MyJuryLook = Pick<Tables<'jury_looks'>, 'id' | 'category_id' | 'participant_id' | 'intro'> & LookImages

interface GuestLooks {
  runway: Runway
  categories: Category[]
  looks: MyJuryLook[]
}

const route = useRoute()
const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()

const weekNumber = Number(route.params.week)

// RLS only returns runways the guest is actively invited to, so a week they were not
// invited to (or whose invitation ended) looks the same as one that is not open: closed
const { data, error, refresh } = await useAsyncData(`guest-looks-${route.params.week}`, async (): Promise<GuestLooks | null> => {
  if (!Number.isInteger(weekNumber) || weekNumber < 1) return null

  const runway = await supabase
    .from('runways')
    .select('id, week_number, runway_date, status')
    .eq('week_number', weekNumber)
    .maybeSingle()
  if (runway.error) throw runway.error
  if (!runway.data || (runway.data.status !== 'werk_room' && runway.data.status !== 'runway')) return null

  const categories = await supabase
    .from('categories')
    .select('id, title, intro_text')
    .eq('runway_id', runway.data.id)
    .order('created_at', { ascending: true })
  if (categories.error) throw categories.error

  const participantId = participant.value?.id
  const categoryIds = categories.data.map(category => category.id)
  if (!participantId || !categoryIds.length) return { runway: runway.data, categories: categories.data, looks: [] }

  const looks = await supabase
    .from('jury_looks')
    .select('id, category_id, participant_id, image_url, image2_url, image3_url, image4_url, intro')
    .eq('participant_id', participantId)
    .in('category_id', categoryIds)
  if (looks.error) throw looks.error

  return { runway: runway.data, categories: categories.data, looks: looks.data }
})

useHead({ title: data.value ? `Mi look de jurado · Semana ${weekNumber}` : 'Look de jurado cerrado' })
useSeoMeta({ robots: 'noindex' })

const isGuest = computed(() => participant.value?.role === 'invitado')
const lookByCategory = computed(() => new Map(data.value?.looks.map(look => [look.category_id, look])))
const multipleCategories = computed(() => (data.value?.categories.length ?? 0) > 1)
</script>

<template>
  <main class="page">
    <AppNav />

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <template v-else-if="data">
      <AppBreadcrumb
        :items="[
          { label: 'Inicio', to: '/' },
          { label: `Semana ${data.runway.week_number}` },
          { label: 'Mi look de jurado' },
        ]"
      />

      <header class="page-header">
        <div class="page-header__titles">
          <p class="kicker">
            Semana {{ data.runway.week_number }} · {{ formatRunwayDate(data.runway.runway_date) }}
          </p>
          <h1>Tu look de jurado para {{ runwayTitle(data.categories) }}</h1>
        </div>
      </header>

      <p v-if="!isGuest" class="hint">
        Esta zona es para los invitados especiales del jurado.
      </p>
      <p v-else-if="!data.categories.length" class="empty">
        Esta semana aún no tiene categorías. ¡Vuelve pronto!
      </p>
      <template v-else>
        <p class="hint">
          Sube hasta 4 fotos de tu look (frente, espalda, reveal y una extra) y escribe una presentación.
          La foto de frente y la presentación son obligatorias. Podrás cambiarlo mientras la semana siga en Werk Room o Pasarela.
        </p>
        <ul class="row-list">
          <AdminJuryLookRow
            v-for="category in data.categories"
            :key="category.id"
            :category-id="category.id"
            :judge="participant!"
            :look="lookByCategory.get(category.id) ?? null"
            :title="multipleCategories ? category.title : undefined"
            editable
            @changed="refresh()"
          />
        </ul>
      </template>
    </template>

    <section v-else class="week-empty" aria-labelledby="closed-title">
      <span class="week-empty__icon" aria-hidden="true">✋</span>
      <h1 id="closed-title">
        Aún no puedes subir tu look
      </h1>
      <p class="lead">
        Solo puedes subirlo mientras la semana esté en Werk Room o Pasarela, y solo si el jurado te ha invitado.
      </p>
      <NuxtLink to="/" class="btn btn--primary">
        Volver a la pasarela
      </NuxtLink>
    </section>
  </main>
</template>
