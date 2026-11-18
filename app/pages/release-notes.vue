<script setup lang="ts">
useHead({ title: `Novedades · ${APP_NAME}` })
useSeoMeta({ robots: 'noindex' })

/** The newest releases are open; the rest wait behind "Versiones anteriores" */
const RECENT_COUNT = 3

const recent = RELEASE_NOTES.slice(0, RECENT_COUNT)
const older = RELEASE_NOTES.slice(RECENT_COUNT)
const versions = RELEASE_NOTES.map(release => ({ id: `v${release.version}`, title: `v${release.version}` }))
const olderIds = new Set(older.map(release => `v${release.version}`))

const olderOpen = ref(false)
const { activeId } = useActiveSection(versions.map(version => version.id))

// A version that sits among the older ones needs them open before the page can scroll to it
function openFor(id: string): void {
  if (olderIds.has(id)) olderOpen.value = true
}

async function goToVersion(id: string): Promise<void> {
  openFor(id)
  activeId.value = id
  await nextTick()
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  document.getElementById(id)?.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'start' })
}

// Arriving with /release-notes#v0.2.0: the browser could not scroll to it while it was hidden
onMounted(async () => {
  const id = decodeURIComponent(window.location.hash.slice(1))
  if (!olderIds.has(id)) return
  olderOpen.value = true
  await nextTick()
  document.getElementById(id)?.scrollIntoView({ block: 'start' })
})
</script>

<template>
  <main class="page release-notes">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Novedades' }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Lo último del taller
        </p>
        <h1>Novedades</h1>
      </div>
    </header>

    <p class="lead">
      Aquí tienes lo que hemos ido estrenando, con su fecha. ¡Lo más nuevo, primero!
    </p>

    <!-- Phones and tablets: sticky row of versions; desktop has the side list instead -->
    <SectionTabs :items="versions" label="Versiones" until="desktop" @navigate="openFor" />

    <div class="release-notes__layout">
      <aside class="release-notes__aside">
        <nav aria-label="Versiones">
          <p class="kicker">
            Versiones
          </p>
          <ul>
            <li v-for="version in versions" :key="version.id">
              <a
                :href="`#${version.id}`"
                :aria-current="activeId === version.id ? 'location' : undefined"
                @click.prevent="goToVersion(version.id)"
              >{{ version.title }}</a>
            </li>
          </ul>
        </nav>
      </aside>

      <div class="release-notes__content">
        <ol class="release-notes__list">
          <li v-for="(release, index) in recent" :key="release.version">
            <ReleaseNoteCard :release="release" :latest="index === 0" />
          </li>
        </ol>

        <details v-if="older.length" class="release-notes__older" :open="olderOpen" @toggle="olderOpen = ($event.target as HTMLDetailsElement).open">
          <summary class="btn btn--secondary btn--block">
            {{ olderOpen ? 'Ocultar versiones anteriores' : `Versiones anteriores (${older.length})` }}
          </summary>
          <ol class="release-notes__list">
            <li v-for="release in older" :key="release.version">
              <ReleaseNoteCard :release="release" />
            </li>
          </ol>
        </details>

        <NuxtLink to="/" class="btn btn--primary release-notes__back">
          Volver a la pasarela
        </NuxtLink>
      </div>
    </div>

    <BackToTop />
  </main>
</template>

<style scoped lang="scss">
.release-notes {
  display: grid;
  gap: var(--space-5);
}

.release-notes__layout {
  display: grid;
  gap: var(--space-5);
  align-items: start;

  @media (min-width: 64rem) {
    grid-template-columns: 10rem minmax(0, 48rem);
    gap: var(--space-6);
  }
}

// Desktop only: the phone and tablet versions of this list are the sticky tabs
.release-notes__aside {
  display: none;

  @media (min-width: 64rem) {
    position: sticky;
    top: var(--space-5);
    display: block;
    max-height: calc(100dvh - var(--space-7));
    overflow-y: auto;
    scrollbar-width: thin;
  }

  nav {
    display: grid;
    gap: var(--space-2);
  }

  ul {
    display: grid;
    gap: var(--space-1);
    padding: 0 0 0 var(--space-3);
    margin: 0;
    list-style: none;
    border-left: 2px solid var(--color-border);
  }

  a {
    display: block;
    padding: var(--space-1) var(--space-2);
    font-size: 0.9rem;
    color: inherit;
    text-decoration: none;
    border-radius: var(--radius-sm);

    &:hover {
      color: var(--color-primary);
    }

    &[aria-current='location'] {
      font-weight: 700;
      color: var(--color-title);
      background-color: color-mix(in srgb, var(--color-primary) 15%, transparent);
    }
  }
}

.release-notes__content {
  display: grid;
  gap: var(--space-4);
  min-width: 0;
}

.release-notes__list {
  display: grid;
  gap: var(--space-4);
  padding: 0;
  margin: 0;
  list-style: none;
}

.release-notes__older {
  display: grid;
  gap: var(--space-4);

  // The summary is the button: no browser marker
  > summary {
    list-style: none;
    cursor: pointer;

    &::-webkit-details-marker {
      display: none;
    }
  }

  &[open] > summary {
    margin-bottom: var(--space-4);
  }
}

.release-notes__back {
  justify-self: start;
}
</style>
