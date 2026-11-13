<script setup lang="ts">
export interface LookPhoto {
  url: string
  label: string
}

defineProps<{
  open: boolean
  /** Queen name */
  title: string
  photos: LookPhoto[]
  categoryTitle?: string | null
  intro?: string | null
  /** Show the previous / next look arrows next to the name */
  canNavigate?: boolean
}>()

defineEmits<{ close: [], previous: [], next: [] }>()
</script>

<template>
  <AppModal wide :open="open" :title="title" @close="$emit('close')">
    <template v-if="canNavigate" #header-actions>
      <nav class="look-nav" aria-label="Navegar entre looks">
        <button type="button" class="look-nav__btn" aria-label="Look anterior" @click="$emit('previous')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="m15 5-7 7 7 7" />
          </svg>
        </button>
        <button type="button" class="look-nav__btn" aria-label="Look siguiente" @click="$emit('next')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="m9 5 7 7-7 7" />
          </svg>
        </button>
      </nav>
    </template>
    <LookGallery
      :title="title"
      :photos="photos"
      :category-title="categoryTitle"
      :intro="intro"
      :active="open"
    />
  </AppModal>
</template>
