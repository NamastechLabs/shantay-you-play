// A literal, so supabase-js can infer the row type (keep in sync with LOOK_SLOTS).
// Shared by `looks` and `jury_looks`, which have the same photo columns.
const QUEEN_LOOK_IMAGES = 'image_url, image2_url, image3_url, image4_url'

/**
 * Storage cleanup for rows removed through cascading foreign keys. Deleting a
 * participant (or a category) cascades to their looks, but the files in Storage are not touched by
 * Postgres, so the app lists the paths first and removes them after the delete.
 * (Deleting storage.objects rows from SQL would leave the underlying files behind.)
 */
export function useParticipantFiles() {
  const supabase = useSupabaseClient()
  const config = useRuntimeConfig().public

  /** Recovers the object path from a public URL (…/object/public/<bucket>/<path>). */
  function pathFromPublicUrl(bucketName: string, publicUrl: string | null): string | null {
    if (!publicUrl) return null
    const marker = `/object/public/${bucketName}/`
    const index = publicUrl.indexOf(marker)
    return index === -1 ? null : decodeURIComponent(publicUrl.slice(index + marker.length))
  }

  function toPaths(bucketName: string, urls: (string | null)[]): string[] {
    return urls.flatMap((url) => pathFromPublicUrl(bucketName, url) ?? [])
  }

  /** Lists every stored file owned by a participant. Call it BEFORE deleting the participant row. */
  async function listParticipantFiles(participantId: string) {
    const [looks, juryLooks, participant] = await Promise.all([
      supabase.from('looks').select(QUEEN_LOOK_IMAGES).eq('participant_id', participantId),
      supabase.from('jury_looks').select(QUEEN_LOOK_IMAGES).eq('participant_id', participantId),
      supabase.from('participants').select('avatar_url').eq('id', participantId).maybeSingle(),
    ])
    if (looks.error) throw looks.error
    if (juryLooks.error) throw juryLooks.error
    if (participant.error) throw participant.error

    return {
      looks: toPaths(config.runwayLooksBucket, [...looks.data, ...juryLooks.data].flatMap(lookImageUrls)),
      avatars: toPaths(config.avatarsBucket, [participant.data?.avatar_url ?? null]),
    }
  }

  /** Lists the photo files of the groups of a category. Call it BEFORE deleting the groups or the category. */
  async function listGroupPhotoFiles(categoryId: string) {
    const { data, error } = await supabase
      .from('category_group_photos')
      .select('image_url, image2_url, image3_url, image4_url')
      .eq('category_id', categoryId)
    if (error) throw error

    return { looks: toPaths(config.runwayLooksBucket, data.flatMap(row => groupPhotoUrls(row))), avatars: [] as string[] }
  }

  /** Lists every look and group photo file of a category. Call it BEFORE deleting the category row. */
  async function listCategoryFiles(categoryId: string) {
    const [looks, juryLooks, groupFiles] = await Promise.all([
      supabase.from('looks').select(QUEEN_LOOK_IMAGES).eq('category_id', categoryId),
      supabase.from('jury_looks').select(QUEEN_LOOK_IMAGES).eq('category_id', categoryId),
      listGroupPhotoFiles(categoryId),
    ])
    if (looks.error) throw looks.error
    if (juryLooks.error) throw juryLooks.error

    return {
      looks: [...toPaths(config.runwayLooksBucket, [...looks.data, ...juryLooks.data].flatMap(lookImageUrls)), ...groupFiles.looks],
      avatars: [],
    }
  }

  /** Best effort: leftover files are harmless, so failures are ignored. */
  async function removeFiles(files: { looks: string[], avatars: string[] }): Promise<void> {
    const jobs = [
      { bucket: config.runwayLooksBucket, paths: files.looks },
      { bucket: config.avatarsBucket, paths: files.avatars },
    ]
    await Promise.allSettled(
      jobs.filter((job) => job.paths.length).map((job) => supabase.storage.from(job.bucket).remove(job.paths)),
    )
  }

  return { listParticipantFiles, listCategoryFiles, listGroupPhotoFiles, removeFiles }
}
