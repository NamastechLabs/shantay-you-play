<script setup lang="ts">
import type { RunwayStatus } from '~/utils/runwayStatus'

defineProps<{ status: RunwayStatus }>()
</script>

<template>
  <span class="badge" :class="`badge--${status}`">
    {{ RUNWAY_STATUS_LABELS[status] }}
  </span>
</template>
