<script setup lang="ts">
import type { CategoryStatus } from '~/utils/categoryStatus'

defineProps<{ status: CategoryStatus }>()
</script>

<template>
  <span class="badge" :class="`badge--${status}`">
    {{ CATEGORY_STATUS_LABELS[status] }}
  </span>
</template>
