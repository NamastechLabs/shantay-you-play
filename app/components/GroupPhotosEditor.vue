<script setup lang="ts">
const props = defineProps<{
  categoryId: string
  groupId: string
  groupName: string
  /** The saved row of the group, or null when it has no photos yet */
  photos: GroupPhotos | null
  editable: boolean
  /** 'collage' shows all the photos joined; 'gallery' one big photo with clickable thumbnails */
  display?: 'collage' | 'gallery'
}>()

const emit = defineEmits<{ changed: [] }>()

const { saveGroupPhotos, saving } = useGroupPhotos()

const files = ref<Partial<Record<GroupPhotoSlot, File>>>({})
const removed = ref<Set<GroupPhotoSlot>>(new Set())
const previews = ref<Partial<Record<GroupPhotoSlot, string>>>({})
const errorMessage = ref<string | null>(null)
// Bumping the key remounts the file inputs, which is the only way to clear them
const inputKey = ref(0)

function revokePreviews(): void {
  for (const url of Object.values(previews.value)) URL.revokeObjectURL(url)
  previews.value = {}
}
onBeforeUnmount(revokePreviews)

function reset(): void {
  revokePreviews()
  files.value = {}
  removed.value = new Set()
  errorMessage.value = null
  inputKey.value++
}

// The saved photos changed (after a save): drop the pending edits
watch(() => props.photos, reset)

const srcFor = (slot: GroupPhotoSlot): string | null =>
  previews.value[slot] ?? (removed.value.has(slot) ? null : props.photos?.[slot] ?? null)

const currentUrls = computed(() => GROUP_PHOTO_SLOTS.flatMap(slot => srcFor(slot.key) ?? []))
// Gallery display: the photo shown big; clamped when photos are removed
const selected = ref(0)
watch(currentUrls, (urls) => {
  if (selected.value > urls.length - 1) selected.value = Math.max(urls.length - 1, 0)
})

const changed = computed(() => Object.keys(files.value).length > 0 || removed.value.size > 0)

async function onFileChange(slot: GroupPhotoSlot, event: Event): Promise<void> {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return

  errorMessage.value = null
  try {
    await assertGroupPhotoRatio(file)
  }
  catch (error) {
    errorMessage.value = toErrorMessage(error)
    input.value = ''
    return
  }

  if (previews.value[slot]) URL.revokeObjectURL(previews.value[slot]!)
  files.value = { ...files.value, [slot]: file }
  previews.value = { ...previews.value, [slot]: URL.createObjectURL(file) }
  removed.value.delete(slot)
}

function removeSlot(slot: GroupPhotoSlot): void {
  if (previews.value[slot]) URL.revokeObjectURL(previews.value[slot]!)
  const { [slot]: _file, ...restFiles } = files.value
  const { [slot]: _preview, ...restPreviews } = previews.value
  files.value = restFiles
  previews.value = restPreviews
  // Only slots that hold a saved photo need to be emptied in the database
  if (props.photos?.[slot]) removed.value = new Set(removed.value).add(slot)
  inputKey.value++
}

async function save(): Promise<void> {
  if (!changed.value || saving.value) return
  errorMessage.value = null
  try {
    await saveGroupPhotos({
      photos: props.photos,
      categoryId: props.categoryId,
      groupId: props.groupId,
      files: files.value,
      removed: [...removed.value],
    })
    emit('changed')
  }
  catch (error) {
    errorMessage.value = toErrorMessage(error)
  }
}
</script>

