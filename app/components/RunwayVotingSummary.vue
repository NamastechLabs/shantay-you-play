<script lang="ts">
/** A band (group category team): its first photo */
export interface SummaryBand {
  id: string
  name: string
  url: string
}

/** A queen: the first photo of her first look */
export interface SummaryQueen {
  id: string
  name: string
  /** Category of her look; null when the week has a single category (nothing to tell apart) */
  categoryTitle: string | null
  url: string
}
</script>

<script setup lang="ts">
/**
 * Full-screen, video-style summary of the week shown when the runway opens for voting:
 * a title card, the bands (when there is a group category), every queen and a closing
 * card that sends people to vote. It is built from live data, not from a video file.
 * Every band and queen gets one photo for a couple of seconds, with a random entrance
 * and exit effect; all the looks are on the vote page and the runway.
 * Emits `close` when the viewer leaves it.
 */
type Scene
  = | { key: string, kind: 'title', ms: number }
    | { key: string, kind: 'band', ms: number, band: SummaryBand }
    | { key: string, kind: 'queen', ms: number, queen: SummaryQueen }
    | { key: string, kind: 'outro', ms: number }

const props = defineProps<{
  weekNumber: number
  bands: SummaryBand[]
  queens: SummaryQueen[]
  /** Where the closing card sends people to vote */
  voteTo: string
  voteLabel: string
}>()
const emit = defineEmits<{ close: [] }>()

const TITLE_MS = 3200
/** Every band and queen stays this long: the photo comes in, stays, and goes out */
const PHOTO_SCENE_MS = 3500
const PHOTO_IN_S = 0.55
const PHOTO_OUT_S = 0.55
/** The name fades in once the photo has finished coming in */
const NAME_FADE_IN_S = 0.4
/** The backdrop comes in first, then the first scene */
const BACKDROP_MS = 500
const SPARKLES = 7

const reduced = import.meta.client && window.matchMedia('(prefers-reduced-motion: reduce)').matches

const scenes = computed<Scene[]>(() => [
  { key: 'title', kind: 'title', ms: TITLE_MS },
  ...props.bands.map((band): Scene => ({ key: `band-${band.id}`, kind: 'band', ms: PHOTO_SCENE_MS, band })),
  ...props.queens.map((queen): Scene => ({ key: `queen-${queen.id}`, kind: 'queen', ms: PHOTO_SCENE_MS, queen })),
  // The closing card waits for the viewer
  { key: 'outro', kind: 'outro', ms: 0 },
])

const started = ref(false)
const index = ref(0)
/** Changes on replay so every scene animates again */
const run = ref(0)
const current = computed(() => scenes.value[index.value]!)
/** Reduced motion: no timeline, every scene is shown as a static list */
const visibleScenes = computed(() => (reduced ? scenes.value : [current.value]))

let backdropTimer: ReturnType<typeof setTimeout> | undefined
let sceneTimer: ReturnType<typeof setTimeout> | undefined

function schedule(): void {
  clearTimeout(sceneTimer)
  if (reduced || !started.value || !current.value.ms) return
  sceneTimer = setTimeout(next, current.value.ms)
}

function next(): void {
  if (index.value < scenes.value.length - 1) index.value += 1
}

function previous(): void {
  if (index.value > 0) index.value -= 1
}

function replay(): void {
  index.value = 0
  run.value += 1
  // Every replay draws new effects
  photoMotions.clear()
  nameMotions.clear()
  schedule()
}

function onStageClick(): void {
  if (current.value.kind !== 'outro') next()
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') emit('close')
  else if (event.key === 'ArrowRight') next()
  else if (event.key === 'ArrowLeft') previous()
}

/** Download every photo up front so scenes never pop in half loaded */
function preload(): void {
  for (const url of [...props.bands.map(band => band.url), ...props.queens.map(queen => queen.url)]) new Image().src = url
}

const closeButton = ref<HTMLButtonElement | null>(null)

watch(index, schedule)

onMounted(() => {
  document.documentElement.style.overflow = 'hidden'
  window.addEventListener('keydown', onKeydown)
  preload()
  closeButton.value?.focus()
  backdropTimer = setTimeout(() => {
    started.value = true
    schedule()
  }, reduced ? 0 : BACKDROP_MS)
})

