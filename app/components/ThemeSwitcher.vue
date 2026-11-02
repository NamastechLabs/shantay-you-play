<script setup lang="ts">
const { theme } = useTheme()
const selectId = useId()
</script>

<template>
  <div class="theme-switcher">
    <label :for="selectId" class="sr-only">Tema</label>
    <select :id="selectId" v-model="theme" class="field__input field__input--compact">
      <option v-for="name in THEMES" :key="name" :value="name">
        {{ THEME_LABELS[name] }}
      </option>
    </select>
  </div>
</template>
