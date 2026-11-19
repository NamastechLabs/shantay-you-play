<script setup lang="ts">
// Manual install steps for iPhone / iPad, opened from the "Instalar app" menu item
const { iosHintOpen } = useInstallApp()
const copy = PWA_COPY
</script>

<template>
  <AppModal :open="iosHintOpen" :title="copy.iosTitle" @close="iosHintOpen = false">
    <p>{{ copy.iosIntro }}</p>
    <ol class="install-steps">
      <li v-for="step in copy.iosSteps" :key="step">
        {{ step }}
      </li>
    </ol>
    <p class="hint">
      {{ copy.iosNote }}
    </p>
    <button type="button" class="btn btn--primary btn--block" @click="iosHintOpen = false">
      {{ copy.iosClose }}
    </button>
  </AppModal>
</template>
