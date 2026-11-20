<script setup lang="ts">
const { current, offset, dismiss } = useSnackbar()

const host = ref<HTMLElement | null>(null)

/**
 * A modal <dialog> sits in the top layer and makes everything outside it inert, so a snackbar raised from a modal
 * (a save error in a form) would be hidden and its close button unusable. While a modal is open the host lives
 * inside it; otherwise it lives in <body>.
 */
function place() {
  const el = host.value
  if (!el) return
  const target = document.querySelector('dialog[open]:modal') ?? document.body
  if (el.parentElement !== target) target.appendChild(el)
}

onMounted(() => {
  watch(current, () => nextTick(place))
  // `close` does not bubble: listen in the capture phase to move the message out of the dialog that is closing
  document.addEventListener('close', place, true)
})
onBeforeUnmount(() => document.removeEventListener('close', place, true))

const icons = {
  success: 'm5 12.5 4.5 4.5L19 7.5',
  error: 'M12 7v6M12 17h.01',
  info: 'M12 11v6M12 7h.01',
}
</script>

<template>
  <div ref="host" class="snackbar-host" :style="{ '--snackbar-offset': `${offset}px` }">
    <!-- Both live regions stay in the page (empty) so screen readers announce the text inserted into them:
         polite for success and info, assertive for errors -->
    <div v-for="region in (['status', 'alert'] as const)" :key="region" class="snackbar-region" :role="region">
      <Transition name="snackbar">
        <div
          v-if="current && (current.type === 'error') === (region === 'alert')"
          :key="current.id"
          class="snackbar"
          :class="`snackbar--${current.type}`"
        >
          <span class="snackbar__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path :d="icons[current.type]" /></svg>
          </span>
          <p class="snackbar__text">
            {{ current.message }}
          </p>
          <button
            v-if="current.type === 'error'"
            type="button"
            class="snackbar__close"
            aria-label="Cerrar mensaje"
            @click="dismiss"
          >
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg>
          </button>
        </div>
      </Transition>
    </div>
  </div>
</template>