onBeforeUnmount(() => {
  clearTimeout(backdropTimer)
  clearTimeout(sceneTimer)
  document.documentElement.style.overflow = ''
  window.removeEventListener('keydown', onKeydown)
})

/** Entrance of an element: it slides up and fades in; with reduced motion it is simply there */
function enter(delay = 0) {
  return {
    initial: reduced ? false : { opacity: 0, y: 28 },
    animate: { opacity: 1, y: 0 },
    transition: { type: 'spring' as const, stiffness: 110, damping: 16, delay },
  }
}

// --- Photo effects ------------------------------------------------------------------------
// A photo is one animation of four keyframes: out of place (and invisible) -> in place -> in place -> out of
// place (and invisible). The way in and the way out are drawn at random, each from its own list, so scenes
// do not look alike. Every property keeps one unit (vw, vh, deg), or the browser cannot interpolate it.

const REST = { x: '0vw', y: '0vh', scale: 1, rotate: 0, rotateY: 0 } as const
type PoseKey = keyof typeof REST
/** What changes from the resting pose; everything else stays at rest */
type Pose = Partial<Record<PoseKey, string | number>>

const IN_EFFECTS: Pose[] = [
  { x: '70vw' }, // slides in from the right
  { x: '-70vw' }, // slides in from the left
  { y: '70vh' }, // rises from the bottom
  { y: '-70vh', rotate: 8 }, // drops from above, tilted
  { scale: 0.2 }, // zooms in from a dot
  { scale: 0.4, rotate: -35 }, // spins in
  { rotateY: 90 }, // flips in like a card
  { scale: 2.2 }, // lands from close to the camera
]

const OUT_EFFECTS: Pose[] = [
  { x: '-70vw' }, // slides out to the left
  { x: '70vw' }, // slides out to the right
  { y: '-70vh' }, // flies up
  { y: '70vh', rotate: -8 }, // falls down, tilted
  { scale: 0.2 }, // shrinks to a dot
  { scale: 0.4, rotate: 35 }, // spins out
  { rotateY: -90 }, // flips away like a card
  { scale: 2.2 }, // flies past the camera
]

const pickRandom = <T,>(items: T[]): T => items[Math.floor(Math.random() * items.length)]!

function buildPhotoMotion() {
  const rest = { ...REST, opacity: 1 }
  // With reduced motion the photo is simply there
  if (reduced) return { initial: false as const, animate: rest }

  const from = { ...REST, ...pickRandom(IN_EFFECTS), opacity: 0 }
  const to = { ...REST, ...pickRandom(OUT_EFFECTS), opacity: 0 }
  const keys = [...Object.keys(REST), 'opacity'] as (PoseKey | 'opacity')[]
  const duration = PHOTO_SCENE_MS / 1000

  return {
    initial: from,
    animate: Object.fromEntries(keys.map(key => [key, [from[key], rest[key], rest[key], to[key]]])),
    transition: {
      duration,
      times: [0, PHOTO_IN_S / duration, 1 - PHOTO_OUT_S / duration, 1],
      ease: ['easeOut', 'linear', 'easeIn'] as ('easeOut' | 'linear' | 'easeIn')[],
    },
  }
}

/** One draw per scene, kept until the next replay: the template runs again on every refresh and must not redraw */
const photoMotions = new Map<string, ReturnType<typeof buildPhotoMotion>>()
function photoMotion(sceneKey: string) {
  let motion = photoMotions.get(sceneKey)
  if (!motion) {
    motion = buildPhotoMotion()
    photoMotions.set(sceneKey, motion)
  }
  return motion
}

/** The name stays hidden while the photo comes in, fades in right after, and fades out with the photo */
function buildNameMotion() {
  const duration = PHOTO_SCENE_MS / 1000
  return {
    initial: { opacity: 0, y: 28 },
    animate: { opacity: [0, 0, 1, 1, 0], y: [28, 28, 0, 0, -12] },
    transition: {
      duration,
      times: [0, PHOTO_IN_S / duration, (PHOTO_IN_S + NAME_FADE_IN_S) / duration, 1 - PHOTO_OUT_S / duration, 1],
      ease: ['linear', 'easeOut', 'linear', 'easeIn'] as ('linear' | 'easeOut' | 'easeIn')[],
    },
  }
}

