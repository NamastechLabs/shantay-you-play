<script lang="ts">
/** A band or a queen in the reveal; `place` 1 = winner (both bands are 1 on a draw) */
export interface RevealItem {
  id: string
  name: string
  url: string
  place: number
}
</script>

<script setup lang="ts">
/**
 * Full-screen reveal of the bands or of the Top 3: blackout, spotlights, every contender lit one by one in
 * random order and with a random effect (without their place), a suspense line, the winner growing from
 * small to big with confetti and sound, and (queens) second and third at the end. Built from live data, themed
 * through the CSS tokens. Emits `close` when it ends, is skipped, or the viewer leaves it.
 */
type Step
  = | { key: string, kind: 'dark', ms: number }
    | { key: string, kind: 'item', ms: number, item: RevealItem }
    | { key: string, kind: 'suspense', ms: number }
    | { key: string, kind: 'fade', ms: number }
    | { key: string, kind: 'winner', ms: number }

const props = defineProps<{
  kind: 'bands' | 'queens'
  items: RevealItem[]
}>()
const emit = defineEmits<{ close: [] }>()

const DARK_MS = 2400
const ITEM_MS = 3200
const ITEM_IN_S = 0.7
const ITEM_OUT_S = 0.5
const NAME_FADE_IN_S = 0.4
const SUSPENSE_WORD_S = 0.5
const SUSPENSE_HOLD_MS = 1600
const FADE_MS = 1100
/** The winner stays on screen this long; second and third come in after `RUNNERS_UP_DELAY_S` */
const WINNER_MS = 7000
const RUNNERS_UP_DELAY_S = 3.2
const SOUND_AT_MS = 500
const CONFETTI_AT_MS = 900
const LEAVE_MS = 700

const reduced = import.meta.client && window.matchMedia('(prefers-reduced-motion: reduce)').matches
const { launch: launchConfetti } = useConfetti()
const sound = useRevealSound()

const winners = computed(() => props.items.filter(item => item.place === 1))
const runnersUp = computed(() => (props.kind === 'queens'
  ? props.items.filter(item => item.place !== 1).sort((a, b) => a.place - b.place)
  : []))
const tie = computed(() => winners.value.length > 1)
const winnerNames = computed(() => winners.value.map(item => item.name).join(' y '))

const suspenseWords = computed(() => {
  if (props.kind === 'queens') return ['La', 'reina', 'de', 'la', 'semana', 'es…']
  return tie.value ? ['Las', 'bandas', 'ganadoras', 'son…'] : ['La', 'banda', 'ganadora', 'es…']
})
const suspenseMs = computed(() => Math.round(suspenseWords.value.length * SUSPENSE_WORD_S * 1000 + SUSPENSE_HOLD_MS))

/** The random order is client-only so server and client markup match (no hydration mismatch) */
const order = ref<RevealItem[]>([])
const steps = computed<Step[]>(() => [
  { key: 'dark', kind: 'dark', ms: DARK_MS },
  ...order.value.map((item): Step => ({ key: `item-${item.id}`, kind: 'item', ms: ITEM_MS, item })),
  { key: 'suspense', kind: 'suspense', ms: suspenseMs.value },
  { key: 'fade', kind: 'fade', ms: FADE_MS },
  { key: 'winner', kind: 'winner', ms: WINNER_MS },
])

const started = ref(false)
const leaving = ref(false)
const index = ref(0)
const current = computed(() => steps.value[index.value] ?? steps.value[0]!)

const timers: ReturnType<typeof setTimeout>[] = []
function later(callback: () => void, ms: number): void {
  timers.push(setTimeout(callback, ms))
}

function clearTimers(): void {
  timers.forEach(clearTimeout)
  timers.length = 0
}

/** Natural end: the stage fades out, then the page comes back */
function finish(): void {
  leaving.value = true
  later(() => emit('close'), LEAVE_MS)
}

function advance(): void {
  if (index.value < steps.value.length - 1) index.value += 1
  else finish()
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') emit('close')
}

function shuffle<T>(list: readonly T[]): T[] {
  const result = [...list]
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[result[i], result[j]] = [result[j]!, result[i]!]
  }
  return result
}

watch(index, () => {
  if (reduced || !started.value) return
  clearTimers()
  later(advance, current.value.ms)
  if (current.value.kind === 'winner') {
    later(() => sound.play(), SOUND_AT_MS)
    later(launchConfetti, CONFETTI_AT_MS)
  }
})

