<script setup lang="ts">
const props = withDefaults(defineProps<{
  /** Lines shown before the text is cut (phones only) */
  lines?: number
  expandLabel?: string
  collapseLabel?: string
}>(), {
  lines: 3,
  expandLabel: 'Leer reto completo ↓',
  collapseLabel: 'Leer menos ↑',
})

const expanded = ref(false)
const clamped = ref(false)
const textId = useId()
const text = ref<HTMLElement | null>(null)
let observer: ResizeObserver | undefined

// The text is only cut on phones, so the button only exists when something is actually hidden
function measure(): void {
  const element = text.value
  if (element && !expanded.value) clamped.value = element.scrollHeight > element.clientHeight + 1
}

function toggle(): void {
  expanded.value = !expanded.value
  if (!expanded.value) nextTick(measure)
}

onMounted(() => {
  measure()
  if (text.value && 'ResizeObserver' in window) {
    observer = new ResizeObserver(measure)
    observer.observe(text.value)
  }
})
onBeforeUnmount(() => observer?.disconnect())
</script>

<template>
  <div class="collapsible">
    <div
      :id="textId"
      ref="text"
      class="collapsible__text"
      :class="{ 'collapsible__text--clamped': !expanded }"
      :style="{ '--collapsible-lines': props.lines }"
    >
      <slot />
    </div>
    <button
      v-if="clamped || expanded"
      type="button"
      class="btn btn--secondary btn--block collapsible__toggle"
      :aria-expanded="expanded"
      :aria-controls="textId"
      @click="toggle"
    >
      {{ expanded ? collapseLabel : expandLabel }}
    </button>
  </div>
</template>

<style scoped lang="scss">
.collapsible {
  display: grid;
  gap: var(--space-3);
  width: 100%;
}

.collapsible__text {
  white-space: pre-line;
}

@media (max-width: 47.99rem) {
  .collapsible__text--clamped {
    display: -webkit-box;
    overflow: hidden;
    -webkit-line-clamp: var(--collapsible-lines);
    line-clamp: var(--collapsible-lines);
    -webkit-box-orient: vertical;
  }
}

// Wide screens show the whole text, so there is nothing to expand
@media (min-width: 48rem) {
  .collapsible__toggle {
    display: none;
  }
}
</style>
