<script setup lang="ts">
const props = defineProps<{
  open: boolean
  title: string
}>()

const emit = defineEmits<{ close: [] }>()

const dialog = ref<HTMLDialogElement | null>(null)
const titleId = useId()

function sync(open: boolean): void {
  const element = dialog.value
  if (!element) return
  if (open && !element.open) element.showModal()
  else if (!open && element.open) element.close()
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
    :aria-labelledby="titleId"
    @click.self="emit('close')"
    @close="emit('close')"
  >
    <div v-if="open" class="drawer__panel">
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
