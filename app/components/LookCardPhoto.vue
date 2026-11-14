<script setup lang="ts">
defineProps<{
  src: string
  alt: string
  /** Number of photos of the look; a badge shows when there are several */
  count: number
  /** Landscape photo (group photos) instead of the portrait look ratio */
  landscape?: boolean
}>()
</script>

<template>
  <span class="look-card__media" :class="{ 'look-card__media--landscape': landscape }">
    <img class="look-card__photo" :src="src" :alt="alt" loading="lazy">
    <!-- Passive cue only: pagination lives in the look dialog -->
    <span v-if="count > 1" class="look-card__count" role="img" :aria-label="`${count} fotos`">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <rect x="8" y="3" width="13" height="13" rx="2.5" />
        <path d="M16 20H6.5A2.5 2.5 0 0 1 4 17.5V8" />
      </svg>
      {{ count }}
    </span>
  </span>
</template>