onMounted(() => {
  document.documentElement.style.overflow = 'hidden'
  window.addEventListener('keydown', onKeydown)
  // Every photo is downloaded up front so nothing pops in half loaded
  for (const item of props.items) new Image().src = item.url
  closeButton.value?.focus()

  order.value = shuffle(props.items)
  started.value = true
  if (!reduced) later(advance, current.value.ms)
})

onBeforeUnmount(() => {
  clearTimers()
  document.documentElement.style.overflow = ''
  window.removeEventListener('keydown', onKeydown)
})

const closeButton = ref<HTMLButtonElement | null>(null)

// --- Effects ------------------------------------------------------------------------------
// An item is one animation: out of place (and invisible) -> in place -> in place -> invisible. The way in is
// drawn at random from this list, never the same twice in a row. Every property keeps one unit (vw, vh, %, deg)
// or the browser cannot interpolate it. Only transform, opacity and clip-path move (cheap on phones).

const CLIP_REST = 'inset(-12% -12% -12% -12%)' // a negative inset leaves room for the glow around the photo
const REST = { x: '0vw', y: '0vh', scale: 1, rotate: 0, rotateY: 0, clipPath: CLIP_REST } as const
type PoseKey = keyof typeof REST
type Pose = Partial<Record<PoseKey, string | number>>
interface Effect { pose: Pose, flash?: boolean }

const EFFECTS: Effect[] = [
  { pose: {} }, // fades in
  { pose: { y: '45vh' } }, // slides up from the bottom
  { pose: { y: '-45vh' } }, // slides down from the top
  { pose: { x: '70vw' } }, // slides in from the right
  { pose: { x: '-70vw' } }, // slides in from the left
  { pose: { scale: 0.25 } }, // zooms from small to big
  { pose: { scale: 0.4, rotate: -30 } }, // spins in
  { pose: { rotateY: 90 } }, // flips in like a card
  { pose: { clipPath: 'inset(-12% 50% -12% 50%)' } }, // opens like a curtain
  { pose: { scale: 1.5 }, flash: true }, // lands with a flash
]

let lastEffect = -1
function pickEffect(): Effect {
  let pick = Math.floor(Math.random() * EFFECTS.length)
  if (pick === lastEffect) pick = (pick + 1) % EFFECTS.length
  lastEffect = pick
  return EFFECTS[pick]!
}

function buildItemMotion() {
  const effect = pickEffect()
  const from = { ...REST, ...effect.pose, opacity: 0 }
  const rest = { ...REST, opacity: 1 }
  const to = { ...REST, opacity: 0, scale: 0.94 }
  const keys = [...Object.keys(REST), 'opacity'] as (PoseKey | 'opacity')[]
  const duration = ITEM_MS / 1000

  return {
    flash: !!effect.flash,
    photo: {
      initial: from,
      animate: Object.fromEntries(keys.map(key => [key, [from[key], rest[key], rest[key], to[key]]])),
      transition: {
        duration,
        times: [0, ITEM_IN_S / duration, 1 - ITEM_OUT_S / duration, 1],
        ease: ['easeOut', 'linear', 'easeIn'] as ('easeOut' | 'linear' | 'easeIn')[],
      },
    },
    name: {
      initial: { opacity: 0, y: 24 },
      animate: { opacity: [0, 0, 1, 1, 0], y: [24, 24, 0, 0, -10] },
      transition: {
        duration,
        times: [0, ITEM_IN_S / duration, (ITEM_IN_S + NAME_FADE_IN_S) / duration, 1 - ITEM_OUT_S / duration, 1],
        ease: ['linear', 'easeOut', 'linear', 'easeIn'] as ('linear' | 'easeOut' | 'easeIn')[],
      },
    },
  }
}

/** One draw per item: the template runs again on every refresh and must not redraw */
const itemMotions = new Map<string, ReturnType<typeof buildItemMotion>>()
function itemMotion(key: string) {
  let motion = itemMotions.get(key)
  if (!motion) {
    motion = buildItemMotion()
    itemMotions.set(key, motion)
  }
  return motion
}

/** Entrance of an element: it rises and fades in; with reduced motion it is simply there */
function enter(delay = 0) {
  return {
    initial: reduced ? false : { opacity: 0, y: 24 },
    animate: { opacity: 1, y: 0 },
    transition: { type: 'spring' as const, stiffness: 110, damping: 16, delay },
  }
}

