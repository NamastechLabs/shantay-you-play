/**
 * Stores a participant's profile picture in the 'participant-avatars' bucket under
 * {participant_id}/. RLS only lets people write inside their own folder.
 */
export function useAvatarUpload() {
  const supabase = useSupabaseClient()
  const bucketName = useRuntimeConfig().public.avatarsBucket
  const bucket = () => supabase.storage.from(bucketName)

  /** Compresses and uploads a picture, returning its storage path and public URL. */
  async function uploadAvatar(participantId: string, file: File): Promise<{ path: string, publicUrl: string }> {
    const image = await compressImage(file, { maxDimension: 512 })
    const extension = image.mimeType === 'image/webp' ? 'webp' : 'jpg'
    // Unique file name per upload, so replaced pictures are never served stale from the CDN
    const path = `${participantId}/${crypto.randomUUID()}.${extension}`

    const { error } = await bucket().upload(path, image.blob, {
      contentType: image.mimeType,
      cacheControl: '31536000',
      upsert: false,
    })
    if (error) throw error

    return { path, publicUrl: bucket().getPublicUrl(path).data.publicUrl }
  }

  /** Recovers the object path from a public URL (…/object/public/<bucket>/<path>). */
  function pathFromPublicUrl(publicUrl: string): string | null {
    const marker = `/object/public/${bucketName}/`
    const index = publicUrl.indexOf(marker)
    return index === -1 ? null : decodeURIComponent(publicUrl.slice(index + marker.length))
  }

  /** Best effort: a leftover file is harmless, so failures are ignored. */
  async function removeByUrl(publicUrl: string | null): Promise<void> {
    const path = publicUrl ? pathFromPublicUrl(publicUrl) : null
    if (path) await bucket().remove([path])
  }

  return { uploadAvatar, removeByUrl }
}
