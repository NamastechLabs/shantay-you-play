<script setup lang="ts">
const { theme } = useTheme()

useHead({ htmlAttrs: { 'data-theme': theme } })

const isDev = import.meta.dev
</script>

<template>
  <NuxtPage />
  <!-- Debugging helper: not part of production builds -->
  <DevImpersonate v-if="isDev" />
</template>
