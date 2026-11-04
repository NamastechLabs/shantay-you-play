<script setup lang="ts">
const props = defineProps<{
  queens: RunwayQueen[]
}>()

// Timeline of the reveal (ms from mount)
const ROULETTE_START_MS = 500 // 0.5-5s: random cards light up like a roulette, slowing down
const ROULETTE_END_MS = 5000
const FADE_END_MS = 7000 // 5-7s: the cards fade out
const CONFETTI_AT_MS = 7700 // 7-7.5s the winner grows from 50% to 100% in the centre; confetti at 7.7s
const RUNNERS_UP_AT_MS = 9000 // 9s: second (left) and third (right) fade in, 600ms

// Phones and tablet portrait: one single card runs the roulette (its photo and name change), then shows the winner.
// Same offsets as the wide timeline: confetti 0.7s after the winner, second and third 2s after it.
const COMPACT_QUERY = '(max-width: 47.99rem)'

const lineup = ref<RunwayQueen[]>([])
const litId = ref<string | null>(null)
const fading = ref(false)
const compact = ref(false)
const winnerIn = ref(false)
const runnersUpIn = ref(false)
const confetti = ref<HTMLCanvasElement | null>(null)
const confettiOn = ref(false)

const winner = computed(() => props.queens.find(queen => queen.place === 1) ?? null)
const second = computed(() => props.queens.find(queen => queen.place === 2) ?? null)
const third = computed(() => props.queens.find(queen => queen.place === 3) ?? null)

// The card shown in compact mode: whoever the roulette is on, then the winner
const shown = computed(() => {
  if (winnerIn.value) return winner.value
  return lineup.value.find(queen => queen.id === litId.value) ?? lineup.value[0] ?? null
})

const timers: ReturnType<typeof setTimeout>[] = []
let frame = 0

function later(callback: () => void, ms: number): void {
  timers.push(setTimeout(callback, ms))
}

function shuffle<T>(items: readonly T[]): T[] {
  const result = [...items]
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[result[i], result[j]] = [result[j]!, result[i]!]
  }
  return result
}

// Lights a random card (never the same twice in a row), then schedules the next one a bit slower
function spin(elapsed: number): void {
  if (elapsed >= ROULETTE_END_MS - ROULETTE_START_MS) return
  const others = lineup.value.filter(queen => queen.id !== litId.value)
  litId.value = others[Math.floor(Math.random() * others.length)]?.id ?? null
  const wait = 80 + (elapsed / (ROULETTE_END_MS - ROULETTE_START_MS)) ** 2 * 420
  later(() => spin(elapsed + wait), wait)
}

// The random order is client-only so server and client markup match (no hydration mismatch)
onMounted(() => {
  lineup.value = shuffle(props.queens)
  compact.value = window.matchMedia(COMPACT_QUERY).matches
  // So the single card never flashes empty while the roulette swaps photos
  if (compact.value) props.queens.forEach((queen) => { new Image().src = queen.image_url })

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    fading.value = true
    winnerIn.value = true
    runnersUpIn.value = true
    return
  }

  later(() => spin(0), ROULETTE_START_MS)

  // Wide: the roulette lights the cards, they fade out, then the winner appears. Compact: the winner replaces the roulette card.
  const winnerAt = compact.value ? ROULETTE_END_MS : FADE_END_MS
  later(() => {
    litId.value = null
    fading.value = !compact.value
  }, ROULETTE_END_MS)
  later(() => {
    winnerIn.value = true
  }, winnerAt)
  later(launchConfetti, winnerAt + (CONFETTI_AT_MS - FADE_END_MS))
  later(() => {
    runnersUpIn.value = true
  }, winnerAt + (RUNNERS_UP_AT_MS - FADE_END_MS))
})

onBeforeUnmount(() => {
  timers.forEach(clearTimeout)
  cancelAnimationFrame(frame)
})

// --- Confetti: a small canvas particle system, no dependency -------------------
interface Piece {
  x: number
  y: number
  vx: number
  vy: number
  size: number
  angle: number
  spin: number
  color: string
  life: number
}

