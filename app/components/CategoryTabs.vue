<script setup lang="ts">
const props = defineProps<{
  /** Each item's section on the page has the id `category-<id>` */
  items: { id: string, title: string }[]
}>()

const activeId = ref<string | null>(props.items[0]?.id ?? null)
const bar = ref<HTMLElement | null>(null)
const list = ref<HTMLElement | null>(null)
// There are more tabs out of sight on that side: a fade tells the user to scroll
const moreBefore = ref(false)
const moreAfter = ref(false)
let frame = 0

const sectionId = (id: string): string => `category-${id}`
const prefersReducedMotion = (): boolean => window.matchMedia('(prefers-reduced-motion: reduce)').matches

function updateFades(): void {
  const row = list.value
  if (!row) return
  moreBefore.value = row.scrollLeft > 4
  moreAfter.value = row.scrollLeft + row.clientWidth < row.scrollWidth - 4
}

// The active tab is the last section whose top has reached the area under the tabs
function updateActive(): void {
  frame = 0
  const limit = (bar.value?.getBoundingClientRect().bottom ?? 0) + 16
  let current = props.items[0]?.id ?? null
  for (const item of props.items) {
    const section = document.getElementById(sectionId(item.id))
    if (section && section.getBoundingClientRect().top <= limit) current = item.id
  }
  activeId.value = current
}

function onScroll(): void {
  if (!frame) frame = requestAnimationFrame(updateActive)
}

function goTo(id: string): void {
  activeId.value = id
  document.getElementById(sectionId(id))?.scrollIntoView({ behavior: prefersReducedMotion() ? 'auto' : 'smooth', block: 'start' })
}

// Keep the active tab in view inside the sideways-scrolling row (without moving the page)
watch(activeId, async (id) => {
  await nextTick()
  const row = list.value
  const tab = row?.querySelector<HTMLElement>(`[data-id="${id}"]`)
  if (!row || !tab) return
  row.scrollTo({ left: tab.offsetLeft - (row.clientWidth - tab.offsetWidth) / 2, behavior: prefersReducedMotion() ? 'auto' : 'smooth' })
})

let resizeObserver: ResizeObserver | undefined

onMounted(() => {
  updateActive()
  updateFades()
  window.addEventListener('scroll', onScroll, { passive: true })
  if (list.value && 'ResizeObserver' in window) {
    resizeObserver = new ResizeObserver(updateFades)
    resizeObserver.observe(list.value)
  }
})
onBeforeUnmount(() => {
  window.removeEventListener('scroll', onScroll)
  resizeObserver?.disconnect()
  cancelAnimationFrame(frame)
})
</script>

<template>
  <nav
    ref="bar"
    class="category-tabs"
    :class="{ 'category-tabs--more-before': moreBefore, 'category-tabs--more-after': moreAfter }"
    aria-label="Categorías de la semana"
  >
    <ul ref="list" class="category-tabs__list" @scroll.passive="updateFades">
      <li v-for="item in items" :key="item.id">
        <a
          :href="`#${sectionId(item.id)}`"
          :data-id="item.id"
          class="category-tabs__tab"
          :class="{ 'category-tabs__tab--active': item.id === activeId }"
          :aria-current="item.id === activeId ? 'true' : undefined"
          @click.prevent="goTo(item.id)"
        >
          {{ item.title }}
        </a>
      </li>
    </ul>
  </nav>
</template>

<style scoped lang="scss">
// Phones only: sits under the results button and, when it reaches the pinned top bar, sticks under it
.category-tabs {
  position: sticky;
  top: var(--app-nav-height);
  z-index: 15;
  // Full width, over the page's own side padding
  min-width: 0;
  padding-block: var(--space-3);
  margin-inline: calc(var(--space-4) * -1);
  background-color: var(--color-page);
  box-shadow: 0 1px 0 var(--color-border);

  // Semi-transparent fades on the edges that have more tabs behind them
  &::before,
  &::after {
    position: absolute;
    top: 0;
    bottom: 0;
    z-index: 1;
    width: 2.5rem;
    pointer-events: none;
    content: '';
    opacity: 0;
    transition: opacity 0.15s;
  }

  &::before {
    left: 0;
    background: linear-gradient(to right, var(--color-page) 15%, transparent);
  }

  &::after {
    right: 0;
    background: linear-gradient(to left, var(--color-page) 15%, transparent);
  }

  &--more-before::before,
  &--more-after::after {
    opacity: 0.9;
  }

  @media (min-width: 48rem) {
    display: none;
  }
}

.category-tabs__list {
  display: flex;
  gap: var(--space-2);
  padding: 0 var(--space-4);
  margin: 0;
  overflow: auto hidden;
  list-style: none;
  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }

  > li {
    flex: none;
  }
}

.category-tabs__tab {
  display: inline-flex;
  align-items: center;
  min-height: 2.75rem;
  padding: var(--space-2) var(--space-4);
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text);
  text-decoration: none;
  white-space: nowrap;
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);

  &--active {
    color: var(--color-on-primary);
    background-color: var(--color-primary);
    border-color: var(--color-primary);
  }
}
</style>
