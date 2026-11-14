<script setup lang="ts">
const props = defineProps<{
  categoryId: string
  /** Heading level of each group name */
  level?: 3 | 4
  /** Optional heading above the photos (e.g. "Los grupos") */
  heading?: string
  /** Heading level of `heading` */
  headingLevel?: 2 | 3
}>()

const supabase = useSupabaseClient()

interface GroupWithPhotos {
  id: string
  name: string
  urls: string[]
  /** Won the jury's band vote (both bands on a draw); only known from 'reveal' */
  winner: boolean
}

// RLS only returns the photos the signed-in person may see (from 'voting' on for everyone but the group itself)
const { data } = await useAsyncData(`category-group-photos-${props.categoryId}`, async () => {
  const [groups, photos, result] = await Promise.all([
    supabase.from('category_groups').select('id, name').eq('category_id', props.categoryId).order('position'),
    supabase.from('category_group_photos').select('group_id, image_url, image2_url, image3_url, image4_url').eq('category_id', props.categoryId),
    // Empty until the runway reaches 'reveal', so nobody gets a crown before the band is revealed
    supabase.rpc('category_group_result', { p_category_id: props.categoryId }),
  ])
  if (groups.error) throw groups.error
  if (photos.error) throw photos.error
  if (result.error) throw result.error

  return groups.data
    .map(group => ({
      ...group,
      urls: groupPhotoUrls(photos.data.find(row => row.group_id === group.id)),
      winner: result.data.some(row => row.group_id === group.id && row.is_winner),
    }))
    .filter(group => group.urls.length > 0) as GroupWithPhotos[]
})

// Same pattern as the looks: the card shows the first photo with a counter, the dialog shows all of them
const fullGroup = ref<GroupWithPhotos | null>(null)
const dialogPhotos = computed(() => (fullGroup.value?.urls ?? []).map((url, index) => ({ url, label: `Foto ${index + 1}` })))
</script>

<template>
  <div v-if="data?.length" class="group-photos">
    <component :is="`h${headingLevel ?? 2}`" v-if="heading" class="group-photos__title">
      {{ heading }}
    </component>
    <div class="group-photos-view">
      <article v-for="group in data" :key="group.id" class="look-card">
        <span v-if="group.winner" class="look-card__crown" role="img" aria-label="Banda ganadora">♛</span>
        <button type="button" class="look-card__open" :aria-label="`Ver las fotos del grupo ${group.name}`" @click="fullGroup = group">
          <LookCardPhoto
            :src="group.urls[0]!"
            :alt="`Foto del grupo ${group.name}`"
            :count="group.urls.length"
            landscape
          />
        </button>
        <!-- A heading cannot live inside a button, so the name sits under the photo -->
        <component :is="`h${level ?? 3}`" class="look-card__body group-photos-view__name">
          {{ group.name }}
        </component>
      </article>

      <LookGalleryDialog
        :open="fullGroup !== null"
        :title="fullGroup?.name ?? ''"
        :photos="dialogPhotos"
        @close="fullGroup = null"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.group-photos {
  display: grid;
  gap: var(--space-3);
}

.group-photos__title {
  font-size: 1.25rem;
}

.group-photos-view {
  display: grid;
  gap: var(--space-4);

  @media (min-width: 64rem) {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

.group-photos-view__name {
  font-size: 1.125rem;
  color: var(--color-title);
}
</style>