const winnerPhoto = {
  initial: reduced ? false : { opacity: 0, scale: 0.3 },
  animate: { opacity: 1, scale: 1 },
  transition: { type: 'spring' as const, stiffness: 80, damping: 13, delay: 0.3 },
}

function placeLabel(place: number): string {
  return place === 2 ? '2.º puesto' : '3.er puesto'
}
</script>

<template>
  <div
    class="reveal-stage"
    :class="{
      'reveal-stage--static': reduced,
      'reveal-stage--leaving': leaving,
      'reveal-stage--lit': current.kind === 'item' || current.kind === 'winner',
    }"
    role="dialog"
    aria-modal="true"
    :aria-label="kind === 'bands' ? 'Revelación de la banda ganadora' : 'Revelación del Top 3'"
  >
    <!-- Spotlights: decoration, colored by the theme tokens -->
    <div v-if="!reduced" class="reveal-stage__beams" aria-hidden="true">
      <span v-for="n in 3" :key="n" class="reveal-stage__beam" :style="{ '--n': n }" />
      <span class="reveal-stage__pool" />
    </div>

    <button
      v-if="sound.available.value && !reduced"
      type="button"
      class="btn btn--secondary reveal-stage__sound"
      :aria-pressed="sound.muted.value"
      :aria-label="sound.muted.value ? 'Activar el sonido' : 'Silenciar el sonido'"
      @click="sound.toggleMuted()"
    >
      <span aria-hidden="true">{{ sound.muted.value ? '🔇' : '🔊' }}</span>
    </button>

    <button ref="closeButton" type="button" class="btn btn--secondary reveal-stage__close" @click="emit('close')">
      {{ reduced ? 'Cerrar' : 'Saltar' }}
    </button>

    <div v-if="started" class="reveal-stage__stage" aria-live="polite">
      <!-- Reduced motion: the result at once, nothing moves or advances by itself -->
      <section v-if="reduced" class="scene scene--winner">
        <h2 class="display scene__title">
          ¡Felicidragues, {{ winnerNames }}!
        </h2>
        <div class="scene__winners" :class="{ 'scene__winners--tie': tie }">
          <figure v-for="winner in winners" :key="winner.id" class="scene__winner">
            <div class="scene__frame scene__frame--winner">
              <div class="scene__photo">
                <img :src="winner.url" :alt="`${kind === 'bands' ? 'Foto de la banda' : 'Look de'} ${winner.name}`" draggable="false">
              </div>
            </div>
            <figcaption class="display scene__name">
              {{ winner.name }}
            </figcaption>
          </figure>
        </div>
        <div v-if="runnersUp.length" class="scene__runners">
          <figure v-for="queen in runnersUp" :key="queen.id" class="scene__runner">
            <div class="scene__frame scene__frame--runner">
              <div class="scene__photo">
                <img :src="queen.url" :alt="`Look de ${queen.name}`" draggable="false">
              </div>
            </div>
            <figcaption>
              <span class="scene__runner-name">{{ queen.name }}</span>
              <span class="scene__runner-place">{{ placeLabel(queen.place) }}</span>
            </figcaption>
          </figure>
        </div>
      </section>

      <section v-else :key="current.key" class="scene" :class="`scene--${current.kind}`">
        <!-- Blackout and spotlights, nothing on stage yet -->
        <template v-if="current.kind === 'dark'" />

        <!-- One contender, lit with a random effect; the place is not shown -->
        <template v-else-if="current.kind === 'item'">
          <span v-if="itemMotion(current.key).flash" class="scene__flash" aria-hidden="true" />
          <Motion as="p" class="kicker scene__kicker" v-bind="enter()">
            {{ kind === 'bands' ? 'Las bandas' : 'Top 3 de la semana' }}
          </Motion>
          <div class="scene__frame" :class="kind === 'bands' ? 'scene__frame--band' : 'scene__frame--queen'">
            <Motion as="div" class="scene__photo" v-bind="itemMotion(current.key).photo">
              <img :src="current.item.url" :alt="`${kind === 'bands' ? 'Foto de la banda' : 'Look de'} ${current.item.name}`" draggable="false">
            </Motion>
          </div>
          <Motion as="h2" class="display scene__name" v-bind="itemMotion(current.key).name">
            {{ current.item.name }}
          </Motion>
        </template>

        <!-- Suspense: the line appears word by word -->
        <template v-else-if="current.kind === 'suspense'">
          <h2 class="display scene__suspense" :style="{ '--out-delay': `${(current.ms - 600) / 1000}s` }">
            <Motion
              v-for="(word, position) in suspenseWords"
              :key="position"
              as="span"
              class="scene__word"
              :initial="{ opacity: 0, y: 14 }"
              :animate="{ opacity: 1, y: 0 }"
              :transition="{ duration: 0.45, delay: 0.2 + position * SUSPENSE_WORD_S }"
            >
              {{ word }}
            </Motion>
          </h2>
        </template>

        <!-- Everything out, a flash at the end -->
        <template v-else-if="current.kind === 'fade'">
          <span class="scene__flash scene__flash--late" aria-hidden="true" />
        </template>

        <!-- The winner: small to big, then second and third -->
        <template v-else>
          <Motion as="h2" class="display scene__title" v-bind="enter(0.1)">
            ¡Felicidragues, {{ winnerNames }}!
          </Motion>
          <div class="scene__winners" :class="{ 'scene__winners--tie': tie }">
            <figure v-for="winner in winners" :key="winner.id" class="scene__winner">
              <div class="scene__frame scene__frame--winner" :class="{ 'scene__frame--with-runners': runnersUp.length }">
                <Motion as="div" class="scene__photo" v-bind="winnerPhoto">
                  <img :src="winner.url" :alt="`${kind === 'bands' ? 'Foto de la banda' : 'Look de'} ${winner.name}`" draggable="false">
                  <span class="scene__crown" aria-hidden="true">♛</span>
                </Motion>
              </div>
              <Motion as="figcaption" class="display scene__name" v-bind="enter(0.9)">
                {{ winner.name }}
              </Motion>
            </figure>
          </div>
          <Motion v-if="runnersUp.length" as="div" class="scene__runners" v-bind="enter(RUNNERS_UP_DELAY_S)">
            <figure v-for="queen in runnersUp" :key="queen.id" class="scene__runner">
              <div class="scene__frame scene__frame--runner">
                <div class="scene__photo">
                  <img :src="queen.url" :alt="`Look de ${queen.name}`" draggable="false">
                </div>
              </div>
              <figcaption>
                <span class="scene__runner-name">{{ queen.name }}</span>
                <span class="scene__runner-place">{{ placeLabel(queen.place) }}</span>
              </figcaption>
            </figure>
          </Motion>
        </template>
      </section>
    </div>
  </div>