/** One per scene, like the photo's: the animation library works on these objects, so they are never shared */
const nameMotions = new Map<string, ReturnType<typeof buildNameMotion>>()
function nameMotion(sceneKey: string) {
  let motion = nameMotions.get(sceneKey)
  if (!motion) {
    motion = buildNameMotion()
    nameMotions.set(sceneKey, motion)
  }
  return motion
}
</script>

<template>
  <div class="summary" :class="{ 'summary--static': reduced }" role="dialog" aria-modal="true" aria-label="Resumen de la votación">
    <!-- Progress, one segment per scene (not needed when nothing moves by itself) -->
    <ol v-if="!reduced" class="summary__progress" aria-hidden="true">
      <li v-for="(scene, position) in scenes" :key="scene.key" class="summary__segment">
        <span
          :key="`${run}-${position}-${index === position}`"
          class="summary__fill"
          :class="{
            'summary__fill--done': position < index || (position === index && !scene.ms),
            'summary__fill--running': position === index && !!scene.ms,
          }"
          :style="{ '--scene-ms': `${scene.ms}ms` }"
        />
      </li>
    </ol>

    <button ref="closeButton" type="button" class="btn btn--secondary summary__close" @click="emit('close')">
      {{ reduced || current.kind === 'outro' ? 'Cerrar' : 'Saltar' }}
    </button>

    <!-- Sparkles are decoration: the theme colors them (and the glow) through its tokens -->
    <template v-if="!reduced">
      <span v-for="n in SPARKLES" :key="n" class="summary__sparkle" :style="{ '--n': n }" aria-hidden="true">✦</span>
    </template>

    <!-- A click anywhere on the stage moves on to the next scene -->
    <div v-if="started" class="summary__stage" aria-live="polite" @click="onStageClick">
      <section
        v-for="scene in visibleScenes"
        :key="`${run}-${scene.key}`"
        class="scene"
        :class="`scene--${scene.kind}`"
      >
        <template v-if="scene.kind === 'title'">
          <Motion as="p" class="kicker" v-bind="enter()">
            Semana {{ weekNumber }}
          </Motion>
          <Motion as="h2" class="display scene__title" v-bind="enter(0.2)">
            ¡Abre la votación!
          </Motion>
          <Motion as="p" class="lead scene__lead" v-bind="enter(0.5)">
            Mira a las reinas de la semana
          </Motion>
        </template>

        <template v-else-if="scene.kind === 'band'">
          <Motion as="p" class="kicker" v-bind="enter()">
            {{ bands.length > 1 ? 'Las bandas' : 'La banda' }}
          </Motion>
          <div class="scene__frame scene__frame--band">
            <Motion as="div" class="scene__photo" v-bind="photoMotion(scene.key)">
              <img :src="scene.band.url" :alt="`Foto de la banda ${scene.band.name}`" draggable="false">
            </Motion>
          </div>
          <Motion as="h2" class="display scene__name" v-bind="reduced ? enter() : nameMotion(scene.key)">
            {{ scene.band.name }}
          </Motion>
        </template>

        <template v-else-if="scene.kind === 'queen'">
          <Motion v-if="scene.queen.categoryTitle" as="p" class="kicker" v-bind="enter()">
            {{ scene.queen.categoryTitle }}
          </Motion>
          <div class="scene__frame scene__frame--queen">
            <Motion as="div" class="scene__photo" v-bind="photoMotion(scene.key)">
              <img :src="scene.queen.url" :alt="`Look de ${scene.queen.name}`" draggable="false">
            </Motion>
          </div>
          <Motion as="h2" class="display scene__name" v-bind="reduced ? enter() : nameMotion(scene.key)">
            {{ scene.queen.name }}
          </Motion>
        </template>

        <template v-else>
          <Motion as="h2" class="display scene__title" v-bind="enter()">
            ¡Es hora de votar!
          </Motion>
          <Motion as="p" class="lead scene__lead" v-bind="enter(0.25)">
            Elige tu Top 3 de reinas de la semana.
          </Motion>
          <Motion as="div" class="scene__actions" v-bind="enter(0.5)">
            <NuxtLink :to="voteTo" class="btn btn--primary">
              {{ voteLabel }}
            </NuxtLink>
            <button type="button" class="btn btn--secondary" @click="replay">
              Repetir el resumen
            </button>
          </Motion>
        </template>
      </section>
    </div>
  </div>
