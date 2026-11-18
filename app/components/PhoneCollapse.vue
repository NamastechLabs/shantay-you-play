<script setup lang="ts">
/**
 * Long detail that is hidden behind a button on phones (below 48rem) and always shown from tablets up.
 * Done in CSS, so the server render and the first paint already match the screen.
 */
defineProps<{
  showLabel: string
  hideLabel: string
}>()

const open = ref(false)
const contentId = useId()
</script>

<template>
  <div class="phone-collapse">
    <div :id="contentId" class="phone-collapse__content" :class="{ 'phone-collapse__content--closed': !open }">
      <slot />
    </div>
    <button
      type="button"
      class="btn btn--secondary btn--block phone-collapse__toggle"
      :aria-expanded="open"
      :aria-controls="contentId"
      @click="open = !open"
    >
      {{ open ? hideLabel : showLabel }}
    </button>
  </div>
</template>

<style scoped lang="scss">
.phone-collapse {
  display: grid;
  gap: var(--space-3);
}

.phone-collapse__content {
  display: grid;
  gap: var(--space-3);
  min-width: 0;
}

@media (max-width: 47.99rem) {
  .phone-collapse__content--closed {
    display: none;
  }
}

@media (min-width: 48rem) {
  .phone-collapse__toggle {
    display: none;
  }
}
</style>
