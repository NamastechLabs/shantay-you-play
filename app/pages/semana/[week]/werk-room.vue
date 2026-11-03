<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'>
type Category = Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text'>
type MyLook = Pick<Tables<'looks'>, 'id' | 'category_id' | 'participant_id' | 'intro'> & LookImages

interface WerkRoom {
  runway: Runway
  categories: Category[]
  looks: MyLook[]
}

const route = useRoute()
const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()

const weekNumber = Number(route.params.week)

// RLS hides draft runways, so a week that does not exist or is not in the Werk Room looks the same: closed
const { data, error, refresh } = await useAsyncData(`werk-room-${route.params.week}`, async (): Promise<WerkRoom | null> => {
  if (!Number.isInteger(weekNumber) || weekNumber < 1) return null

  const runway = await supabase
    .from('runways')
    .select('id, week_number, runway_date, status')
    .eq('week_number', weekNumber)
    .maybeSingle()
  if (runway.error) throw runway.error
  if (runway.data?.status !== 'werk_room') return null

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
    .from('looks')
    .select('id, category_id, participant_id, image_url, image2_url, image3_url, image4_url, intro')
    .eq('participant_id', participantId)
    .in('category_id', categoryIds)
  if (looks.error) throw looks.error

  return { runway: runway.data, categories: categories.data, looks: looks.data }
})

const isOpen = computed(() => data.value !== null && data.value !== undefined)

// Not an error page, but the response still says "too early" (429) for crawlers and monitors
if (!error.value && !isOpen.value && import.meta.server) {
  setResponseStatus(useRequestEvent()!, 429, 'Too Many Requests')
}

useHead({ title: isOpen.value ? `Werk Room · Semana ${weekNumber}` : 'Werk Room cerrado' })
useSeoMeta({ robots: 'noindex' })

const isContestant = computed(() => participant.value?.role === 'concursante')
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
          { label: 'Werk Room' },
        ]"
      />

      <!-- Neon sign; the word is the whole message, so screen readers get the page title instead -->
      <div class="werk-sign" aria-hidden="true">
        <span class="werk-sign__text">WERK</span>
      </div>

      <header class="page-header">
        <div class="page-header__titles">
          <p class="kicker">
            Semana {{ data.runway.week_number }} · {{ formatRunwayDate(data.runway.runway_date) }}
          </p>
          <h1>Tu look para {{ runwayTitle(data.categories) }}</h1>
        </div>
      </header>

      <p v-if="!isContestant" class="hint">
        Esta zona es para las concursantes. Los looks de todas se gestionan desde el
        <NuxtLink to="/admin" class="link">panel del jurado</NuxtLink>.
      </p>
      <p v-else-if="!data.categories.length" class="empty">
        Esta semana aún no tiene categorías. ¡Vuelve pronto, reina!
      </p>
      <template v-else>
        <p class="hint">
          Sube hasta 4 fotos de tu look (frente, espalda, rebuild y una extra) y cuéntanos de qué va.
          La foto de frente es obligatoria. Puedes cambiarlo todo mientras el Werk Room siga abierto.
        </p>
        <ul class="row-list">
          <LookEditRow
            v-for="category in data.categories"
            :key="category.id"
            :category-id="category.id"
            :contestant="participant!"
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
        ¡¿Dónde crees que vas, reina?!
      </h1>
      <p class="lead">
        ¡El Werk Room todavía no está abierto!
      </p>
      <NuxtLink to="/" class="btn btn--primary">
        Volver a la pasarela
      </NuxtLink>
    </section>
  </main>
</template>

<style scoped lang="scss">
// Pink neon sign on a dark curtain, built from the theme's primary color
.werk-sign {
  display: grid;
  place-items: center;
  padding: var(--space-6) var(--space-4);
  overflow: hidden;
  background:
    repeating-linear-gradient(
      90deg,
      color-mix(in srgb, var(--color-primary) 22%, black) 0 0.75rem,
      color-mix(in srgb, var(--color-primary) 10%, black) 0.75rem 1.5rem
    );
  border-radius: var(--radius-lg);
  box-shadow: inset 0 0 4rem black;
}

.werk-sign__text {
  --neon: var(--color-primary);
  --core: color-mix(in srgb, var(--color-primary) 25%, white);

  font-family: var(--font-body);
  font-size: clamp(3rem, 2rem + 8vw, 6rem);
  font-weight: 500;
  line-height: 1;
  letter-spacing: 0.12em;
  // The trailing letter-spacing would push the word off-center
  padding-left: 0.12em;
  color: var(--core);
  text-shadow:
    0 0 0.05em var(--core),
    0 0 0.12em var(--neon),
    0 0 0.3em var(--neon),
    0 0 0.6em var(--neon),
    0 0 1em var(--neon);

  @media (prefers-reduced-motion: no-preference) {
    animation: neon-flicker 5s infinite;
  }
}

@keyframes neon-flicker {
  0%, 18%, 22%, 62%, 64%, 100% {
    opacity: 1;
  }

  20%, 63% {
    opacity: 0.75;
  }
}

.week-empty {
  display: grid;
  gap: var(--space-3);
  justify-items: center;
  padding: var(--space-7) var(--space-4);
  text-align: center;
  background-color: var(--color-surface);
  border: 2px dashed var(--color-border);
  border-radius: var(--radius-lg);
}

.week-empty__icon {
  display: grid;
  place-items: center;
  width: 4rem;
  height: 4rem;
  font-size: 2rem;
  background-color: color-mix(in srgb, var(--color-highlight) 30%, var(--color-surface));
  border-radius: var(--radius-pill);
  box-shadow: var(--glow-accent);
}

.week-empty .lead {
  max-width: 28rem;
}
</style>