</template>

<style scoped lang="scss">
.reveal-stage {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: grid;
  overflow: hidden;
  color: var(--reveal-text);
  background: var(--reveal-stage);
  animation: stage-in 0.8s ease both;
}

.reveal-stage--static {
  overflow-y: auto;
}

.reveal-stage--leaving {
  animation: stage-out 0.7s ease-in both;
}

// --- Spotlights: transform and opacity only -------------------------------------------------
.reveal-stage__beams {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
}

.reveal-stage__beam {
  position: absolute;
  top: -6vh;
  left: calc(var(--n) * 25% - 12.5% - 25vw);
  width: 50vw;
  height: 120vh;
  background: linear-gradient(to bottom, var(--spotlight-beam), transparent 82%);
  clip-path: polygon(46% 0, 54% 0, 100% 100%, 0 100%);
  opacity: 0.35;
  transform-origin: 50% 0;
  transition: opacity 0.8s ease;
  animation: beam-sweep calc(5s + var(--n) * 1.3s) ease-in-out infinite alternate;
  animation-delay: calc(var(--n) * -1.7s);
}

// Once something is on stage the beams gather on it and shine brighter
.reveal-stage--lit .reveal-stage__beam {
  opacity: 0.6;
}

.reveal-stage__pool {
  position: absolute;
  right: -20vw;
  bottom: -24vh;
  left: -20vw;
  height: 60vh;
  background: radial-gradient(closest-side, var(--spotlight-beam), transparent);
  opacity: 0.4;
}

.reveal-stage__close {
  position: absolute;
  right: var(--space-4);
  bottom: var(--space-4);
  z-index: 3;
}

.reveal-stage__sound {
  position: absolute;
  top: var(--space-4);
  right: var(--space-4);
  z-index: 3;
}

.reveal-stage__stage {
  position: relative;
  display: grid;
  place-items: center;
  min-height: 0;
  padding: var(--space-6) var(--space-4) calc(var(--space-6) + var(--space-5));
}

