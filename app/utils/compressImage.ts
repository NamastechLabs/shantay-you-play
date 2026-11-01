export interface CompressImageOptions {
  /** Longest side of the output image in px. Smaller images are never upscaled. */
  maxDimension?: number
  /** Encoder quality between 0 and 1 */
  quality?: number
  /** Preferred output format; falls back to JPEG if the browser can't encode it */
  mimeType?: 'image/webp' | 'image/jpeg'
}

export interface CompressedImage {
  blob: Blob
  mimeType: 'image/webp' | 'image/jpeg'
  width: number
  height: number
}

const DEFAULT_OPTIONS: Required<CompressImageOptions> = {
  maxDimension: 1600,
  quality: 0.82,
  mimeType: 'image/webp',
}

function canvasToBlob(canvas: HTMLCanvasElement, mimeType: string, quality: number): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error('No se pudo codificar la imagen'))),
      mimeType,
      quality,
    )
  })
}

/**
 * Resizes and re-encodes an image in the browser before upload.
 * Phone photos (often 4-12 MB) typically end up around 150-400 KB.
 * Client-only: relies on createImageBitmap and <canvas>.
 */
export async function compressImage(file: File, options: CompressImageOptions = {}): Promise<CompressedImage> {
  const { maxDimension, quality, mimeType } = { ...DEFAULT_OPTIONS, ...options }

  if (!file.type.startsWith('image/')) {
    throw new Error('El archivo seleccionado no es una imagen')
  }

  let bitmap: ImageBitmap
  try {
    // 'from-image' applies the EXIF orientation so phone photos aren't sideways
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' })
  }
  catch {
    // e.g. HEIC outside Safari
    throw new Error('Formato de imagen no soportado por este navegador. Prueba con JPG o PNG.')
  }

  try {
    const scale = Math.min(1, maxDimension / Math.max(bitmap.width, bitmap.height))
    const width = Math.round(bitmap.width * scale)
    const height = Math.round(bitmap.height * scale)

    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height

    const context = canvas.getContext('2d')
    if (!context) {
      throw new Error('Canvas 2D no disponible')
    }
    context.imageSmoothingEnabled = true
    context.imageSmoothingQuality = 'high'
    context.drawImage(bitmap, 0, 0, width, height)

    let blob = await canvasToBlob(canvas, mimeType, quality)
    let outputType: CompressedImage['mimeType'] = mimeType

    // Browsers that can't encode the requested type silently return PNG instead
    if (blob.type !== mimeType) {
      blob = await canvasToBlob(canvas, 'image/jpeg', quality)
      outputType = 'image/jpeg'
    }

    return { blob, mimeType: outputType, width, height }
  }
  finally {
    bitmap.close()
  }
}
