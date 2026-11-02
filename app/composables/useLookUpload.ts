import type { Tables } from '~/types/database.types'

export type Look = Tables<'looks'>
export type JuryLook = Tables<'jury_looks'>

/** Queens' looks are voted on; the jury's looks are only shown on the homepage. */
export type LookKind = 'queen' | 'jury'

export interface UploadLookInput {
  categoryId: string
  participantId: string
  file: File
  intro?: string | null
}

const LOOK_COLUMNS = 'id, category_id, participant_id, image_url, intro, uploaded_by, created_at, updated_at'

/**
 * Judge-only: compresses a runway photo, stores it in the 'runway-looks' bucket
 * under {category_id}/{participant_id}/ and writes the matching row: `looks` for
 * queens, `jury_looks` for the jury.
 * RLS rejects the upload/insert for non-judges or closed categories.
 */
export function useLookUpload(kind: LookKind = 'queen') {
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
  function pathFromPublicUrl(publicUrl: string): string | null {
    const marker = `/object/public/${bucketName}/`
    const index = publicUrl.indexOf(marker)
    return index === -1 ? null : decodeURIComponent(publicUrl.slice(index + marker.length))
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

  // Both tables share the same columns; the jury's intro is just required
  function insertRow(categoryId: string, participantId: string, imageUrl: string, intro: string | null) {
    return kind === 'jury'
      ? supabase
          .from('jury_looks')
          .insert({ category_id: categoryId, participant_id: participantId, image_url: imageUrl, intro: intro ?? '' })
          .select(LOOK_COLUMNS)
          .single()
      : supabase
          .from('looks')
          .insert({ category_id: categoryId, participant_id: participantId, image_url: imageUrl, intro })
          .select(LOOK_COLUMNS)
          .single()
  }

  function updateImage(lookId: string, imageUrl: string) {
    return kind === 'jury'
      ? supabase.from('jury_looks').update({ image_url: imageUrl }).eq('id', lookId).select(LOOK_COLUMNS).single()
      : supabase.from('looks').update({ image_url: imageUrl }).eq('id', lookId).select(LOOK_COLUMNS).single()
  }

  /** Creates a new look for a participant in a category. */
  function uploadLook({ categoryId, participantId, file, intro = null }: UploadLookInput): Promise<Look> {
    return track(async () => {
      const { path, publicUrl } = await storeImage(categoryId, participantId, file)

      const { data, error: insertError } = await insertRow(categoryId, participantId, publicUrl, intro)

      if (insertError) {
        // Don't leave an orphaned file behind if the row couldn't be written
        await bucket().remove([path])
        throw insertError
      }
      return data
    })
  }

  /** Swaps the photo of an existing look and deletes the previous file. */
  function replaceLookImage(look: Pick<Look, 'id' | 'category_id' | 'participant_id' | 'image_url'>, file: File): Promise<Look> {
    return track(async () => {
      const { path, publicUrl } = await storeImage(look.category_id, look.participant_id, file)

      const { data, error: updateError } = await updateImage(look.id, publicUrl)

      if (updateError) {
        await bucket().remove([path])
        throw updateError
      }

      // Best effort: a leftover old file is harmless, so don't fail the replace over it
      const previousPath = pathFromPublicUrl(look.image_url)
      if (previousPath) {
        await bucket().remove([previousPath])
      }
      return data
    })
  }

  return { uploading: readonly(uploading), error: readonly(error), uploadLook, replaceLookImage }
}
