<script setup lang="ts">
import type { RevealBand } from '~/composables/useRunwayResults'

const props = withDefaults(defineProps<{
  /** The bands of the group category; `place` 1 = winner (both are 1 on a draw) */
  bands: RevealBand[]
  /** Plays the reveal when the component mounts; without it the final state is shown at once */
  animate?: boolean
  /**
   * Final layout after the Top 3 reveal: the losing band collapses and the winner(s) take the
   * full width. Changing it while mounted is animated; it also stops a reveal still running.
   */
  compact?: boolean
}>(), { animate: true, compact: false })

/** The reveal has finished (the jury's button appears after it) */
const emit = defineEmits<{ done: [] }>()

// Timeline of the reveal (ms from mount), same effect as the Top 3 reveal
const ROULETTE_START_MS = 500 // 0.5-4s: the cards light up alternately, slowing down
const ROULETTE_END_MS = 4000 // the winner is revealed
const CONFETTI_AT_MS = 4400
const DONE_AT_MS = 5500
const TIE_REVEAL_MS = 500 // on a draw there is no roulette: both win at once
const TIE_DONE_MS = 1800

const { launch: launchConfetti } = useConfetti()

const winners = computed(() => props.bands.filter(band => band.place === 1))
const tie = computed(() => winners.value.length > 1)
const resolved = ref(props.compact || !props.animate)
const litId = ref<string | null>(null)

// Compact with a single winner: its column takes everything, the other one collapses to nothing
// (fr tracks interpolate, so the grid animates the growth)
const columns = computed(() => props.compact
  ? props.bands.map(band => (band.place === 1 ? '1fr' : '0fr')).join(' ')
  : props.bands.map(() => '1fr').join(' '))
const solo = computed(() => props.compact && !tie.value)

const timers: ReturnType<typeof setTimeout>[] = []

function later(callback: () => void, ms: number): void {
  timers.push(setTimeout(callback, ms))
}

function clearTimers(): void {
  timers.forEach(clearTimeout)
  timers.length = 0
}

// Lights the other card (never the same twice in a row), then schedules the next one a bit slower
function spin(elapsed: number): void {
  if (elapsed >= ROULETTE_END_MS - ROULETTE_START_MS) return
  const others = props.bands.filter(band => band.id !== litId.value)
  litId.value = others[Math.floor(Math.random() * others.length)]?.id ?? null
  const wait = 80 + (elapsed / (ROULETTE_END_MS - ROULETTE_START_MS)) ** 2 * 420
  later(() => spin(elapsed + wait), wait)
}

function reveal(): void {
  litId.value = null
  resolved.value = true
}

// The jury moved on while the roulette was still running (another screen): jump to the final state
watch(() => props.compact, (compact) => {
  if (!compact) return
  clearTimers()
  reveal()
})

onMounted(() => {
  if (props.compact || !props.animate) return

  if (props.bands.length < 2 || window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    reveal()
    emit('done')
    return
  }

  if (tie.value) {
    later(() => {
      reveal()
      launchConfetti()
    }, TIE_REVEAL_MS)
    later(() => emit('done'), TIE_DONE_MS)
    return
  }

  later(() => spin(0), ROULETTE_START_MS)
  later(reveal, ROULETTE_END_MS)
  later(launchConfetti, CONFETTI_AT_MS)
  later(() => emit('done'), DONE_AT_MS)
})

onBeforeUnmount(clearTimers)
</script>

<template>
  <div
    class="band-reveal"
    :class="{ 'band-reveal--compact': compact, 'band-reveal--solo': solo }"
    :style="{ gridTemplateColumns: columns }"
    role="group"
    :aria-label="tie ? 'Bandas ganadoras' : 'Banda ganadora'"
  >
    <figure
      v-for="band in bands"
      :key="band.id"
      class="band-reveal__card"
      :class="{
        'band-reveal__card--lit': litId === band.id,
        'band-reveal__card--winner': resolved && band.place === 1,
        'band-reveal__card--dim': resolved && band.place !== 1 && !compact,
        'band-reveal__card--gone': compact && band.place !== 1,
      }"
      :aria-hidden="compact && band.place !== 1 ? 'true' : undefined"
    >
      <img class="band-reveal__photo" :src="band.image_url" :alt="compact && band.place !== 1 ? '' : `Foto de la banda ${band.name}`">
      <span v-if="resolved && band.place === 1" class="band-reveal__crown" aria-hidden="true">♛</span>
      <figcaption class="band-reveal__caption">
        <span class="band-reveal__name">{{ band.name }}</span>
        <span v-if="resolved && band.place === 1" class="band-reveal__label" role="status">
          {{ tie ? '¡Banda ganadora (empate)!' : '¡Banda ganadora!' }}
        </span>
      </figcaption>
    </figure>
  </div>
</template>

<style scoped lang="scss">
$move-ms: 0.8s;

.band-reveal {
  display: grid;
  gap: var(--space-3);
  width: 100%;
  max-width: 44rem;
  margin-inline: auto;
  transition: max-width $move-ms ease-in-out, grid-template-columns $move-ms ease-in-out, column-gap $move-ms ease-in-out;

  @media (min-width: 48rem) {
    gap: var(--space-5);
  }

  // After the Top 3 reveal: the winning band(s) use the whole width, like the three columns of the Top 3
  &--compact {
    max-width: 100%;
  }

  // The collapsed band leaves no gap behind
  &--solo {
    column-gap: 0;
  }
}

.band-reveal__card {
  position: relative;
  min-width: 0;
  margin: 0;
  overflow: hidden;
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);
  transition: border-color 0.1s ease-out, box-shadow 0.1s ease-out, opacity $move-ms ease-in-out, transform $move-ms cubic-bezier(0.34, 1.3, 0.64, 1);

  // Roulette highlight
  &--lit {
    z-index: 1;
    border-color: var(--color-highlight);
    box-shadow: var(--shadow-raised), var(--glow-primary-strong);
  }

  &--winner {
    z-index: 1;
    border-color: var(--color-highlight);
    box-shadow: var(--shadow-raised), var(--glow-primary);
    transform: scale(1.04);
  }

  // The losing band stays visible but steps back
  &--dim {
    opacity: 0.5;
    transform: scale(0.96);
  }

  // Collapsed: fades out while its column shrinks to nothing
  &--gone {
    pointer-events: none;
    border-color: transparent;
    box-shadow: none;
    opacity: 0;
    transform: scale(0.9);
  }
}

// At full width the winner needs no extra zoom, it would overflow the page
.band-reveal--compact .band-reveal__card--winner {
  transform: none;
}

.band-reveal__photo {
  display: block;
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
}

.band-reveal__caption {
  display: grid;
  gap: var(--space-1);
  padding: var(--space-3);
  text-align: center;
}

.band-reveal__name {
  overflow: hidden;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.band-reveal__label {
  font-family: var(--font-display);
  color: var(--color-title);
}

.band-reveal__crown {
  position: absolute;
  top: var(--space-2);
  right: var(--space-2);
  display: grid;
  place-items: center;
  width: 2.5rem;
  height: 2.5rem;
  font-size: 1.5rem;
  line-height: 1;
  color: var(--color-on-accent);
  background-color: var(--color-highlight);
  border-radius: var(--radius-pill);
  box-shadow: var(--shadow-card);
}

@media (prefers-reduced-motion: reduce) {
  .band-reveal,
  .band-reveal__card {
    transition: none;
  }
}
</style>
