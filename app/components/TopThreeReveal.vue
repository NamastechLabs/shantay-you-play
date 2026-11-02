<script setup lang="ts">
const props = withDefaults(defineProps<{
  queens: RunwayQueen[]
  /** How long the three queens are shown together before the winner is crowned */
  delayMs?: number
}>(), { delayMs: 5000 })

const lineup = ref<RunwayQueen[]>([])
const crowned = ref(false)
let timer: ReturnType<typeof setTimeout> | undefined

function shuffle<T>(items: readonly T[]): T[] {
  const result = [...items]
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[result[i], result[j]] = [result[j]!, result[i]!]
  }
  return result
}

// The random order is client-only so server and client markup match (no hydration mismatch)
onMounted(() => {
  lineup.value = shuffle(props.queens)
  timer = setTimeout(() => {
    crowned.value = true
  }, props.delayMs)
})

onBeforeUnmount(() => clearTimeout(timer))

// Animating the track sizes makes the winner grow to the centre while the others collapse
const columns = computed(() =>
  lineup.value.map(queen => (crowned.value && queen.place !== 1 ? '0fr' : '1fr')).join(' '),
)
</script>

<template>
  <div
    class="reveal"
    :class="{ 'reveal--crowned': crowned }"
    :style="{ gridTemplateColumns: columns }"
    role="group"
    aria-label="Top 3 de la semana"
  >
    <figure
      v-for="queen in lineup"
      :key="queen.id"
      class="reveal__card"
      :class="{ 'reveal__card--winner': crowned && queen.place === 1, 'reveal__card--out': crowned && queen.place !== 1 }"
      :aria-hidden="crowned && queen.place !== 1 ? 'true' : undefined"
    >
      <img class="reveal__photo" :src="queen.image_url" :alt="`Look de ${queen.name}`">
      <span v-if="queen.place === 1" class="reveal__crown" aria-hidden="true">♛</span>
      <figcaption class="reveal__caption">
        <span class="reveal__name">{{ queen.name }}</span>
        <span v-if="crowned && queen.place === 1" class="reveal__label" role="status">¡Ganadora de la semana!</span>
      </figcaption>
    </figure>
  </div>
</template>

<style scoped lang="scss">
.reveal {
  display: grid;
  gap: var(--space-3);
  width: 100%;
  transition: grid-template-columns 1s ease-in-out, column-gap 1s ease-in-out;

  &--crowned {
    column-gap: 0;
  }

  @media (min-width: 48rem) {
    gap: var(--space-5);
  }
}

.reveal__card {
  position: relative;
  min-width: 0;
  margin: 0;
  overflow: hidden;
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);
  transition: opacity 0.6s ease, border-color 0.6s ease, box-shadow 0.6s ease;

  // The winner is capped and centred inside its (now full-width) track
  &--winner {
    width: 100%;
    max-width: 34rem;
    margin-inline: auto;
    border-color: var(--color-highlight);
    box-shadow: var(--shadow-raised), var(--glow-primary);
  }

  &--out {
    pointer-events: none;
    opacity: 0;
  }
}

.reveal__photo {
  display: block;
  width: 100%;
  aspect-ratio: 3 / 4;
  object-fit: cover;
}

.reveal__caption {
  display: grid;
  gap: var(--space-1);
  padding: var(--space-3);
  text-align: center;
}

.reveal__name {
  overflow: hidden;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.reveal__label {
  font-family: var(--font-display);
  color: var(--color-title);
}

// Only the winner has a crown; it pops in once the card has taken the stage
.reveal__crown {
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
  opacity: 0;
  transform: scale(0.4) rotate(-20deg);
  transition: opacity 0.4s ease 0.9s, transform 0.5s cubic-bezier(0.34, 1.56, 0.64, 1) 0.9s;

  .reveal--crowned & {
    opacity: 1;
    transform: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .reveal,
  .reveal__card,
  .reveal__crown {
    transition: none;
  }
}
</style>
