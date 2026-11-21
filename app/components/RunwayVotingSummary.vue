<script lang="ts">
/** A band (group category team) with its landscape photos */
export interface SummaryBand {
  id: string
  name: string
  urls: string[]
}

/** A queen with the photos of her looks (up to 4) */
export interface SummaryQueen {
  id: string
  name: string
  /** Category of her look; null when the week has a single category (nothing to tell apart) */
  categoryTitle: string | null
  urls: string[]
}
</script>

<script setup lang="ts">
/**
 * Full-screen, video-style summary of the week shown when the runway opens for voting:
 * a title card, the bands (when there is a group category), every queen and a closing
 * card that sends people to vote. It is built from live data, not from a video file.
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
const BAND_MS = 3800
const QUEEN_MS = 3000
/** With a big cast every queen gets a bit less time, so the summary stays short */
const BIG_CAST = 8
const BIG_CAST_QUEEN_MS = 2200
/** The backdrop comes in first, then the first scene */
const BACKDROP_MS = 500
const SPARKLES = 7

const reduced = import.meta.client && window.matchMedia('(prefers-reduced-motion: reduce)').matches
/** Phones: the photos of a queen (or band) are a carousel, one at a time at full size; bigger screens show them side by side */
const carousel = !reduced && import.meta.client && window.matchMedia('(max-width: 640px)').matches

// Carousel timing: every scene lasts the same, whatever its number of photos. The first photo slides in after
// CAROUSEL_START_S, the last one stays for CAROUSEL_HOLD_MS, and the time in between is shared by the photos
// (the previous one slides out as the next arrives), so fewer photos stay longer each.
const CAROUSEL_START_S = 0.3
const CAROUSEL_SLIDE_S = 0.6
const CAROUSEL_HOLD_MS = 1300
const CAROUSEL_SCENE_MS = 5000
/** With a big cast every scene is shorter (at 4 photos each step is still longer than a slide) */
const CAROUSEL_BIG_CAST_SCENE_MS = 4200
const carouselSceneMs = computed(() => (props.queens.length > BIG_CAST ? CAROUSEL_BIG_CAST_SCENE_MS : CAROUSEL_SCENE_MS))
/** Seconds between one slide arriving and the next one arriving, for a carousel of `photos` slides */
const carouselStepS = (photos: number): number =>
  photos > 1 ? (carouselSceneMs.value - (CAROUSEL_START_S + CAROUSEL_SLIDE_S) * 1000 - CAROUSEL_HOLD_MS) / (photos - 1) / 1000 : 0

const scenes = computed<Scene[]>(() => {
  const queenMs = props.queens.length > BIG_CAST ? BIG_CAST_QUEEN_MS : QUEEN_MS
  return [
    { key: 'title', kind: 'title', ms: TITLE_MS },
    ...props.bands.map((band): Scene => ({ key: `band-${band.id}`, kind: 'band', ms: carousel ? carouselSceneMs.value : BAND_MS, band })),
    ...props.queens.map((queen): Scene => ({ key: `queen-${queen.id}`, kind: 'queen', ms: carousel ? carouselSceneMs.value : queenMs, queen })),
    // The closing card waits for the viewer
    { key: 'outro', kind: 'outro', ms: 0 },
  ]
})

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
  const urls = [...props.bands.flatMap(band => band.urls), ...props.queens.flatMap(queen => queen.urls)]
  for (const url of urls) new Image().src = url
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

/** Photos land one after the other, each with its own small tilt */
function photoEnter(position: number, delay = 0.25) {
  const tilt = position % 2 === 0 ? -3 : 3
  return {
    initial: reduced ? false : { opacity: 0, y: 70, scale: 0.85, rotate: tilt * 3 },
    animate: { opacity: 1, y: 0, scale: 1, rotate: reduced ? 0 : tilt },
    transition: { type: 'spring' as const, stiffness: 90, damping: 13, delay: delay + position * 0.18 },
  }
}

/**
 * Phones: slide `position` of a carousel of `count` slides. It comes in from the right at full size, stays until
 * the next slide arrives and leaves to the left; the last slide stays. Same unit (%) in every keyframe, or the
 * browser cannot interpolate it.
 */
function slideEnter(position: number, count: number) {
  const isLast = position === count - 1
  const step = carouselStepS(count)
  const total = isLast ? CAROUSEL_SLIDE_S : step + CAROUSEL_SLIDE_S
  return {
    initial: { x: '115%', opacity: 0 },
    animate: isLast
      ? { x: ['115%', '0%'], opacity: [0, 1] }
      : { x: ['115%', '0%', '0%', '-115%'], opacity: [0, 1, 1, 0] },
    transition: {
      duration: total,
      times: isLast ? [0, 1] : [0, CAROUSEL_SLIDE_S / total, step / total, 1],
      ease: 'easeInOut' as const,
      delay: CAROUSEL_START_S + position * step,
    },
  }
}

