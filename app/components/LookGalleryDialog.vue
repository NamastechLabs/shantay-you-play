<script setup lang="ts">
export interface LookPhoto {
  url: string
  label: string
}

const props = defineProps<{
  open: boolean
  /** Queen name */
  title: string
  photos: LookPhoto[]
  categoryTitle?: string | null
  intro?: string | null
  /** Show the previous / next look arrows next to the name */
  canNavigate?: boolean
}>()

defineEmits<{ close: [], previous: [], next: [] }>()

const index = ref(0)
const track = ref<HTMLElement | null>(null)

// While a programmatic scroll (dot click, arrow key) is running, scroll events must not move the active index
let lockedUntil = 0

function prefersReducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

// Phones and tablet portrait: slides are scrolled sideways (native swipe + snap). Desktop only shows the active slide.
function scrollToIndex(smooth: boolean): void {
  const element = track.value
  if (!element) return
  lockedUntil = Date.now() + (smooth ? 500 : 0)
  element.scrollTo({ left: index.value * element.clientWidth, behavior: smooth && !prefersReducedMotion() ? 'smooth' : 'instant' })
}

function select(next: number): void {
  index.value = Math.min(Math.max(next, 0), props.photos.length - 1)
  scrollToIndex(true)
}

function onScroll(): void {
  const element = track.value
  if (!element || Date.now() < lockedUntil || !element.clientWidth) return
  index.value = Math.round(element.scrollLeft / element.clientWidth)
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'ArrowRight') select(index.value + 1)
  else if (event.key === 'ArrowLeft') select(index.value - 1)
  else return
  event.preventDefault()
}

// Always start on the first photo, also when the arrows switch to another look
watch([() => props.open, () => props.photos[0]?.url], async () => {
  index.value = 0
  await nextTick()
  scrollToIndex(false)
})

// Crossing the breakpoint (rotating a tablet) keeps the photo that was showing
let query: MediaQueryList | null = null
const onBreakpoint = (): void => scrollToIndex(false)
onMounted(() => {
  query = window.matchMedia('(min-width: 64rem)')
  query.addEventListener('change', onBreakpoint)
})
onBeforeUnmount(() => query?.removeEventListener('change', onBreakpoint))
</script>

<template>
  <AppModal wide :open="open" :title="title" @close="$emit('close')">
    <template v-if="canNavigate" #header-actions>
      <nav class="look-nav" aria-label="Navegar entre looks">
        <button type="button" class="look-nav__btn" aria-label="Look anterior" @click="$emit('previous')">
          ←
        </button>
        <button type="button" class="look-nav__btn" aria-label="Look siguiente" @click="$emit('next')">
          →
        </button>
      </nav>
    </template>
    <div class="look-gallery" @keydown="onKeydown">
      <div
        ref="track"
        class="look-gallery__track"
        role="group"
        aria-roledescription="carrusel"
        aria-label="Fotos del look"
        @scroll.passive="onScroll"
      >
        <figure
          v-for="(photo, i) in photos"
          :key="photo.url"
          class="look-gallery__slide"
          :class="{ 'look-gallery__slide--active': i === index }"
          :aria-label="`${photo.label}, foto ${i + 1} de ${photos.length}`"
        >
          <img :src="photo.url" :alt="`Look de ${title}: ${photo.label}`">
          <figcaption>{{ photo.label }}</figcaption>
        </figure>
      </div>

      <!-- Tablet portrait and smaller: pagination dots -->
      <div v-if="photos.length > 1" class="look-gallery__dots" role="group" aria-label="Elegir foto">
        <button
          v-for="(photo, i) in photos"
          :key="photo.url"
          type="button"
          class="look-gallery__dot"
          :class="{ 'look-gallery__dot--active': i === index }"
          :aria-label="`Ver foto ${i + 1}: ${photo.label}`"
          :aria-current="i === index ? 'true' : undefined"
          @click="select(i)"
        />
      </div>

      <!-- Tablet landscape and desktop: all the photos, click one to enlarge it on the left -->
      <ul v-if="photos.length > 1" class="look-gallery__thumbs" aria-label="Todas las fotos">
        <li v-for="(photo, i) in photos" :key="photo.url">
          <button
            type="button"
            class="look-gallery__thumb"
            :class="{ 'look-gallery__thumb--active': i === index }"
            :aria-label="`Ver foto ${i + 1}: ${photo.label}`"
            :aria-pressed="i === index"
            @click="select(i)"
          >
            <img :src="photo.url" alt="" loading="lazy">
          </button>
        </li>
      </ul>

      <p v-if="categoryTitle || intro" class="look-gallery__intro">
        <strong v-if="categoryTitle">{{ categoryTitle }}</strong>
        {{ intro }}
      </p>
    </div>
  </AppModal>
</template>
