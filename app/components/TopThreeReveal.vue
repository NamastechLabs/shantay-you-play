<script setup lang="ts">
defineProps<{
  queens: RunwayQueen[]
}>()

// The reveal itself (blackout, spotlights, winner) is `RevealStage`; this is the podium it leaves on the page
const PLACE_LABELS: Record<number, string> = { 1: '¡Ganadora de la semana!', 2: '2.º puesto', 3: '3.er puesto' }
</script>

<template>
  <div class="podium" role="group" aria-label="Top 3 de la semana">
    <figure
      v-for="queen in queens"
      :key="queen.id"
      class="podium__card"
      :class="`podium__card--place-${queen.place}`"
    >
      <img class="podium__photo" :src="queen.image_url" :alt="`Look de ${queen.name}`">
      <span v-if="queen.place === 1" class="podium__crown" aria-hidden="true">♛</span>
      <figcaption class="podium__caption">
        <span class="podium__name">{{ queen.name }}</span>
        <span class="podium__label">{{ PLACE_LABELS[queen.place] }}</span>
      </figcaption>
    </figure>
  </div>
</template>

<style scoped lang="scss">
// Phones: the winner on top, second and third side by side under her.
// From tablet: second | winner | third on one row.
.podium {
  --podium-gap: var(--space-3);

  display: grid;
  grid-template-areas:
    'winner winner'
    'second third';
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--podium-gap);
  width: 100%;

  @media (min-width: 48rem) {
    --podium-gap: var(--space-5);

    grid-template-areas: 'second winner third';
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

.podium__card {
  position: relative;
  min-width: 0;
  margin: 0;
  overflow: hidden;
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);

  &--place-1 {
    grid-area: winner;
    justify-self: center;
    width: min(78%, 18rem);
    border-color: var(--color-highlight);
    box-shadow: var(--shadow-raised), var(--glow-primary);

    @media (min-width: 48rem) {
      width: 100%;
    }
  }

  &--place-2 {
    grid-area: second;
  }

  &--place-3 {
    grid-area: third;
  }
}

.podium__photo {
  display: block;
  width: 100%;
  aspect-ratio: 3 / 4;
  object-fit: cover;
}

.podium__caption {
  display: grid;
  gap: var(--space-1);
  padding: var(--space-3);
  text-align: center;
}

.podium__name {
  overflow: hidden;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.podium__label {
  font-family: var(--font-display);
  color: var(--color-title);
}

.podium__crown {
  position: absolute;
  top: var(--space-3);
  right: var(--space-3);
  display: grid;
  place-items: center;
  width: 3rem;
  height: 3rem;
  font-size: 1.75rem;
  line-height: 1;
  color: var(--color-on-accent);
  background-color: var(--color-highlight);
  border-radius: var(--radius-pill);
  box-shadow: var(--shadow-card);
}
</style>
