import type { Tables } from '~/types/database.types'

export type Look = Tables<'looks'>
export type JuryLook = Tables<'jury_looks'>

export interface SaveLookInput {
  /** The look being edited, or null to create it (then the front photo is required) */
  look: Pick<Look, 'id'> & LookImages | null
  categoryId: string
  participantId: string
  /** New photos, by slot (replacing whatever the slot held) */
  files: Partial<Record<LookSlot, File>>
  /** Slots to empty; the front photo can only be replaced, never removed */
  removed: LookSlot[]
  intro: string | null
}

export interface UploadJuryLookInput {
  categoryId: string
  participantId: string
  file: File
  intro: string
}

const QUEEN_COLUMNS = 'id, category_id, participant_id, image_url, image2_url, image3_url, image4_url, intro, uploaded_by, created_at, updated_at'
const JURY_COLUMNS = 'id, category_id, participant_id, image_url, intro, uploaded_by, created_at, updated_at'

/**
 * Judge-only: compresses runway photos, stores them in the 'runway-looks' bucket
 * under {category_id}/{participant_id}/ and writes the matching row: `looks` (up
 * to 4 photos) for queens, `jury_looks` (one photo) for the jury.
 * RLS rejects the upload/insert for non-judges or closed categories.
 */
export function useLookUpload() {
  const supabase = useSupabaseClient()
  const bucketName = useRuntimeConfig().public.runwayLooksBucket
  const bucket = () => supabase.storage.from(bucketName)

  const uploading = ref(false)
  const error = ref<string | null>(null)

  /** Compresses and uploads a file, returning its storage path and public URL. */
  async function storeImage(categoryId: string, participantId: string, file: File) {
    const image = await compressImage(file)
    const extension = image.mimeType === 'image/webp' ? 'webp' : 'jpg'
    // Unique file name per upload, so replaced photos are never served stale from the CDN
    const path = `${categoryId}/${participantId}/${crypto.randomUUID()}.${extension}`

    const { error: uploadError } = await bucket().upload(path, image.blob, {
      contentType: image.mimeType,
      cacheControl: '31536000',
      upsert: false,
    })
    if (uploadError) throw uploadError

    const { data } = bucket().getPublicUrl(path)
    return { path, publicUrl: data.publicUrl }
  }

  /** Recovers the object path from a public URL (…/object/public/<bucket>/<path>). */
  function pathFromPublicUrl(publicUrl: string | null | undefined): string | null {
    if (!publicUrl) return null
    const marker = `/object/public/${bucketName}/`
    const index = publicUrl.indexOf(marker)
    return index === -1 ? null : decodeURIComponent(publicUrl.slice(index + marker.length))
  }

  /** Best effort: a leftover file is harmless, so never fail an operation over it. */
  async function removeUrls(urls: (string | null | undefined)[]): Promise<void> {
    const paths = urls.flatMap(url => pathFromPublicUrl(url) ?? [])
    if (paths.length) await bucket().remove(paths)
  }

  /** Runs an upload action, tracking loading/error state. Errors are re-thrown. */
  async function track<T>(action: () => Promise<T>): Promise<T> {
    uploading.value = true
    error.value = null
    try {
      return await action()
    }
    catch (err) {
      error.value = toErrorMessage(err)
      throw err
    }
    finally {
      uploading.value = false
    }
  }

  /**
   * Creates or updates a queen's look in one go: uploads the new photos, writes
   * the row, then deletes the files that were replaced or removed.
   */
  function saveLook({ look, categoryId, participantId, files, removed, intro }: SaveLookInput): Promise<Look> {
    return track(async () => {
      const stored: { slot: LookSlot, path: string, publicUrl: string }[] = []
      // Only optional slots can be set to null: the front photo is never removed
      const changes: { image_url?: string } & Partial<Record<Exclude<LookSlot, 'image_url'>, string | null>> = {}

      try {
        for (const { key } of LOOK_SLOTS) {
          const file = files[key]
          if (!file) continue
          const image = await storeImage(categoryId, participantId, file)
          stored.push({ slot: key, ...image })
          changes[key] = image.publicUrl
        }
        for (const slot of removed) {
          if (slot !== 'image_url' && !files[slot]) changes[slot] = null
        }

        const result = look
          ? await supabase.from('looks').update({ ...changes, intro }).eq('id', look.id).select(QUEEN_COLUMNS).single()
          : await supabase
              .from('looks')
              .insert({ category_id: categoryId, participant_id: participantId, ...changes, image_url: changes.image_url ?? '', intro })
              .select(QUEEN_COLUMNS)
              .single()
        if (result.error) throw result.error

        const replaced = look ? LOOK_SLOTS.flatMap(({ key }) => (key in changes ? look[key] ?? [] : [])) : []
        // The row is saved at this point, so a failed cleanup must not delete the new files
        await removeUrls(replaced).catch(() => undefined)
        return result.data
      }
      catch (err) {
        // Don't leave orphaned files behind if the row couldn't be written
        await bucket().remove(stored.map(item => item.path))
        throw err
      }
    })
  }

  /** Resets a queen's look: deletes the row (photos and intro) and then its files. */
  function deleteLook(look: Pick<Look, 'id'> & LookImages): Promise<void> {
    return track(async () => {
      const { error: deleteError } = await supabase.from('looks').delete().eq('id', look.id)
      if (deleteError) throw deleteError
      await removeUrls(lookImageUrls(look)).catch(() => undefined)
    })
  }

  /** Creates a jury look: one photo plus the (required) presentation text. */
  function uploadJuryLook({ categoryId, participantId, file, intro }: UploadJuryLookInput): Promise<JuryLook> {
    return track(async () => {
      const { path, publicUrl } = await storeImage(categoryId, participantId, file)

      const { data, error: insertError } = await supabase
        .from('jury_looks')
        .insert({ category_id: categoryId, participant_id: participantId, image_url: publicUrl, intro })
        .select(JURY_COLUMNS)
        .single()

      if (insertError) {
        await bucket().remove([path])
        throw insertError
      }
      return data
    })
  }

  /** Swaps the photo of an existing jury look and deletes the previous file. */
  function replaceJuryImage(look: Pick<JuryLook, 'id' | 'category_id' | 'participant_id' | 'image_url'>, file: File): Promise<JuryLook> {
    return track(async () => {
      const { path, publicUrl } = await storeImage(look.category_id, look.participant_id, file)

      const { data, error: updateError } = await supabase
        .from('jury_looks')
        .update({ image_url: publicUrl })
        .eq('id', look.id)
        .select(JURY_COLUMNS)
        .single()

      if (updateError) {
        await bucket().remove([path])
        throw updateError
      }

      await removeUrls([look.image_url])
      return data
    })
  }

  return { uploading: readonly(uploading), error: readonly(error), saveLook, deleteLook, uploadJuryLook, replaceJuryImage }
}
