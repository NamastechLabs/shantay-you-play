<script setup lang="ts">
import type { ReleaseNote } from '~/utils/releaseNotes'

defineProps<{
  release: ReleaseNote
  /** The newest release gets a "Nueva" badge */
  latest?: boolean
}>()
</script>

<template>
  <article :id="`v${release.version}`" class="card release-card">
    <div class="release-card__meta">
      <span class="badge release-card__version"><span class="sr-only">Versión </span>v{{ release.version }}</span>
      <span v-if="latest" class="badge release-card__new">Nueva</span>
      <time class="kicker" :datetime="release.date">{{ formatReleaseDate(release.date) }}</time>
    </div>
    <h2>{{ release.title }}</h2>
    <ul class="release-card__features">
      <li v-for="feature in release.features" :key="feature">
        {{ feature }}
      </li>
    </ul>
  </article>
</template>

<style scoped lang="scss">
.release-card {
  display: grid;
  gap: var(--space-2);
  // A link like /release-notes#v0.2.0 lands below the pinned top bar, with some air
  scroll-margin-top: var(--space-5);

  h2 {
    font-size: 1.25rem;
    color: var(--color-title);
  }
}

.release-card__meta {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: center;
}

.release-card__version {
  color: var(--color-title);
  letter-spacing: 0.04em;
  text-transform: none;
  background-color: var(--color-surface-raised);
  border-color: var(--color-border);
}

.release-card__new {
  color: var(--color-on-primary);
  background-color: var(--color-primary);
}

// One marker per feature, so several features read as separate items
.release-card__features {
  display: grid;
  gap: var(--space-2);
  padding: 0;
  margin: 0;
  list-style: none;

  li {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    gap: var(--space-2);
  }

  li::before {
    color: var(--color-kicker);
    content: '✦';
  }
}
</style>
