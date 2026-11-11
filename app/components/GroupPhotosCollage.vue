<script setup lang="ts">
defineProps<{
  /** Up to 4 photo URLs in order */
  urls: string[]
  /** Group name, used in the photo descriptions */
  name: string
}>()
</script>

<template>
  <!-- The photos touch each other, so together they read as one picture of the group -->
  <ul v-if="urls.length" class="collage" :class="`collage--${urls.length}`" :aria-label="`Fotos del grupo ${name}`">
    <li v-for="(url, index) in urls" :key="url" class="collage__tile">
      <img :src="url" :alt="`Foto ${index + 1} del grupo ${name}`" loading="lazy">
    </li>
  </ul>
</template>

<style scoped lang="scss">
.collage {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  padding: 0;
  margin: 0;
  overflow: hidden;
  list-style: none;
  background-color: var(--color-surface);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);
}

.collage__tile {
  aspect-ratio: 16 / 9;

  img {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

// One or two photos use the full width; with three, the first one spans the top row
.collage--1 .collage__tile,
.collage--2 .collage__tile,
.collage--3 .collage__tile:first-child {
  grid-column: span 2;
}
</style>
