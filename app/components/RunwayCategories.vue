<script setup lang="ts">
defineProps<{
  categories: { id: string, title: string, intro_text: string | null }[]
}>()
</script>

<template>
  <!-- One category: its title is already the heading, so only the intro is shown -->
  <CollapsibleText v-if="categories.length === 1" class="lead categories__single" :text="categories[0]!.intro_text ?? ''" />

  <!-- Several categories: one numbered card each, side by side on wide screens -->
  <ul v-else-if="categories.length" class="categories">
    <li v-for="(category, index) in categories" :key="category.id" class="categories__item">
      <span class="categories__number" aria-hidden="true">{{ index + 1 }}</span>
      <h2 class="categories__title">
        {{ category.title }}
      </h2>
      <CollapsibleText v-if="category.intro_text" class="categories__intro" :text="category.intro_text" />
    </li>
  </ul>
</template>

<style scoped lang="scss">
.categories__single {
  max-width: 40rem;
}

.categories {
  display: grid;
  gap: var(--space-3);
  width: 100%;
  padding: 0;
  margin: 0;
  list-style: none;

  @media (min-width: 48rem) {
    grid-template-columns: repeat(auto-fit, minmax(18rem, 1fr));
    gap: var(--space-4);
  }
}

.categories__item {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  column-gap: var(--space-3);
  row-gap: var(--space-2);
  align-items: center;
  align-content: start;
  padding: var(--space-4);
  background-color: color-mix(in srgb, var(--color-surface) 70%, transparent);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.categories__number {
  display: grid;
  place-items: center;
  width: 2rem;
  height: 2rem;
  font-family: var(--font-display);
  font-weight: 700;
  color: var(--color-on-primary);
  background-color: var(--color-primary);
  border-radius: var(--radius-pill);
}

.categories__title {
  font-size: 1.125rem;
  overflow-wrap: anywhere;
  color: var(--color-title);
}

// The intro takes the full width of the card, under the number and the title
.categories__intro {
  grid-column: 1 / -1;
  color: var(--color-text-muted);
}
</style>
