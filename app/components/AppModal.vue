<script setup lang="ts">
const props = defineProps<{
  open: boolean
  title: string
  /** Wider card on desktop, for side-by-side content */
  wide?: boolean
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

// flush: 'post' so the dialog content is rendered before it opens
watch(() => props.open, sync, { flush: 'post' })
onMounted(() => sync(props.open))
</script>

<template>
  <dialog
    ref="dialog"
    class="modal"
    :class="{ 'modal--wide': wide }"
    :aria-labelledby="titleId"
    @click.self="emit('close')"
    @close="emit('close')"
  >
    <div v-if="open" class="modal__body">
      <div class="modal__header">
        <h2 :id="titleId">
          {{ title }}
        </h2>
        <!-- Optional controls next to the title (e.g. previous / next arrows) -->
        <slot name="header-actions" />
        <button type="button" class="modal__close" aria-label="Cerrar" @click="emit('close')">
          ×
        </button>
      </div>
      <slot />
    </div>
  </dialog>
</template>
