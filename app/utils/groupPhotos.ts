import type { Tables } from '~/types/database.types'

/** A group has up to 4 landscape photos, shown together as one picture */
export const GROUP_PHOTO_SLOTS = [
  { key: 'image_url', label: 'Foto 1' },
  { key: 'image2_url', label: 'Foto 2' },
  { key: 'image3_url', label: 'Foto 3' },
  { key: 'image4_url', label: 'Foto 4' },
] as const

export type GroupPhotoSlot = typeof GROUP_PHOTO_SLOTS[number]['key']

export type GroupPhotos = Pick<Tables<'category_group_photos'>, 'group_id' | 'category_id' | GroupPhotoSlot>

/** Landscape ratios accepted for group photos */
const ALLOWED_RATIOS = [16 / 9, 5 / 3]
/** Relative tolerance, so photos cropped by a few pixels still pass */
const RATIO_TOLERANCE = 0.03

/** Saved photo URLs of a group in slot order, skipping the empty slots. */
export function groupPhotoUrls(photos: Partial<Record<GroupPhotoSlot, string | null>> | null | undefined): string[] {
  return GROUP_PHOTO_SLOTS.flatMap(slot => photos?.[slot.key] ?? [])
}

/** True when width / height is (about) 16:9 or 5:3. */
export function isAllowedGroupRatio(width: number, height: number): boolean {
  if (!width || !height) return false
  const ratio = width / height
  return ALLOWED_RATIOS.some(allowed => Math.abs(ratio - allowed) / allowed <= RATIO_TOLERANCE)
}

/**
 * Client-only: throws a Spanish error message unless the image is landscape 16:9 or 5:3.
 * The EXIF orientation is applied first, so phone photos are measured as displayed.
 */
export async function assertGroupPhotoRatio(file: File): Promise<void> {
  if (!file.type.startsWith('image/')) throw new Error('El archivo seleccionado no es una imagen')

  let bitmap: ImageBitmap
  try {
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' })
  }
  catch {
    throw new Error('Formato de imagen no soportado por este navegador. Prueba con JPG o PNG.')
  }

  try {
    if (!isAllowedGroupRatio(bitmap.width, bitmap.height)) {
      throw new Error('La foto debe ser apaisada, en formato 16:9 o 5:3.')
    }
  }
  finally {
    bitmap.close()
  }
}
