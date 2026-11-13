import type { GroupPhotos, GroupPhotoSlot } from '~/utils/groupPhotos'

export interface SaveGroupPhotosInput {
  /** The saved row of the group, or null when it has no photos yet */
  photos: GroupPhotos | null
  categoryId: string
  groupId: string
  /** New photos by slot (replacing whatever the slot held) */
  files: Partial<Record<GroupPhotoSlot, File>>
  /** Slots to empty */
  removed: GroupPhotoSlot[]
}

const COLUMNS = 'group_id, category_id, image_url, image2_url, image3_url, image4_url'

/**
 * Uploads the landscape photos of a group to the 'runway-looks' bucket under
 * {category_id}/{group_id}/ and writes the group's row. RLS lets the group's
 * members do it during 'werk_room' and judges until voting opens.
 */
export function useGroupPhotos() {
  const supabase = useSupabaseClient()
  const bucketName = useRuntimeConfig().public.runwayLooksBucket
  const bucket = () => supabase.storage.from(bucketName)

  function pathFromPublicUrl(publicUrl: string | null | undefined): string | null {
    if (!publicUrl) return null
    const marker = `/object/public/${bucketName}/`
    const index = publicUrl.indexOf(marker)
    return index === -1 ? null : decodeURIComponent(publicUrl.slice(index + marker.length))
  }

  async function storeImage(categoryId: string, groupId: string, file: File) {
    await assertGroupPhotoRatio(file)
    const image = await compressImage(file)
    const extension = image.mimeType === 'image/webp' ? 'webp' : 'jpg'
    // Unique name per upload, so replaced photos are never served stale from the CDN
    const path = `${categoryId}/${groupId}/${crypto.randomUUID()}.${extension}`

    const { error: uploadError } = await bucket().upload(path, image.blob, {
      contentType: image.mimeType,
      cacheControl: '31536000',
      upsert: false,
    })
    if (uploadError) throw uploadError

    return { path, publicUrl: bucket().getPublicUrl(path).data.publicUrl }
  }

  const saving = ref(false)

  /** Saves the changes of one group; returns the stored row. Errors are re-thrown. */
  async function saveGroupPhotos({ photos, categoryId, groupId, files, removed }: SaveGroupPhotosInput): Promise<GroupPhotos> {
    saving.value = true
    const stored: string[] = []
    try {
      const changes: Partial<Record<GroupPhotoSlot, string | null>> = {}
      try {
        for (const { key } of GROUP_PHOTO_SLOTS) {
          const file = files[key]
          if (!file) continue
          const image = await storeImage(categoryId, groupId, file)
          stored.push(image.path)
          changes[key] = image.publicUrl
        }
      }
      catch (err) {
        await bucket().remove(stored)
        throw err
      }
      for (const slot of removed) {
        if (!files[slot]) changes[slot] = null
      }

      try {
        const result = photos
          ? await supabase.from('category_group_photos').update(changes).eq('group_id', groupId).select(COLUMNS).single()
          : await supabase.from('category_group_photos').insert({ group_id: groupId, category_id: categoryId, ...changes }).select(COLUMNS).single()
        if (result.error) throw result.error

        // The row is saved, so a failed cleanup must not fail the save
        const replaced = GROUP_PHOTO_SLOTS.flatMap(({ key }) => (key in changes ? photos?.[key] ?? [] : []))
        const paths = replaced.flatMap(url => pathFromPublicUrl(url) ?? [])
        if (paths.length) await bucket().remove(paths).catch(() => undefined)
        return result.data
      }
      catch (err) {
        await bucket().remove(stored)
        throw err
      }
    }
    finally {
      saving.value = false
    }
  }

  return { saving: readonly(saving), saveGroupPhotos }
}