<template>
  <div class="group-photos">
    <template v-if="display === 'gallery' && currentUrls.length">
      <img class="group-photos__main" :src="currentUrls[selected]" :alt="`Foto ${selected + 1} del grupo ${groupName}`">
      <ul v-if="currentUrls.length > 1" class="group-photos__thumbs" aria-label="Fotos del grupo">
        <li v-for="(url, index) in currentUrls" :key="url">
          <button
            type="button"
            class="group-photos__thumb"
            :class="{ 'group-photos__thumb--active': index === selected }"
            :aria-label="`Ver foto ${index + 1}`"
            :aria-pressed="index === selected"
            @click="selected = index"
          >
            <img :src="url" alt="">
          </button>
        </li>
      </ul>
    </template>
    <GroupPhotosCollage v-else-if="display !== 'gallery'" :urls="currentUrls" :name="groupName" />
    <p v-if="!currentUrls.length" class="hint">
      Aún no hay fotos del grupo.
    </p>

    <template v-if="editable">
      <p class="hint">
        Hasta 4 fotos apaisadas (16:9 o 5:3) que se muestran juntas.
      </p>
      <ul class="group-photos__slots">
        <li v-for="slot in GROUP_PHOTO_SLOTS" :key="`${slot.key}-${inputKey}`" class="group-photos__slot">
          <span class="group-photos__frame">
            <img v-if="srcFor(slot.key)" :src="srcFor(slot.key)!" :alt="`${slot.label} del grupo ${groupName}`">
            <span v-else class="group-photos__empty">{{ slot.label }}</span>
          </span>
          <span class="group-photos__actions">
            <label class="btn btn--secondary btn--small group-photos__pick">
              {{ srcFor(slot.key) ? 'Cambiar' : 'Elegir' }}
              <input
                class="sr-only"
                type="file"
                accept="image/*"
                :aria-label="`${srcFor(slot.key) ? 'Cambiar' : 'Elegir'} ${slot.label.toLowerCase()} del grupo ${groupName}`"
                @change="onFileChange(slot.key, $event)"
              >
            </label>
            <button
              v-if="srcFor(slot.key)"
              type="button"
              class="btn btn--ghost btn--danger btn--small"
              :aria-label="`Quitar ${slot.label.toLowerCase()} del grupo ${groupName}`"
              :title="`Quitar ${slot.label.toLowerCase()}`"
              @click="removeSlot(slot.key)"
            >
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v6M14 11v6" />
              </svg>
            </button>
          </span>
        </li>
      </ul>

      <p v-if="errorMessage" class="form-error" role="alert">
        {{ errorMessage }}
      </p>
      <div class="group-photos__footer">
        <button type="button" class="btn btn--ghost" :disabled="!changed || saving" @click="reset">
          Descartar
        </button>
        <button type="button" class="btn btn--primary" :disabled="!changed || saving" @click="save">
          {{ saving ? 'Guardando…' : 'Guardar fotos' }}
        </button>
      </div>
    </template>
  </div>
</template>

<style scoped lang="scss">
.group-photos {
  display: grid;
  gap: var(--space-3);
}

.group-photos__main {
  display: block;
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);
}

.group-photos__thumbs {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--space-2);
  padding: 0;
  margin: 0;
  list-style: none;
}

.group-photos__thumb {
  display: block;
  width: 100%;
  padding: 0;
  overflow: hidden;
  aspect-ratio: 16 / 9;
  cursor: pointer;
  background: none;
  border: 2px solid transparent;
  border-radius: var(--radius-md);
  opacity: 0.7;

  img {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  &:hover,
  &--active {
    opacity: 1;
  }

  &--active {
    border-color: var(--color-primary);
  }
}

.group-photos__slots {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 12rem), 1fr));
  gap: var(--space-3);
  padding: 0;
  margin: 0;
  list-style: none;
}

.group-photos__slot {
  display: grid;
  gap: var(--space-2);
}

.group-photos__frame {
  display: grid;
  place-items: center;
  overflow: hidden;
  aspect-ratio: 16 / 9;
  background-color: var(--color-surface-raised);
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-md);

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.group-photos__empty {
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.group-photos__actions {
  display: flex;
  gap: var(--space-1);
  align-items: center;
}

.group-photos__pick {
  position: relative;
  cursor: pointer;
}

.group-photos__footer {
  display: flex;
  gap: var(--space-2);
  justify-content: flex-end;
}
</style>
