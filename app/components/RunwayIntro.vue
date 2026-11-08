<script setup lang="ts">
/**
 * Full-screen intro video of the runway. The black backdrop fades in first, then
 * the video starts. Emits `close` when it ends or the viewer skips it.
 */
defineProps<{ src: string }>()
const emit = defineEmits<{ close: [] }>()

const video = ref<HTMLVideoElement | null>(null)
const ready = ref(false)
// Browsers may refuse to autoplay with sound when the viewer has not interacted with the page
const needsTap = ref(false)

// Wait for the black backdrop before the video appears
const BACKDROP_MS = 800
let timer: ReturnType<typeof setTimeout> | undefined

async function play(): Promise<void> {
  needsTap.value = false
  try {
    await video.value?.play()
  }
  catch {
    needsTap.value = true
  }
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') emit('close')
}

onMounted(() => {
  document.documentElement.style.overflow = 'hidden'
  window.addEventListener('keydown', onKeydown)
  timer = setTimeout(() => {
    ready.value = true
    play()
  }, BACKDROP_MS)
})

onBeforeUnmount(() => {
  clearTimeout(timer)
  document.documentElement.style.overflow = ''
  window.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <div class="intro" role="dialog" aria-modal="true" aria-label="Introducción de la pasarela">
    <video
      ref="video"
      class="intro__video"
      :class="{ 'intro__video--visible': ready }"
      :src="src"
      playsinline
      preload="auto"
      @ended="emit('close')"
      @error="emit('close')"
    />

    <button v-if="needsTap" type="button" class="btn btn--primary intro__play" @click="play">
      Reproducir
    </button>

    <button type="button" class="btn btn--secondary intro__skip" @click="emit('close')">
      Saltar
    </button>
  </div>
</template>

<style scoped lang="scss">
.intro {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: grid;
  place-items: center;
  background-color: #000;
  animation: intro-to-black 0.8s ease both;
}

.intro__video {
  width: 100%;
  height: 100%;
  object-fit: contain;
  opacity: 0;
  transition: opacity 0.6s ease;
}

.intro__video--visible {
  opacity: 1;
}

.intro__play {
  position: absolute;
}

.intro__skip {
  position: absolute;
  right: var(--space-4);
  bottom: var(--space-4);
}

@keyframes intro-to-black {
  from { background-color: transparent; }
  to { background-color: #000; }
}

@media (prefers-reduced-motion: reduce) {
  .intro,
  .intro__video {
    animation-duration: 0.01s;
    transition-duration: 0.01s;
  }
}
</style>
