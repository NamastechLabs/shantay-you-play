<script setup lang="ts">
/**
 * Text cut to a number of lines, with the link right after the ellipsis ("… Leer reto completo").
 * The cut is done by measuring, so the link always sits at the end of the last line, whatever the background.
 * - default: the link expands and collapses the text.
 * - `inert`: for text inside a clickable card (a link or button inside it would be invalid): the link is only
 *   a hint ("… Ver más") and the card's own click opens the full text.
 */
const props = withDefaults(defineProps<{
  text: string
  /** Lines shown before the text is cut */
  lines?: number
  /** Cut only on phones (below 48rem); wide screens show the whole text */
  phonesOnly?: boolean
  inert?: boolean
  expandLabel?: string
  collapseLabel?: string
}>(), {
  lines: 3,
  phonesOnly: true,
  inert: false,
  expandLabel: undefined,
  collapseLabel: 'Leer menos',
})

const PHONE_QUERY = '(max-width: 47.99rem)'

const expanded = ref(false)
const ready = ref(false)
const cutAt = ref<number | null>(null)
const textId = useId()
const root = ref<HTMLElement | null>(null)
const probeText = ref<HTMLElement | null>(null)
const probeLink = ref<HTMLElement | null>(null)

const tag = computed(() => (props.inert ? 'span' : 'div'))
const textTag = computed(() => (props.inert ? 'span' : 'p'))
const expandText = computed(() => props.expandLabel ?? (props.inert ? 'Ver más' : 'Leer reto completo'))
const isCut = computed(() => cutAt.value !== null)
const shown = computed(() => (cutAt.value === null || expanded.value ? props.text : `${props.text.slice(0, cutAt.value)}…`))

/** Does `candidate` (plus the link, when asked) fit in the allowed lines? */
function fits(candidate: string, withLink: boolean, maxHeight: number): boolean {
  if (!probeText.value || !probeLink.value) return true
  probeText.value.textContent = candidate
  probeLink.value.style.display = withLink ? '' : 'none'
  return (probeText.value.parentElement?.scrollHeight ?? 0) <= maxHeight
}

function layout(): void {
  const probe = probeText.value?.parentElement
  if (!probe) return
  const wide = props.phonesOnly && !window.matchMedia(PHONE_QUERY).matches
  cutAt.value = null

  if (!wide) {
    const style = getComputedStyle(probe)
    const lineHeight = Number.parseFloat(style.lineHeight) || Number.parseFloat(style.fontSize) * 1.5
    const maxHeight = lineHeight * props.lines + 1

    if (!fits(props.text, false, maxHeight)) {
      // Longest start of the text that still fits with its "…" and the link
      let low = 0
      let high = props.text.length
      while (low < high) {
        const middle = Math.ceil((low + high) / 2)
        if (fits(`${props.text.slice(0, middle).trimEnd()}… `, true, maxHeight)) low = middle
        else high = middle - 1
      }
      // Do not cut a word in half
      let cut = props.text.slice(0, low)
      const lastSpace = cut.search(/\s\S*$/)
      if (lastSpace > 0 && low < props.text.length) cut = cut.slice(0, lastSpace)
      cut = cut.replace(/[\s,;:]+$/, '')
      // Never leave half an emoji (a lone high surrogate) at the end
      if (/[\uD800-\uDBFF]$/.test(cut)) cut = cut.slice(0, -1)
      cutAt.value = cut.length
    }
  }
  ready.value = true
}

let observer: ResizeObserver | undefined
let lastWidth = 0

onMounted(() => {
  layout()
  if (root.value && 'ResizeObserver' in window) {
    lastWidth = root.value.clientWidth
    // Only a change of width changes the cut (expanding the text changes the height, not the width)
    observer = new ResizeObserver(() => {
      const width = root.value?.clientWidth ?? 0
      if (width !== lastWidth) {
        lastWidth = width
        layout()
      }
    })
    observer.observe(root.value)
  }
})
onBeforeUnmount(() => observer?.disconnect())
watch(() => props.text, () => {
  expanded.value = false
  if (ready.value) nextTick(layout)
})
</script>

<template>
  <component :is="tag" ref="root" class="collapsible">
    <component
      :is="textTag"
      :id="textId"
      class="collapsible__text"
      :class="{ 'collapsible__text--fallback': !ready, 'collapsible__text--phones': phonesOnly }"
      :style="{ '--collapsible-lines': lines }"
    >
      {{ shown }}
      <template v-if="isCut">
        <button
          v-if="!inert"
          type="button"
          class="collapsible__link"
          :aria-expanded="expanded"
          :aria-controls="textId"
          @click="expanded = !expanded"
        >
          {{ expanded ? collapseLabel : expandText }}
        </button>
        <span v-else-if="!expanded" class="collapsible__link" aria-hidden="true">{{ expandText }}</span>
      </template>
    </component>

    <!-- Invisible copy used to measure where the text has to be cut -->
    <component :is="textTag" class="collapsible__text collapsible__probe" aria-hidden="true">
      <span ref="probeText" /><span ref="probeLink" class="collapsible__link">{{ expandText }}</span>
    </component>
  </component>
</template>

<style scoped lang="scss">
.collapsible {
  position: relative;
  display: block;
  width: 100%;
}

.collapsible__text {
  display: block;
  margin: 0;
  white-space: pre-line;
}

// Until the cut is measured (server render, first paint) a plain clamp avoids a jump
.collapsible__text--fallback {
  display: -webkit-box;
  overflow: hidden;
  -webkit-line-clamp: var(--collapsible-lines);
  line-clamp: var(--collapsible-lines);
  -webkit-box-orient: vertical;
}

// Wide screens show the whole text
@media (min-width: 48rem) {
  .collapsible__text--fallback.collapsible__text--phones {
    display: block;
    overflow: visible;
  }
}

.collapsible__probe {
  position: absolute;
  inset: 0 0 auto;
  pointer-events: none;
  visibility: hidden;
}

.collapsible__link {
  padding: 0;
  font: inherit;
  font-weight: 700;
  color: var(--color-kicker);
  text-decoration: underline;
  text-underline-offset: 0.2em;
  white-space: nowrap;
  cursor: pointer;
  background: none;
  border: 0;
}

span.collapsible__link {
  cursor: inherit;
}
</style>
