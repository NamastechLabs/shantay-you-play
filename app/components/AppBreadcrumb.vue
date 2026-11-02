<script setup lang="ts">
export interface BreadcrumbItem {
  label: string
  /** Omit on the last item: it is the current page */
  to?: string
}

defineProps<{ items: BreadcrumbItem[] }>()
</script>

<template>
  <nav class="breadcrumb" aria-label="Migas de pan">
    <ol class="breadcrumb__list">
      <li v-for="(item, index) in items" :key="index" class="breadcrumb__item">
        <NuxtLink v-if="item.to && index < items.length - 1" :to="item.to" class="breadcrumb__link">
          {{ item.label }}
        </NuxtLink>
        <span v-else class="breadcrumb__current" aria-current="page">{{ item.label }}</span>
      </li>
    </ol>
  </nav>
</template>
