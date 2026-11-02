<script setup lang="ts">
defineProps<{
  categories: { id: string, title: string, intro_text: string | null }[]
}>()
</script>

<template>
  <!-- One category: its title is already the heading, so only the intro is shown -->
  <p v-if="categories.length === 1" class="lead categories__single">
    {{ categories[0]!.intro_text }}
  </p>

  <ul v-else-if="categories.length" class="categories">
    <li v-for="category in categories" :key="category.id" class="categories__item">
      <h2 class="categories__title">
        {{ category.title }}
      </h2>
      <p v-if="category.intro_text" class="categories__intro">
        {{ category.intro_text }}
      </p>
    </li>
  </ul>
</template>

<style scoped lang="scss">
.categories__single {
  max-width: 40rem;
  white-space: pre-line;
}

.categories {
  display: grid;
  gap: var(--space-3);
  max-width: 40rem;
  padding: 0;
  margin: 0;
  list-style: none;
}

.categories__item {
  display: grid;
  gap: var(--space-1);
  padding-left: var(--space-3);
  border-left: 3px solid var(--color-primary);
}

.categories__title {
  font-size: 1.125rem;
  color: var(--color-title);
}

.categories__intro {
  color: var(--color-text-muted);
  white-space: pre-line;
}
</style>
