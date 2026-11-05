export interface SharePayload {
  /** Photos to attach, in order */
  imageUrls: string[]
  /** Message that goes with the photos */
  text: string
}

export type ShareResult = 'shared' | 'copied' | 'cancelled'

const MIME_EXTENSIONS: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
}

async function downloadFile(url: string, index: number): Promise<File> {
  const response = await fetch(url)
  if (!response.ok) throw new Error('No se pudo descargar una de las fotos del look.')
  const blob = await response.blob()
  const extension = MIME_EXTENSIONS[blob.type] ?? 'jpg'
  return new File([blob], `look-${index + 1}.${extension}`, { type: blob.type || 'image/jpeg' })
}

/**
 * Shares a look through the native share sheet (Android / iOS) so it can be sent
 * straight to a WhatsApp chat. Where files cannot be shared (desktop browsers) the
 * text is copied to the clipboard instead.
 *
 * Images are downloaded ahead of time with `prefetch`: browsers only allow
 * `navigator.share` shortly after a tap, so there is no time to fetch on click.
 */
export function useShareLooks() {
  const sharing = ref(false)
  const cache = new Map<string, Promise<File>>()

  function fileFor(url: string, index: number): Promise<File> {
    let file = cache.get(url)
    if (!file) {
      file = downloadFile(url, index)
      // A failed download must be retried on the next attempt
      file.catch(() => cache.delete(url))
      cache.set(url, file)
    }
    return file
  }

  function prefetch(imageUrls: string[]) {
    imageUrls.forEach((url, index) => fileFor(url, index).catch(() => {}))
  }

  async function share({ imageUrls, text }: SharePayload): Promise<ShareResult> {
    sharing.value = true

    try {
      const files = await Promise.all(imageUrls.map(fileFor))

      if (navigator.canShare?.({ files })) {
        await navigator.share({ files, text })
        return 'shared'
      }

      await navigator.clipboard.writeText(text)
      return 'copied'
    }
    catch (error) {
      // Closing the share sheet is not an error
      if (error instanceof DOMException && error.name === 'AbortError') return 'cancelled'
      throw error
    }
    finally {
      sharing.value = false
    }
  }

  return { sharing, prefetch, share }
}
