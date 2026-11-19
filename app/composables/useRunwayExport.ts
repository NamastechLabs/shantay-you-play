import { LOOK_SLOTS } from '~/utils/lookSlots'

interface LookRow {
  category_id: string
  participant_id: string
  intro: string | null
  image_url: string
  image2_url: string | null
  image3_url: string | null
  image4_url: string | null
  participant: { drag_name: string | null } | null
}

interface GroupRow {
  id: string
  category_id: string
  name: string
  intro: string | null
}

interface GroupPhotosRow {
  group_id: string
  image_url: string | null
  image2_url: string | null
  image3_url: string | null
  image4_url: string | null
}

interface MemberRow {
  group_id: string
  participant_id: string
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
        .select('id, title, intro_text, kind')
        .eq('runway_id', runwayId)
        .order('created_at', { ascending: true })
      if (categoriesResult.error) throw categoriesResult.error
      const categories = categoriesResult.data

      const categoryIds = categories.map(category => category.id)
      const columns = 'category_id, participant_id, intro, image_url, image2_url, image3_url, image4_url, participant:participants!{fk}(drag_name)'
      const [looks, juryLooks] = await Promise.all([
        supabase.from('looks').select(columns.replace('{fk}', 'looks_participant_id_fkey')).in('category_id', categoryIds).order('created_at', { ascending: true }),
        supabase.from('jury_looks').select(columns.replace('{fk}', 'jury_looks_participant_id_fkey')).in('category_id', categoryIds).order('created_at', { ascending: true }),
      ])
      if (looks.error) throw looks.error
      if (juryLooks.error) throw juryLooks.error
      const looksRows = looks.data as unknown as LookRow[]
      const juryRows = juryLooks.data as unknown as LookRow[]

      // Groups ("bands") of the group categories: name, intro, photos and members
      const groupCategoryIds = categories.filter(category => category.kind === 'group').map(category => category.id)
      const [groups, groupPhotos, members] = groupCategoryIds.length
        ? await Promise.all([
            supabase.from('category_groups').select('id, category_id, name, intro').in('category_id', groupCategoryIds).order('position', { ascending: true }),
            supabase.from('category_group_photos').select('group_id, image_url, image2_url, image3_url, image4_url').in('category_id', groupCategoryIds),
            supabase.from('category_group_members').select('group_id, participant_id, participant:participants!category_group_members_participant_id_fkey(drag_name)').in('category_id', groupCategoryIds).order('created_at', { ascending: true }),
          ])
        : [null, null, null]
      for (const result of [groups, groupPhotos, members]) {
        if (result?.error) throw result.error
      }
      const groupRows = (groups?.data ?? []) as GroupRow[]
      const photoRows = (groupPhotos?.data ?? []) as GroupPhotosRow[]
      const memberRows = (members?.data ?? []) as unknown as MemberRow[]
      const groupOfQueen = new Map(memberRows.map(member => [member.participant_id, member.group_id]))
      const groupNames = new Map(groupRows.map(group => [group.id, group.name]))

      // Sub-categories of the individual categories and the one each queen picked
      const [subcategories, picks] = await Promise.all([
        supabase.from('category_subcategories').select('id, category_id, name').in('category_id', categoryIds).order('position', { ascending: true }).order('created_at', { ascending: true }),
        supabase.from('category_subcategory_picks').select('category_id, participant_id, subcategory_id').in('category_id', categoryIds),
      ])
      if (subcategories.error) throw subcategories.error
      if (picks.error) throw picks.error
      const subcategoryNames = new Map(subcategories.data.map(subcategory => [subcategory.id, subcategory.name]))
      const subcategoryOf = new Map(picks.data.map(pick => [`${pick.category_id}:${pick.participant_id}`, subcategoryNames.get(pick.subcategory_id) ?? null]))

      const files: Record<string, Uint8Array> = {}

      /** Downloads a photo into the ZIP and returns its path; `base` has no extension */
      async function addPhoto(url: string, base: string): Promise<string> {
        const { bytes, extension } = await fetchPhoto(url)
        let file = `${base}.${extension}`
        for (let n = 2; files[file]; n++) file = `${base}-${n}.${extension}`
        files[file] = bytes
        return file
      }

      async function toLook(row: LookRow, folder: string, isJury = false) {
        const queen = row.participant?.drag_name ?? null
        const photos = await Promise.all(LOOK_SLOTS.flatMap((slot) => {
          const url = row[slot.key]
          return url ? [{ label: slot.label, url }] : []
        }).map(async (photo) => {
          // Same queen + same label can only happen in jury looks, hence the numeric suffix on collisions
          const file = await addPhoto(photo.url, `${folder}/${slugify(queen ?? 'sin-nombre')}-${slugify(photo.label)}`)
          return { label: photo.label, file }
        }))
        return {
          queen,
          group: groupNames.get(groupOfQueen.get(row.participant_id) ?? '') ?? null,
          // Only queens pick a sub-category (null for jury looks and when none was picked)
          subcategory: isJury ? null : subcategoryOf.get(`${row.category_id}:${row.participant_id}`) ?? null,
          intro: row.intro,
          photos,
        }
      }

      const payload = {
        runway: { week_number: runway.week_number, date: runway.runway_date, status: runway.status },
        categories: await Promise.all(categories.map(async (category) => {
          const folder = slugify(category.title) || 'categoria'
          return {
            title: category.title,
            type: category.kind,
            intro: category.intro_text,
            subcategories: subcategories.data.filter(subcategory => subcategory.category_id === category.id).map(subcategory => subcategory.name),
            groups: await Promise.all(groupRows.filter(group => group.category_id === category.id).map(async (group) => {
              const row = photoRows.find(photo => photo.group_id === group.id)
              const urls = row ? [row.image_url, row.image2_url, row.image3_url, row.image4_url] : []
              const photos = await Promise.all(urls.flatMap((url, index) => (url ? [{ url, index }] : [])).map(async ({ url, index }) => ({
                label: `Foto ${index + 1}`,
                file: await addPhoto(url, `${folder}/grupos/${slugify(group.name)}-foto-${index + 1}`),
              })))
              return {
                name: group.name,
                intro: group.intro,
                photos,
                members: memberRows.filter(member => member.group_id === group.id).map(member => member.participant?.drag_name ?? null),
              }
            })),
            looks: await Promise.all(looksRows.filter(look => look.category_id === category.id).map(look => toLook(look, folder))),
            jury_looks: await Promise.all(juryRows.filter(look => look.category_id === category.id).map(look => toLook(look, `${folder}/jury`, true))),
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
