<script setup lang="ts">
// Floating "back to the top" button for long pages; it shows up after scrolling a while
const SHOW_AFTER_PX = 800
const visible = ref(false)
let frame = 0

function update(): void {
  frame = 0
  visible.value = window.scrollY > SHOW_AFTER_PX
}

function onScroll(): void {
  if (!frame) frame = requestAnimationFrame(update)
}

function toTop(): void {
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  window.scrollTo({ top: 0, behavior: reduced ? 'auto' : 'smooth' })
}

onMounted(() => {
  update()
  window.addEventListener('scroll', onScroll, { passive: true })
})
onBeforeUnmount(() => {
  window.removeEventListener('scroll', onScroll)
  cancelAnimationFrame(frame)
})
</script>

<template>
  <button v-show="visible" type="button" class="back-to-top" aria-label="Volver arriba" @click="toTop">
    <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="m6 15 6-6 6 6" />
    </svg>
  </button>
</template>

<style scoped lang="scss">
// Phones and tablets; on desktop the pages have a side list that stays in view
.back-to-top {
  position: fixed;
  right: var(--space-4);
  bottom: var(--space-4);
  z-index: 10;
  display: grid;
  place-items: center;
  width: 2.75rem;
  height: 2.75rem;
  padding: 0;
  color: var(--color-on-primary);
  cursor: pointer;
  background-color: var(--color-primary);
  border: 0;
  border-radius: var(--radius-pill);
  box-shadow: var(--shadow-raised);

  &:hover {
    background-color: var(--color-primary-hover);
  }

  @media (min-width: 64rem) {
    display: none;
  }
}
</style>
