<script setup lang="ts">
defineProps<{
  steps: { id: string, label: string, done: boolean }[]
  /** Index of the current step */
  current: number
  /** Accessible name of the navigation landmark */
  label: string
}>()

defineEmits<{ select: [index: number] }>()
</script>

<template>
  <nav :aria-label="label">
    <ol class="stepper stepper--free">
      <li v-for="(step, index) in steps" :key="step.id">
        <button
          type="button"
          class="stepper__step"
          :class="[step.done ? 'stepper__step--done' : null, index === current ? 'stepper__step--current' : null]"
          :aria-current="index === current ? 'step' : undefined"
          @click="$emit('select', index)"
        >
          <span class="stepper__index" aria-hidden="true">{{ step.done ? '✓' : index + 1 }}</span>
          {{ step.label }}
          <span v-if="step.done" class="sr-only">(hecho)</span>
        </button>
      </li>
    </ol>
  </nav>
</template>
