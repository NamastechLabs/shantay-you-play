<script setup lang="ts">
import type { CategoryWinner } from '~/composables/useCategoryWinners'

defineProps<{
  category: { id: string, week_number: number, title: string }
  winner?: CategoryWinner | null
}>()
</script>

<template>
  <NuxtLink :to="`/categories/${category.id}`" class="past-card" :class="{ 'past-card--no-photo': !winner }">
    <img
      v-if="winner"
      class="past-card__photo"
      :src="winner.image_url"
      :alt="`Look de ${winner.name}, ganadora de la semana ${category.week_number}`"
      loading="lazy"
    >
    <div class="past-card__body">
      <p class="kicker">
        Semana {{ category.week_number }}
      </p>
      <h3 class="past-card__title">
        {{ category.title }}
      </h3>
      <p v-if="winner" class="past-card__winner">
        <span class="past-card__crown" aria-hidden="true">♛</span>
        <span class="muted">Ganadora</span>
        <strong class="past-card__name">{{ winner.name }}</strong>
      </p>
      <p v-else class="muted">
        Sin ganadora todavía.
      </p>
    </div>
  </NuxtLink>
</template>

<style scoped lang="scss">
.past-card {
  display: grid;
  overflow: hidden;
  color: inherit;
  text-decoration: none;
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);

  &:hover,
  &:focus-visible {
    border-color: var(--color-highlight);
    box-shadow: var(--shadow-raised), var(--glow-primary);
  }

  // Photo on the left from tablet portrait up: fixed 300px, then 2 of 8 columns on desktop
  @media (min-width: 48rem) {
    grid-template-columns: 300px 1fr;
  }

  @media (min-width: 64rem) {
    grid-template-columns: repeat(8, 1fr);    
  }

  &--no-photo {
    grid-template-columns: 1fr;
  }
}

.past-card__photo {
  display: block;
  width: 100%;
  height: 100%;
  min-height: 0;
  aspect-ratio: 16 / 9;
  max-height: 14rem;
  object-fit: cover;
  object-position: top;

  @media (min-width: 48rem) {
    aspect-ratio: auto;
    min-height: 10rem;
  }

  @media (min-width: 64rem) {
    grid-column: span 2;
  }
}

.past-card__body {
  display: grid;
  gap: var(--space-2);
  align-content: start;
  min-width: 0;
  padding: var(--space-4);

  @media (min-width: 48rem) {
    padding: var(--space-4);
  }

  @media (min-width: 64rem) {
    grid-column: span 6;

    .past-card--no-photo & {
      grid-column: auto;
    }
  }
}

.past-card__title {
  font-size: 1.25rem;
  overflow-wrap: anywhere;
  color: var(--color-title);
}

.past-card__winner {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: center;
}

.past-card__crown {
  display: grid;
  place-items: center;
  width: 2rem;
  height: 2rem;
  color: var(--color-on-accent);
  background-color: var(--color-highlight);
  border-radius: var(--radius-pill);
}

.past-card__name {
  font-family: var(--font-display);
  overflow-wrap: anywhere;
}
</style>
