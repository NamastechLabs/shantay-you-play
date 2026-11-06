<script setup lang="ts">
import type { LookPhoto } from '~/components/LookGalleryDialog.vue'

export interface JuryMember {
  id: string
  name: string
  intro: string
  photos: LookPhoto[]
  /** Only set when the runway has several categories and the list mixes them */
  categoryTitle?: string | null
}

const props = withDefaults(defineProps<{
  members: JuryMember[]
  title: string
  /** Heading level, so the section nests under the page's own headings */
  level?: 2 | 3
}>(), { level: 2 })

const titleId = useId()
const open = ref<JuryMember | null>(null)

// Step through the jury in list order, wrapping around at both ends
function showAdjacent(step: 1 | -1): void {
  const current = props.members.findIndex(member => member.id === open.value?.id)
  if (current === -1) return
  open.value = props.members[(current + step + props.members.length) % props.members.length] ?? null
}
</script>

<template>
  <section v-if="members.length" class="jury" :aria-labelledby="titleId">
    <component :is="`h${level}`" :id="titleId" class="jury__title">
      {{ title }}
    </component>
    <ul class="jury__list">
      <li v-for="member in members" :key="member.id">
        <button type="button" class="jury__card" @click="open = member">
          <LookCardPhoto
            v-if="member.photos[0]"
            class="jury__media"
            :src="member.photos[0].url"
            :alt="`Look de ${member.name}`"
            :count="member.photos.length"
          />
          <span class="jury__body">
            <strong class="jury__name">{{ member.name }}</strong>
            <span v-if="member.categoryTitle" class="muted">{{ member.categoryTitle }}</span>
            <span class="jury__intro">{{ member.intro }}</span>
          </span>
        </button>
      </li>
    </ul>

    <LookGalleryDialog
      :open="open !== null"
      :title="open?.name ?? ''"
      :photos="open?.photos ?? []"
      :category-title="open?.categoryTitle"
      :intro="open?.intro"
      :can-navigate="members.length > 1"
      @previous="showAdjacent(-1)"
      @next="showAdjacent(1)"
      @close="open = null"
    />
  </section>
</template>

<style scoped>
.jury {
  display: grid;
  gap: var(--space-4);
  justify-self: stretch;
}

.jury__title {
  font-size: 1.25rem;
}

.jury__list {
  display: grid;
  gap: var(--space-4);
  padding: 0;
  margin: 0;
  list-style: none;

  @media (min-width: 48rem) {
    grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
  }
}

.jury__card {
  display: grid;
  grid-template-columns: 10rem 1fr;
  gap: var(--space-3);
  align-items: start;
  width: 100%;
  height: 100%;
  padding: var(--space-3);
  color: inherit;
  text-align: left;
  cursor: pointer;
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);
  transition: transform 0.15s, box-shadow 0.15s;

  &:hover {
    box-shadow: var(--shadow-raised);
    transform: translateY(-2px);
  }
}

.jury__media {
  align-self: start;
  justify-self: center;
  width: 100%;
  overflow: hidden;
  border-radius: var(--radius-sm);
}

.jury__media :deep(.look-card__count) {
  right: var(--space-2);
  bottom: var(--space-2);
  padding: 0 var(--space-2);
  font-size: 0.75rem;
}

.jury__body {
  display: grid;
  gap: var(--space-2);
}

.jury__name {
  font-family: var(--font-display);
  font-size: 1.125rem;
  line-height: 1.3;
  color: var(--color-title);
}

/* The full intro is in the gallery dialog */
.jury__intro {
  display: -webkit-box;
  overflow: hidden;
  white-space: pre-line;
  -webkit-line-clamp: 5;
  line-clamp: 5;
  -webkit-box-orient: vertical;
}
</style>