</template>

<style scoped lang="scss">
.summary {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: grid;
  overflow: hidden;
  color: var(--color-text);
  background: var(--page-backdrop), var(--color-page);
  animation: summary-in 0.5s ease both;
}

// Reduced motion: every scene is listed one under the other
.summary--static {
  overflow-y: auto;
}

.summary__progress {
  position: absolute;
  top: var(--space-3);
  right: var(--space-4);
  left: var(--space-4);
  z-index: 2;
  display: flex;
  gap: 4px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.summary__segment {
  flex: 1;
  height: 4px;
  overflow: hidden;
  background: color-mix(in srgb, var(--color-text) 18%, transparent);
  border-radius: var(--radius-pill);
}

.summary__fill {
  display: block;
  width: 100%;
  height: 100%;
  background: var(--color-primary);
  box-shadow: var(--glow-primary);
  transform: scaleX(0);
  transform-origin: left;
}

.summary__fill--done {
  transform: scaleX(1);
}

.summary__fill--running {
  animation: summary-fill var(--scene-ms) linear both;
}

.summary__close {
  position: absolute;
  right: var(--space-4);
  bottom: var(--space-4);
  z-index: 3;
}

.summary__stage {
  display: grid;
  place-items: center;
  min-height: 0;
  padding: var(--space-6) var(--space-4) calc(var(--space-6) + var(--space-5));
  cursor: pointer;
}

.scene {
  display: grid;
  gap: var(--space-3);
  justify-items: center;
  width: 100%;
  max-width: 34rem;
  text-align: center;
}

.scene--queen,
.scene--band {
  max-width: min(92vw, 44rem);
}

.summary--static .scene {
  margin-block: var(--space-5);
}

.scene__title {
  margin: 0;
  font-size: clamp(2.4rem, 11vw, 4rem);
  color: var(--color-title);
  text-shadow: var(--glow-primary);
}

.scene__name {
  margin: 0;
  font-size: clamp(1.8rem, 8vw, 2.8rem);
  color: var(--color-title);
}

.scene__lead {
  margin: 0;
}

.scene__actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
  justify-content: center;
}

// The photo box has a fixed size, so the name never moves. The photo keeps its own proportions (never cropped)
// and the frame goes on the image itself, so it hugs the photo. The perspective is for the flip effect.
.scene__frame {
  --photo-max-height: min(54dvh, 32rem);

  display: grid;
  place-items: center;
  width: 100%;
  height: var(--photo-max-height);
  perspective: 900px;
}

// Bands are landscape and need less height
.scene__frame--band {
  --photo-max-height: min(34dvh, 22rem);
}

.scene__photo {
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

// Fixed spots (top, left) so the sparkles are spread over the screen but never move around
$sparkle-spots: (8%, 12%), (18%, 82%), (34%, 6%), (46%, 90%), (62%, 14%), (74%, 78%), (86%, 40%);

@for $spot from 1 through length($sparkle-spots) {
  .summary__sparkle:nth-of-type(#{$spot}) {
    top: nth(nth($sparkle-spots, $spot), 1);
    left: nth(nth($sparkle-spots, $spot), 2);
  }
}

.summary__sparkle {
  position: absolute;
  font-size: calc(0.9rem + var(--n) * 0.18rem);
  color: var(--color-highlight);
  text-shadow: var(--glow-accent);
  opacity: 0;
  pointer-events: none;
  animation: summary-twinkle 2.6s ease-in-out infinite;
  animation-delay: calc(var(--n) * 0.37s);
}

@keyframes summary-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes summary-fill {
  from { transform: scaleX(0); }
  to { transform: scaleX(1); }
}

@keyframes summary-twinkle {
  0%, 100% { opacity: 0; transform: scale(0.4) rotate(0deg); }
  50% { opacity: 0.9; transform: scale(1.2) rotate(45deg); }
}

@media (prefers-reduced-motion: reduce) {
  .summary {
    animation-duration: 0.01s;
  }
}
</style>
