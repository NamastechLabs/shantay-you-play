<script setup lang="ts">
const props = defineProps<{
  open: boolean
  title: string
}>()

const emit = defineEmits<{ close: [] }>()

const dialog = ref<HTMLDialogElement | null>(null)
const titleId = useId()

/** The panel stays rendered while it slides out */
const rendered = ref(props.open)
const closing = ref(false)

function sync(open: boolean): void {
  const element = dialog.value
  if (!element) return

  if (open) {
    closing.value = false
    rendered.value = true
    if (!element.open) element.showModal()
    return
  }

  if (!element.open || closing.value) return
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    finishClose()
    return
  }
  // finishClose() runs on animationend; the timeout is a safety net if it never fires
  closing.value = true
  window.setTimeout(finishClose, 400)
}

function finishClose(): void {
  const element = dialog.value
  if (!closing.value && element?.open && props.open) return
  closing.value = false
  rendered.value = false
  if (element?.open) element.close()
}

function onAnimationEnd(event: AnimationEvent): void {
  if (closing.value && event.target === dialog.value) finishClose()
}

// flush: 'post' so the content is rendered before the panel opens
watch(() => props.open, sync, { flush: 'post' })
onMounted(() => sync(props.open))
</script>

<template>
  <!-- Side panel: fixed to the viewport, so the page behind never scrolls with it -->
  <dialog
    ref="dialog"
    class="drawer"
    :class="{ 'drawer--closing': closing }"
    :aria-labelledby="titleId"
    @click.self="emit('close')"
    @cancel.prevent="emit('close')"
    @close="emit('close')"
    @animationend="onAnimationEnd"
  >
    <div v-if="rendered" class="drawer__panel">
      <header class="drawer__header">
        <h2 :id="titleId">
          {{ title }}
        </h2>
        <button type="button" class="drawer__close" aria-label="Cerrar" @click="emit('close')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M6 6l12 12M18 6 6 18" />
          </svg>
        </button>
      </header>
      <div class="drawer__content">
        <slot />
      </div>
      <footer v-if="$slots.footer" class="drawer__footer">
        <slot name="footer" />
      </footer>
    </div>
  </dialog>
</template>
