<script setup lang="ts">
const { theme } = useTheme()

// Browser bar color of the installed app: the default theme's page color on the server, the active theme's after mount
const themeColor = ref('#eaf4ff')
useHead({ htmlAttrs: { 'data-theme': theme }, meta: [{ name: 'theme-color', content: themeColor }] })
onMounted(() => {
  watch(theme, () => {
    nextTick(() => {
      const color = getComputedStyle(document.documentElement).getPropertyValue('--color-page').trim()
      if (color) themeColor.value = color
    })
  }, { immediate: true })
})

const isDev = import.meta.dev
</script>

<template>
  <!-- Adds <link rel="manifest"> (DRG-18) -->
  <NuxtPwaAssets />
  <NuxtPage />
  <!-- Debugging helper: not part of production builds -->
  <DevImpersonate v-if="isDev" />
</template>