/** The dot of the slide on screen lights up while it is there (the last one stays lit) */
function dotEnter(position: number, count: number) {
  const isLast = position === count - 1
  const step = carouselStepS(count)
  return {
    initial: { opacity: 0.3, scale: 1 },
    animate: isLast
      ? { opacity: [0.3, 1], scale: [1, 1.5] }
      : { opacity: [0.3, 1, 1, 0.3], scale: [1, 1.5, 1.5, 1] },
    transition: {
      duration: isLast ? CAROUSEL_SLIDE_S : step + CAROUSEL_SLIDE_S,
      times: isLast ? [0, 1] : [0, CAROUSEL_SLIDE_S / (step + CAROUSEL_SLIDE_S), step / (step + CAROUSEL_SLIDE_S), 1],
      delay: CAROUSEL_START_S + position * step,
    },
  }
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
          <ul class="scene__photos scene__photos--band" :class="{ 'scene__photos--many': scene.band.urls.length > 1, 'scene__photos--carousel': carousel }">
            <Motion v-for="(url, position) in scene.band.urls" :key="url" as="li" class="scene__photo" v-bind="carousel ? slideEnter(position, scene.band.urls.length) : photoEnter(position)">
              <img :src="url" :alt="`Foto de la banda ${scene.band.name}`" draggable="false">
            </Motion>
          </ul>
          <ol v-if="carousel && scene.band.urls.length > 1" class="scene__dots" aria-hidden="true">
            <Motion v-for="(url, position) in scene.band.urls" :key="url" as="li" class="scene__dot" v-bind="dotEnter(position, scene.band.urls.length)" />
          </ol>
          <Motion as="h2" class="display scene__name" v-bind="enter(0.2)">
            {{ scene.band.name }}
          </Motion>
        </template>

        <template v-else-if="scene.kind === 'queen'">
          <Motion v-if="scene.queen.categoryTitle" as="p" class="kicker" v-bind="enter()">
            {{ scene.queen.categoryTitle }}
          </Motion>
          <ul class="scene__photos scene__photos--queen" :class="{ 'scene__photos--many': scene.queen.urls.length > 1, 'scene__photos--carousel': carousel }">
            <Motion v-for="(url, position) in scene.queen.urls" :key="url" as="li" class="scene__photo" v-bind="carousel ? slideEnter(position, scene.queen.urls.length) : photoEnter(position)">
              <img :src="url" :alt="`Look de ${scene.queen.name}`" draggable="false">
            </Motion>
          </ul>
          <ol v-if="carousel && scene.queen.urls.length > 1" class="scene__dots" aria-hidden="true">
            <Motion v-for="(url, position) in scene.queen.urls" :key="url" as="li" class="scene__dot" v-bind="dotEnter(position, scene.queen.urls.length)" />
          </ol>
          <Motion as="h2" class="display scene__name" v-bind="enter(0.2)">
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

.scene__photos {
  display: grid;
  gap: var(--space-3);
  justify-content: center;
  width: 100%;
  margin: 0;
  padding: 0;
  list-style: none;
}

.scene__photo {
  overflow: hidden;
  border: 3px solid var(--color-surface);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-raised), var(--glow-primary);

  img {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
    user-select: none;
  }
}

// Queens: portrait photos, one big or a small grid
.scene__photos--queen {
  grid-template-columns: min(100%, 17rem);

  .scene__photo {
    aspect-ratio: 3 / 4;
  }
}

.scene__photos--queen.scene__photos--many {
  grid-template-columns: repeat(2, minmax(0, 11rem));

  .scene__photo {
    aspect-ratio: 1;
  }
}

// Bands: landscape photos, one big or a small grid
.scene__photos--band {
  grid-template-columns: minmax(0, 28rem);

  .scene__photo {
    aspect-ratio: 16 / 9;
  }
}

.scene__photos--band.scene__photos--many {
  grid-template-columns: repeat(2, minmax(0, 13.5rem));
}

// Fixed spots (top, left) so the sparkles are spread over the screen but never move around
$sparkle-spots: (8%, 12%), (18%, 82%), (34%, 6%), (46%, 90%), (62%, 14%), (74%, 78%), (86%, 40%);

@for $spot from 1 through length($sparkle-spots) {
  .summary__sparkle:nth-of-type(#{$spot}) {
    top: nth(nth($sparkle-spots, $spot), 1);
    left: nth(nth($sparkle-spots, $spot), 2);
  }
}

// Phones: the photos are slides of a carousel in one box, each at its original proportions (never cropped);
// the frame goes on the image itself so it hugs the photo
.scene__photos--carousel {
  position: relative;
  display: block;
  grid-template-columns: none;
  width: min(86vw, 22rem);
  height: min(58dvh, 28rem);

  .scene__photo {
    position: absolute;
    inset: 0;
    // Flex, not grid: the image's percentage max-size resolves against this box
    display: flex;
    align-items: center;
    justify-content: center;
    aspect-ratio: auto;
    overflow: visible;
    border: 0;
    box-shadow: none;

    img {
      width: auto;
      height: auto;
      max-width: 100%;
      max-height: 100%;
      border: 3px solid var(--color-surface);
      border-radius: var(--radius-lg);
      box-shadow: var(--shadow-raised), var(--glow-primary);
    }
  }
}

.scene__photos--band.scene__photos--carousel {
  height: auto;
  aspect-ratio: 16 / 9;
  width: min(92vw, 28rem);
}

.scene__dots {
  display: flex;
  gap: var(--space-2);
  margin: 0;
  padding: 0;
  list-style: none;
}

.scene__dot {
  width: 8px;
  height: 8px;
  background: var(--color-primary);
  border-radius: var(--radius-pill);
  box-shadow: var(--glow-primary);
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
