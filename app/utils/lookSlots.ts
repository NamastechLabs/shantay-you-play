/** A queen's look has up to 4 photos, one column each; the first (front) is required. */
export const LOOK_SLOTS = [
  { key: 'image_url', label: 'Frente' },
  { key: 'image2_url', label: 'Espalda' },
  { key: 'image3_url', label: 'Reveal' },
  { key: 'image4_url', label: 'Extra' },
] as const

export type LookSlot = typeof LOOK_SLOTS[number]['key']

export type LookImages = { image_url: string } & Partial<Record<Exclude<LookSlot, 'image_url'>, string | null>>

/** Photos of a look in slot order with their slot label (Frente, Espalda…), skipping the empty slots. */
export function lookPhotos(look: LookImages): { url: string, label: string }[] {
  return LOOK_SLOTS.flatMap(slot => (look[slot.key] ? [{ url: look[slot.key] as string, label: slot.label }] : []))
}

/** Photo URLs of a look in slot order, skipping the empty slots. */
export function lookImageUrls(look: LookImages): string[] {
  return LOOK_SLOTS.flatMap(slot => look[slot.key] ?? [])
}