async function launchConfetti(): Promise<void> {
  confettiOn.value = true
  await nextTick()
  const canvas = confetti.value
  const context = canvas?.getContext('2d')
  if (!canvas || !context) return

  const ratio = window.devicePixelRatio || 1
  const width = window.innerWidth
  const height = window.innerHeight
  canvas.width = width * ratio
  canvas.height = height * ratio
  context.scale(ratio, ratio)

  const style = getComputedStyle(document.documentElement)
  const colors = ['--color-primary', '--color-accent', '--color-highlight', '--color-title']
    .map(name => style.getPropertyValue(name).trim())
    .filter(Boolean)

  const piece = (x: number, y: number, vx: number, vy: number): Piece => ({
    x,
    y,
    vx,
    vy,
    size: 6 + Math.random() * 8,
    angle: Math.random() * Math.PI * 2,
    spin: (Math.random() - 0.5) * 0.3,
    color: colors[Math.floor(Math.random() * colors.length)] ?? '#fff',
    life: 0,
  })

  // Two cannons from the bottom corners, plus a light rain from the top
  const pieces: Piece[] = []
  for (let i = 0; i < 90; i++) {
    const speed = 12 + Math.random() * 12
    const spread = (Math.random() - 0.5) * 0.7
    pieces.push(piece(0, height, speed * Math.sin(0.9 + spread), -speed * Math.cos(0.9 + spread)))
    pieces.push(piece(width, height, -speed * Math.sin(0.9 + spread), -speed * Math.cos(0.9 + spread)))
  }
  for (let i = 0; i < 60; i++) {
    pieces.push(piece(Math.random() * width, -20 - Math.random() * height * 0.5, (Math.random() - 0.5) * 2, 2 + Math.random() * 3))
  }

  const started = performance.now()
  const draw = (now: number): void => {
    const elapsed = now - started
    context.clearRect(0, 0, width, height)
    for (const p of pieces) {
      p.vy += 0.28
      p.vx *= 0.99
      p.x += p.vx
      p.y += p.vy
      p.angle += p.spin
      p.life += 1
      context.save()
      context.globalAlpha = Math.max(0, Math.min(1, (4500 - elapsed) / 1000))
      context.translate(p.x, p.y)
      context.rotate(p.angle)
      context.fillStyle = p.color
      context.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2)
      context.restore()
    }
    if (elapsed < 4500) frame = requestAnimationFrame(draw)
    else confettiOn.value = false
  }
  frame = requestAnimationFrame(draw)
}
</script>

<template>
  <div
    class="reveal"
    :style="{ '--reveal-count': lineup.length || queens.length }"
    role="group"
    aria-label="Top 3 de la semana"
  >
    <!-- Phones: one card that runs the roulette, then becomes the winner; second and third go below -->
    <template v-if="compact">
      <figure v-if="shown" class="reveal__card reveal__single" :class="{ 'reveal__single--winner': winnerIn }">
        <img class="reveal__photo" :src="shown.image_url" :alt="`Look de ${shown.name}`">
        <span v-if="winnerIn" class="reveal__crown" aria-hidden="true">♛</span>
        <figcaption class="reveal__caption">
          <span class="reveal__name">{{ shown.name }}</span>
          <span v-if="winnerIn" class="reveal__label" role="status">¡Ganadora de la semana!</span>
        </figcaption>
      </figure>

      <div class="reveal__row" :class="{ 'reveal__row--in': runnersUpIn }" :aria-hidden="runnersUpIn ? undefined : 'true'">
        <figure v-for="(queen, i) in [second, third]" :key="queen?.id ?? i" class="reveal__card reveal__mini">
          <template v-if="queen">
            <img class="reveal__photo" :src="queen.image_url" :alt="runnersUpIn ? `Look de ${queen.name}` : ''">
            <figcaption class="reveal__caption">
              <span class="reveal__name">{{ queen.name }}</span>
              <span class="reveal__label">{{ queen.place === 2 ? '2.º puesto' : '3.er puesto' }}</span>
            </figcaption>
          </template>
        </figure>
      </div>
    </template>

    <template v-else>
    <!-- Phase 1 and 2: the three finalists, lit one at a time, then faded out -->
    <div
      class="reveal__grid"
      :class="{ 'reveal__grid--fading': fading, 'reveal__grid--gone': winnerIn }"
      :aria-hidden="winnerIn ? 'true' : undefined"
    >
      <figure
        v-for="queen in lineup"
        :key="queen.id"
        class="reveal__card"
        :class="{ 'reveal__card--lit': litId === queen.id }"
      >
        <img class="reveal__photo" :src="queen.image_url" :alt="`Look de ${queen.name}`">
        <figcaption class="reveal__caption">
          <span class="reveal__name">{{ queen.name }}</span>
        </figcaption>
      </figure>
    </div>

    <!-- Phase 3: the winner, centred, grows from 50% to 100% -->
    <figure v-if="winner" class="reveal__card reveal__winner" :class="{ 'reveal__winner--in': winnerIn }">
      <img class="reveal__photo" :src="winner.image_url" :alt="winnerIn ? `Look de ${winner.name}` : ''">
      <span class="reveal__crown" aria-hidden="true">♛</span>
      <figcaption class="reveal__caption">
        <span class="reveal__name">{{ winner.name }}</span>
        <span v-if="winnerIn" class="reveal__label" role="status">¡Ganadora de la semana!</span>
      </figcaption>
    </figure>

    <!-- Phase 4: second on the left and third on the right of the winner -->
    <div class="reveal__runners" :class="{ 'reveal__runners--in': runnersUpIn }" :aria-hidden="runnersUpIn ? undefined : 'true'">
      <figure v-if="second" class="reveal__card reveal__runner reveal__runner--second">
        <img class="reveal__photo" :src="second.image_url" :alt="runnersUpIn ? `Look de ${second.name}` : ''">
        <figcaption class="reveal__caption">
          <span class="reveal__name">{{ second.name }}</span>
          <span class="reveal__label">2.º puesto</span>
        </figcaption>
      </figure>
      <figure v-if="third" class="reveal__card reveal__runner reveal__runner--third">
        <img class="reveal__photo" :src="third.image_url" :alt="runnersUpIn ? `Look de ${third.name}` : ''">
        <figcaption class="reveal__caption">
          <span class="reveal__name">{{ third.name }}</span>
          <span class="reveal__label">3.er puesto</span>
        </figcaption>
      </figure>
    </div>

    </template>

    <canvas v-if="confettiOn" ref="confetti" class="reveal__confetti" aria-hidden="true" />
  </div>
