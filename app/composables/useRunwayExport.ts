import { LOOK_SLOTS } from '~/utils/lookSlots'

interface LookRow {
  category_id: string
  intro: string | null
  image_url: string
  image2_url: string | null
  image3_url: string | null
  image4_url: string | null
  participant: { drag_name: string | null } | null
}

const MIME_EXTENSIONS: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
}

/** Lowercase ASCII without accents, words joined by "-" ("Ana Conda" → "ana-conda") */
function slugify(text: string): string {
  return text
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean)
    .join('-')
}

/**
 * Downloads a runway as a ZIP for the AI that writes the commentary: `runway.json` (same
 * content as `GET /api/commentary/runway`, with the path of each photo inside the ZIP) and
 * the photos, one folder per category (`jury/` for the jury's looks). It is built in the
 * browser with the judge's own session, so it needs no commentary token.
 */
export function useRunwayExport() {
  const supabase = useSupabaseClient()
  const exporting = ref(false)

  async function fetchPhoto(url: string): Promise<{ bytes: Uint8Array, extension: string }> {
    const response = await fetch(url)
    if (!response.ok) throw new Error('No se pudo descargar una de las fotos.')
    const blob = await response.blob()
    return { bytes: new Uint8Array(await blob.arrayBuffer()), extension: MIME_EXTENSIONS[blob.type] ?? 'jpg' }
  }

  async function download(runwayId: string): Promise<void> {
    exporting.value = true
    try {
      const { zipSync, strToU8 } = await import('fflate')

      const runwayResult = await supabase.from('runways').select('id, week_number, runway_date, status').eq('id', runwayId).single()
      if (runwayResult.error) throw runwayResult.error
      const runway = runwayResult.data

      const categoriesResult = await supabase
        .from('categories')
        .select('id, title, intro_text')
        .eq('runway_id', runwayId)
        .order('created_at', { ascending: true })
      if (categoriesResult.error) throw categoriesResult.error
      const categories = categoriesResult.data

      const categoryIds = categories.map(category => category.id)
      const columns = 'category_id, intro, image_url, image2_url, image3_url, image4_url, participant:participants!{fk}(drag_name)'
      const [looks, juryLooks] = await Promise.all([
        supabase.from('looks').select(columns.replace('{fk}', 'looks_participant_id_fkey')).in('category_id', categoryIds).order('created_at', { ascending: true }),
        supabase.from('jury_looks').select(columns.replace('{fk}', 'jury_looks_participant_id_fkey')).in('category_id', categoryIds).order('created_at', { ascending: true }),
      ])
      if (looks.error) throw looks.error
      if (juryLooks.error) throw juryLooks.error
      const looksRows = looks.data as unknown as LookRow[]
      const juryRows = juryLooks.data as unknown as LookRow[]

      const files: Record<string, Uint8Array> = {}

      async function toLook(row: LookRow, folder: string) {
        const queen = row.participant?.drag_name ?? null
        const photos = await Promise.all(LOOK_SLOTS.flatMap((slot) => {
          const url = row[slot.key]
          return url ? [{ label: slot.label, url }] : []
        }).map(async (photo) => {
          const { bytes, extension } = await fetchPhoto(photo.url)
          // Same queen + same label can only happen in jury looks, hence the numeric suffix on collisions
          const base = `${folder}/${slugify(queen ?? 'sin-nombre')}-${slugify(photo.label)}`
          let file = `${base}.${extension}`
          for (let n = 2; files[file]; n++) file = `${base}-${n}.${extension}`
          files[file] = bytes
          return { label: photo.label, file }
        }))
        return { queen, intro: row.intro, photos }
      }

      const payload = {
        runway: { week_number: runway.week_number, date: runway.runway_date, status: runway.status },
        categories: await Promise.all(categories.map(async (category) => {
          const folder = slugify(category.title) || 'categoria'
          return {
            title: category.title,
            intro: category.intro_text,
            looks: await Promise.all(looksRows.filter(look => look.category_id === category.id).map(look => toLook(look, folder))),
            jury_looks: await Promise.all(juryRows.filter(look => look.category_id === category.id).map(look => toLook(look, `${folder}/jury`))),
          }
        })),
      }

      files['runway.json'] = strToU8(JSON.stringify(payload, null, 2))
      // Photos are already compressed (webp / jpeg), so store them without deflating
      const zip = zipSync(files, { level: 0 })

      const link = document.createElement('a')
      const href = URL.createObjectURL(new Blob([zip as BlobPart], { type: 'application/zip' }))
      link.href = href
      link.download = `pasarela-semana-${runway.week_number}.zip`
      link.click()
      URL.revokeObjectURL(href)
    }
    finally {
      exporting.value = false
    }
  }

  return { exporting, download }
}
