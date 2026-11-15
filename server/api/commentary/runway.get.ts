import { serverSupabaseServiceRole } from '#supabase/server'

/** Photo slots of a look, in order (mirrors app/utils/lookSlots.ts). */
const SLOTS = [
  { column: 'image_url', label: 'Foto 1' },
  { column: 'image2_url', label: 'Foto 2' },
  { column: 'image3_url', label: 'Foto 3' },
  { column: 'image4_url', label: 'Foto 4' },
] as const

type LookRow = {
  category_id: string
  participant_id: string
  intro: string | null
  image_url: string
  image2_url: string | null
  image3_url: string | null
  image4_url: string | null
  participant: { drag_name: string | null } | null
}

type GroupRow = {
  id: string
  category_id: string
  position: number
  name: string
  intro: string | null
}

type GroupPhotosRow = { group_id: string } & Record<typeof SLOTS[number]['column'], string | null>

type MemberRow = {
  group_id: string
  participant_id: string
  participant: { drag_name: string | null } | null
}

function toLook(row: LookRow, groupName: string | null = null) {
  return {
    queen: row.participant?.drag_name ?? null,
    group: groupName,
    intro: row.intro,
    photos: SLOTS.flatMap(({ column, label }) => (row[column] ? [{ label, url: row[column] as string }] : [])),
  }
}

/**
 * Runway content for the AI that writes the commentary: the runway in the 'runway'
 * stage (Pasarela) with its categories, every queen's look (intro + photo URLs) and the
 * jury's looks. `?week=N` picks another week instead. Requires the commentary token.
 */
export default defineEventHandler(async (event) => {
  assertCommentaryToken(event)

  const db = serverSupabaseServiceRole(event)
  const week = Number(getQuery(event).week)
  const byWeek = Number.isInteger(week) && week > 0

  const runwayQuery = db.from('runways').select('id, week_number, runway_date, status')
  const { data: runways, error: runwayError } = await (byWeek
    ? runwayQuery.eq('week_number', week)
    // TEMPORARY: the stage check is off, so this returns the latest week whatever its status.
    // Restore `.eq('status', 'runway')` before the `.order(...)` to only serve the Pasarela stage.
    : runwayQuery.order('week_number', { ascending: false }))
    .limit(1)
  if (runwayError) throw createError({ statusCode: 500, statusMessage: runwayError.message })

  const runway = runways?.[0]
  if (!runway) {
    throw createError({
      statusCode: 404,
      statusMessage: byWeek ? `No runway for week ${week}` : 'No runways found',
    })
  }

  const { data: categories, error: categoriesError } = await db
    .from('categories')
    .select('id, title, intro_text, kind')
    .eq('runway_id', runway.id)
    .order('created_at', { ascending: true })
  if (categoriesError) throw createError({ statusCode: 500, statusMessage: categoriesError.message })

  const categoryIds = (categories ?? []).map(category => category.id)
  const columns = 'category_id, participant_id, intro, image_url, image2_url, image3_url, image4_url, participant:participants!{fk}(drag_name)'
  const [looks, juryLooks] = await Promise.all([
    db.from('looks').select(columns.replace('{fk}', 'looks_participant_id_fkey')).in('category_id', categoryIds).order('created_at', { ascending: true }),
    db.from('jury_looks').select(columns.replace('{fk}', 'jury_looks_participant_id_fkey')).in('category_id', categoryIds).order('created_at', { ascending: true }),
  ])
  if (looks.error) throw createError({ statusCode: 500, statusMessage: looks.error.message })
  if (juryLooks.error) throw createError({ statusCode: 500, statusMessage: juryLooks.error.message })

  // Groups ("bands") of the group categories: name, intro, photos and members
  const groupCategoryIds = (categories ?? []).filter(category => category.kind === 'group').map(category => category.id)
  const [groups, groupPhotos, members] = groupCategoryIds.length
    ? await Promise.all([
        db.from('category_groups').select('id, category_id, position, name, intro').in('category_id', groupCategoryIds).order('position', { ascending: true }),
        db.from('category_group_photos').select('group_id, image_url, image2_url, image3_url, image4_url').in('category_id', groupCategoryIds),
        db.from('category_group_members').select('group_id, participant_id, participant:participants!category_group_members_participant_id_fkey(drag_name)').in('category_id', groupCategoryIds).order('created_at', { ascending: true }),
      ])
    : [null, null, null]
  for (const result of [groups, groupPhotos, members]) {
    if (result?.error) throw createError({ statusCode: 500, statusMessage: result.error.message })
  }
  const groupRows = (groups?.data ?? []) as GroupRow[]
  const photoRows = (groupPhotos?.data ?? []) as GroupPhotosRow[]
  const memberRows = (members?.data ?? []) as unknown as MemberRow[]
  const groupOfQueen = new Map(memberRows.map(member => [member.participant_id, member.group_id]))
  const groupNames = new Map(groupRows.map(group => [group.id, group.name]))
  const groupNameOf = (look: LookRow) => groupNames.get(groupOfQueen.get(look.participant_id) ?? '') ?? null

  const looksRows = (looks.data ?? []) as unknown as LookRow[]
  const juryRows = (juryLooks.data ?? []) as unknown as LookRow[]

  return {
    runway: {
      week_number: runway.week_number,
      date: runway.runway_date,
      status: runway.status,
    },
    categories: (categories ?? []).map(category => ({
      title: category.title,
      type: category.kind,
      intro: category.intro_text,
      groups: groupRows.filter(group => group.category_id === category.id).map(group => ({
        name: group.name,
        intro: group.intro,
        photos: SLOTS.flatMap(({ column }, index) => {
          const url = photoRows.find(photo => photo.group_id === group.id)?.[column]
          return url ? [{ label: `Foto ${index + 1}`, url }] : []
        }),
        members: memberRows.filter(member => member.group_id === group.id).map(member => member.participant?.drag_name ?? null),
      })),
      looks: looksRows.filter(look => look.category_id === category.id).map(look => toLook(look, groupNameOf(look))),
      jury_looks: juryRows.filter(look => look.category_id === category.id).map(look => toLook(look)),
    })),
  }
})