</template>

<style scoped lang="scss">
.reveal {
  --reveal-gap: var(--space-3);
  // The podium always has 3 slots: second | winner | third
  --reveal-slots: 3;

  position: relative;
  width: 100%;

  @media (min-width: 48rem) {
    --reveal-gap: var(--space-5);
  }
}

.reveal__grid {
  display: grid;
  grid-template-columns: repeat(var(--reveal-count), minmax(0, 1fr));
  gap: var(--reveal-gap);
  opacity: 1;

  &--fading {
    opacity: 0;
    transition: opacity 2s ease-in-out;
  }

  // Once faded out it stays in the layout (so nothing jumps) but can't be seen or reached
  &--gone {
    visibility: hidden;
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
  transition: border-color 0.1s ease-out, box-shadow 0.1s ease-out;

  // Roulette highlight
  &--lit {
    z-index: 1;
    border-color: var(--color-highlight);
    box-shadow: var(--shadow-raised), var(--glow-primary-strong);
  }
}

// Same size as one of the original cards, centred over the (hidden) grid
.reveal__winner {
  position: absolute;
  top: 50%;
  left: 50%;
  width: calc((100% - (var(--reveal-slots) - 1) * var(--reveal-gap)) / var(--reveal-slots));
  min-width: min(100%, 11rem);
  border-color: var(--color-highlight);
  box-shadow: var(--shadow-raised), var(--glow-primary);
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.5);
  pointer-events: none;

  &--in {
    opacity: 1;
    transform: translate(-50%, -50%) scale(1);
    transition: opacity 0.5s ease-out, transform 0.5s cubic-bezier(0.34, 1.3, 0.64, 1);
  }
}

// Over the hidden grid: second in the left slot, third in the right slot (the winner covers the middle one)
.reveal__runners {
  position: absolute;
  inset: 0;
  display: grid;
  grid-template-columns: repeat(var(--reveal-slots), minmax(0, 1fr));
  gap: var(--reveal-gap);
  align-items: start;
  visibility: hidden;
  opacity: 0;
  pointer-events: none;

  &--in {
    visibility: visible;
    opacity: 1;
    transition: opacity 0.6s ease-in;
  }
}

.reveal__runner--second {
  grid-column: 1;
}

.reveal__runner--third {
  grid-column: 3;
}

// Compact: the single roulette / winner card, centred, and the two runners-up in a row below it
.reveal__single {
  width: min(78%, 18rem);
  margin-inline: auto;

  &--winner {
    border-color: var(--color-highlight);
    box-shadow: var(--shadow-raised), var(--glow-primary);
    animation: reveal-pop 0.5s cubic-bezier(0.34, 1.3, 0.64, 1);
  }
}

@keyframes reveal-pop {
  from {
    opacity: 0.4;
    transform: scale(0.5);
  }

  to {
    opacity: 1;
    transform: scale(1);
  }
}

// Space is reserved from the start so the page doesn't jump when they appear
.reveal__row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--reveal-gap);
  margin-top: var(--space-4);
  visibility: hidden;
  opacity: 0;

  &--in {
    visibility: visible;
    opacity: 1;
    transition: opacity 0.6s ease-in;
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
}

.reveal__confetti {
  position: fixed;
  inset: 0;
  z-index: 10;
  width: 100vw;
  height: 100vh;
  pointer-events: none;
}

@media (prefers-reduced-motion: reduce) {
  .reveal__single--winner {
    animation: none;
  }

  .reveal__grid,
  .reveal__runners,
  .reveal__row,
  .reveal__card,
  .reveal__winner {
    transition: none;
  }
}
</style>
