<script setup lang="ts">
const props = defineProps<{
  categoryId: string
  /** Heading level of each group name */
  level?: 3 | 4
}>()

const supabase = useSupabaseClient()

// RLS only returns the photos the signed-in person may see (from 'voting' on for everyone but the group itself)
const { data } = await useAsyncData(`category-group-photos-${props.categoryId}`, async () => {
  const [groups, photos] = await Promise.all([
    supabase.from('category_groups').select('id, name').eq('category_id', props.categoryId).order('position'),
    supabase.from('category_group_photos').select('group_id, image_url, image2_url, image3_url, image4_url').eq('category_id', props.categoryId),
  ])
  if (groups.error) throw groups.error
  if (photos.error) throw photos.error

  return groups.data
    .map(group => ({ ...group, urls: groupPhotoUrls(photos.data.find(row => row.group_id === group.id)) }))
    .filter(group => group.urls.length > 0)
})
</script>

<template>
  <div v-if="data?.length" class="group-photos-view">
    <figure v-for="group in data" :key="group.id" class="group-photos-view__group">
      <GroupPhotosCollage :urls="group.urls" :name="group.name" />
      <figcaption>
        <component :is="`h${level ?? 3}`" class="group-photos-view__name">
          {{ group.name }}
        </component>
      </figcaption>
    </figure>
  </div>
</template>

<style scoped lang="scss">
.group-photos-view {
  display: grid;
  gap: var(--space-4);

  @media (min-width: 64rem) {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

.group-photos-view__group {
  display: grid;
  gap: var(--space-2);
  margin: 0;
}

.group-photos-view__name {
  font-size: 1.125rem;
  color: var(--color-title);
}
</style>
