<script setup lang="ts">
definePageMeta({ middleware: 'jurado' })

const route = useRoute()
const supabase = useSupabaseClient()
const runwayId = String(route.params.id)

const { data, error: loadError, refresh } = await useAsyncData(`admin-runway-${runwayId}`, async () => {
  const runway = await supabase
    .from('runways')
    .select('id, week_number, runway_date, status')
    .eq('id', runwayId)
    .maybeSingle()
  if (runway.error) throw runway.error
  if (!runway.data) return null

  const categories = await supabase
    .from('categories')
    .select('id, title, intro_text')
    .eq('runway_id', runwayId)
    .order('created_at', { ascending: true })
  if (categories.error) throw categories.error

  return { runway: runway.data, categories: categories.data }
})

if (!loadError.value && !data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Semana no encontrada', fatal: true })
}

const runway = computed(() => data.value?.runway ?? null)

// The section pages only render when the runway loaded, so the non-null assertion is safe
provideAdminRunway({
  runway: computed(() => data.value!.runway),
  categories: computed(() => data.value?.categories ?? []),
  refresh: async () => {
    await refresh()
  },
})

const sections = computed(() => [
  { to: `/admin/runways/${runwayId}`, label: 'Resumen', exact: true },
  { to: `/admin/runways/${runwayId}/categories`, label: 'Categorías', exact: false },
  { to: `/admin/runways/${runwayId}/looks`, label: 'Looks', exact: false },
])
const isActive = (section: { to: string, exact: boolean }): boolean =>
  section.exact ? route.path === section.to : route.path.startsWith(section.to)
</script>

<template>
  <main v-if="runway" class="page">
    <AppNav />
    <AppBreadcrumb
      :items="[
        { label: 'Inicio', to: '/' },
        { label: 'Panel del jurado', to: '/admin' },
        { label: `Semana ${runway.week_number}` },
      ]"
    />

    <header class="page-header">
      <h1>Semana {{ runway.week_number }}</h1>
      <StatusBadge :status="runway.status" />
    </header>

    <nav class="tabs" aria-label="Secciones de la semana">
      <NuxtLink
        v-for="section in sections"
        :key="section.to"
        :to="section.to"
        class="tabs__tab"
        :class="{ 'tabs__tab--active': isActive(section) }"
        :aria-current="isActive(section) ? 'page' : undefined"
      >
        {{ section.label }}
      </NuxtLink>
    </nav>

    <NuxtPage />
  </main>

  <main v-else class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Panel del jurado', to: '/admin' }]" />
    <p class="form-error" role="alert">
      {{ toErrorMessage(loadError) }}
    </p>
  </main>
</template>