.scene {
  position: relative;
  display: grid;
  gap: var(--space-3);
  justify-items: center;
  width: 100%;
  max-width: min(92vw, 44rem);
  text-align: center;
}

.reveal-stage--static .scene {
  margin-block: var(--space-5);
}

.scene__title {
  margin: 0;
  font-size: clamp(2rem, 9vw, 3.4rem);
  color: var(--reveal-text);
  text-shadow: var(--glow-primary);
}

.scene__name {
  margin: 0;
  font-size: clamp(1.8rem, 8vw, 2.8rem);
  color: var(--reveal-text);
  text-shadow: var(--glow-primary);
}

.scene__kicker {
  margin: 0;
  color: var(--color-highlight);
}

// The line is made of words that come in one by one; the whole line fades out at the end of the step
.scene__suspense {
  display: flex;
  flex-wrap: wrap;
  gap: 0 0.35em;
  justify-content: center;
  margin: 0;
  font-size: clamp(2rem, 9vw, 3.4rem);
  color: var(--reveal-text);
  text-shadow: var(--glow-primary);
  animation: scene-out 0.6s ease-in both;
  animation-delay: var(--out-delay);
}

.scene__word {
  display: inline-block;
}

// The photo box has a fixed size, so the name never moves. The photo keeps its proportions (never cropped).
.scene__frame {
  --photo-max-height: min(52dvh, 30rem);

  display: grid;
  place-items: center;
  width: 100%;
  height: var(--photo-max-height);
  perspective: 900px;
}

.scene__frame--band {
  --photo-max-height: min(34dvh, 20rem);
}

.scene__frame--winner {
  --photo-max-height: min(46dvh, 30rem);
}

// Second and third need room under the winner
.scene__frame--with-runners {
  --photo-max-height: min(34dvh, 24rem);
}

.scene__frame--runner {
  --photo-max-height: min(18dvh, 11rem);
}

.scene__photo {
  position: relative;
  display: grid;
  place-items: center;

  img {
    display: block;
    width: auto;
    height: auto;
    max-width: min(92vw, 44rem);
    max-height: var(--photo-max-height);
    border: 3px solid var(--color-surface);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-raised), var(--glow-primary);
    user-select: none;
  }
}

.scene__winners {
  display: grid;
  gap: var(--space-3);
  width: 100%;
  justify-items: center;
}

// A draw: both winners side by side
.scene__winners--tie {
  grid-template-columns: repeat(2, minmax(0, 1fr));

  .scene__photo img {
    max-width: 44vw;
  }
}

.scene__winner {
  display: grid;
  gap: var(--space-2);
  justify-items: center;
  width: 100%;
  margin: 0;
}

.scene__crown {
  position: absolute;
  top: calc(var(--space-2) * -1);
  right: calc(var(--space-2) * -1);
  display: grid;
  place-items: center;
  width: 2.75rem;
  height: 2.75rem;
  font-size: 1.6rem;
  line-height: 1;
  color: var(--color-on-accent);
  background-color: var(--color-highlight);
  border-radius: var(--radius-pill);
  box-shadow: var(--shadow-card);
}

.scene__runners {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--space-4);
  width: 100%;
}

.scene__runner {
  display: grid;
  gap: var(--space-1);
  justify-items: center;
  margin: 0;

  figcaption {
    display: grid;
  }
}

.scene__runner-name {
  font-weight: 700;
}

.scene__runner-place {
  font-family: var(--font-display);
  color: var(--color-highlight);
}

// A short white burst (the "flash" effect, and just before the winner)
.scene__flash {
  position: fixed;
  inset: 0;
  z-index: 2;
  background: #fff;
  opacity: 0;
  pointer-events: none;
  animation: flash 0.7s ease-out both;
}

.scene__flash--late {
  animation-delay: 0.6s;
}

@keyframes stage-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes stage-out {
  from { opacity: 1; }
  to { opacity: 0; }
}

@keyframes scene-out {
  from { opacity: 1; }
  to { opacity: 0; }
}

@keyframes beam-sweep {
  from { transform: rotate(-16deg); }
  to { transform: rotate(16deg); }
}

@keyframes flash {
  0% { opacity: 0; }
  20% { opacity: 0.85; }
  100% { opacity: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .reveal-stage,
  .reveal-stage--leaving {
    animation-duration: 0.01s;
  }
}
</style>
