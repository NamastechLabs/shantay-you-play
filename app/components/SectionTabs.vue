<script setup lang="ts">
/**
 * Sticky row of pill tabs that jumps between the sections of a long page (categories of a runway,
 * sections of the help, versions of the release notes). It scrolls sideways, with a fade and an arrow
 * on the edges that hide more tabs, and the active tab follows the scroll.
 * Each item's section on the page has the id `<idPrefix><item.id>`.
 */
const props = withDefaults(defineProps<{
  items: { id: string, title: string }[]
  idPrefix?: string
  label?: string
  /** Where the tabs stop being shown: phones (below 48rem) or everything below desktop (64rem) */
  until?: 'phone' | 'desktop'
}>(), { idPrefix: '', label: 'Secciones', until: 'phone' })

/** A tab is about to scroll to its section: the page can open it first (e.g. a collapsed block) */
const emit = defineEmits<{ navigate: [id: string] }>()

const activeId = ref<string | null>(props.items[0]?.id ?? null)
const bar = ref<HTMLElement | null>(null)
const list = ref<HTMLElement | null>(null)
// There are more tabs out of sight on that side: a fade tells the user to scroll
const moreBefore = ref(false)
const moreAfter = ref(false)
let frame = 0

const sectionId = (id: string): string => `${props.idPrefix}${id}`
const prefersReducedMotion = (): boolean => window.matchMedia('(prefers-reduced-motion: reduce)').matches

function updateFades(): void {
  const row = list.value
  if (!row) return
  moreBefore.value = row.scrollLeft > 4
  moreAfter.value = row.scrollLeft + row.clientWidth < row.scrollWidth - 4
}

/** A section inside something collapsed is not rendered: it cannot be the one being read */
function isRendered(element: HTMLElement | null): element is HTMLElement {
  if (!element) return false
  const box = element.getBoundingClientRect()
  return (box.width > 0 || box.height > 0) && (element.checkVisibility?.() ?? true)
}

// The active tab is the last section whose top has reached the area under the tabs
function updateActive(): void {
  frame = 0
  const limit = (bar.value?.getBoundingClientRect().bottom ?? 0) + 16
  const atBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2
  let current = props.items[0]?.id ?? null
  for (const item of props.items) {
    const section = document.getElementById(sectionId(item.id))
    // At the very bottom a short last section can never reach the top: it is the one being read
    if (isRendered(section) && (atBottom || section.getBoundingClientRect().top <= limit)) current = item.id
  }
  activeId.value = current
}

function onScroll(): void {
  if (!frame) frame = requestAnimationFrame(updateActive)
}

async function goTo(id: string): Promise<void> {
  activeId.value = id
  emit('navigate', id)
  await nextTick()
  const section = document.getElementById(sectionId(id))
  section?.scrollIntoView({ behavior: prefersReducedMotion() ? 'auto' : 'smooth', block: 'start' })
  // Screen readers and keyboard users continue from the section they chose
  const heading = section?.matches('h1, h2, h3') ? section : section?.querySelector<HTMLElement>('h2')
  if (heading) {
    heading.tabIndex = -1
    heading.focus({ preventScroll: true })
  }
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
    class="section-tabs"
    :class="{
      'section-tabs--more-before': moreBefore,
      'section-tabs--more-after': moreAfter,
      'section-tabs--until-desktop': until === 'desktop',
    }"
    :aria-label="label"
  >
    <ul ref="list" class="section-tabs__list" @scroll.passive="updateFades">
      <li v-for="item in items" :key="item.id">
        <a
          :href="`#${sectionId(item.id)}`"
          :data-id="item.id"
          class="section-tabs__tab"
          :class="{ 'section-tabs__tab--active': item.id === activeId }"
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
// Sits in the page flow and, when it reaches the top (under the pinned top bar on phones), sticks there.
// Shown on phones, or up to desktop width with `until="desktop"` (pages that have a side list from 64rem).
.section-tabs {
  position: sticky;
  top: var(--app-nav-height);
  z-index: 15;
  // Full width, over the page's own side padding
  min-width: 0;
  padding-block: var(--space-2);
  margin-inline: calc(var(--space-4) * -1);
  background-color: var(--color-surface);
  box-shadow: 0 1px 0 var(--color-border);

  // Fades with a small arrow on the edges that have more tabs behind them
  &::before,
  &::after {
    position: absolute;
    top: 0;
    bottom: 0;
    z-index: 1;
    display: flex;
    align-items: center;
    width: 3rem;
    padding-inline: var(--space-2);
    font-size: 1.5rem;
    font-weight: 700;
    line-height: 1;
    color: var(--color-kicker);
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.15s;
  }

  &::before {
    left: 0;
    justify-content: flex-start;
    content: '‹';
    content: '‹' / '';
    background: linear-gradient(to right, var(--color-surface) 35%, transparent);
  }

  &::after {
    right: 0;
    justify-content: flex-end;
    content: '›';
    content: '›' / '';
    background: linear-gradient(to left, var(--color-surface) 35%, transparent);
  }

  &--more-before::before,
  &--more-after::after {
    opacity: 1;
  }

  &:not(.section-tabs--until-desktop) {
    @media (min-width: 48rem) {
      display: none;
    }
  }

  &--until-desktop {
    @media (min-width: 48rem) {
      // The page's side padding is wider from tablets up
      margin-inline: calc(var(--space-6) * -1);
    }

    @media (min-width: 64rem) {
      display: none;
    }
  }
}

.section-tabs--until-desktop .section-tabs__list {
  @media (min-width: 48rem) {
    padding-inline: var(--space-6);
  }
}

.section-tabs__list {
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

.section-tabs__tab {
  display: inline-flex;
  align-items: center;
  min-height: 2.5rem;
  padding: var(--space-1) var(--space-4);
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
