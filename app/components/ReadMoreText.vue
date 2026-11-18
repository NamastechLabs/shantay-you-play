<script setup lang="ts">
/**
 * A paragraph that, on phones (below 48rem), shows only its first sentence followed by a "Leer más" link,
 * and the rest when the link is tapped. From tablets up the whole text is shown and there is no link.
 * Done in CSS, so the server render and the first paint already match the screen.
 */
defineProps<{
  /** First sentence, always visible */
  intro: string
  /** The rest of the text */
  more: string
}>()

const open = ref(false)
const moreId = useId()
</script>

<template>
  <p class="read-more">
    {{ intro }}
    <button
      v-if="!open && more"
      type="button"
      class="read-more__link"
      :aria-expanded="false"
      :aria-controls="moreId"
      @click="open = true"
    >Leer más</button>
    <span :id="moreId" class="read-more__rest" :class="{ 'read-more__rest--closed': !open }">{{ more }}</span>
    {{ ' ' }}
    <button
      v-if="open && more"
      type="button"
      class="read-more__link"
      :aria-expanded="true"
      :aria-controls="moreId"
      @click="open = false"
    >Leer menos</button>
  </p>
</template>

<style scoped lang="scss">
.read-more__link {
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

// Wide screens show everything, so there is nothing to open
@media (min-width: 48rem) {
  .read-more__link {
    display: none;
  }
}

@media (max-width: 47.99rem) {
  .read-more__rest--closed {
    display: none;
  }
}
</style>
