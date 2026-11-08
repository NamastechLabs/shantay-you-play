import { serverSupabaseServiceRole } from '#supabase/server'

/** Photo slots of a look, in order (mirrors app/utils/lookSlots.ts). */
const SLOTS = [
  { column: 'image_url', label: 'Frente' },
  { column: 'image2_url', label: 'Espalda' },
  { column: 'image3_url', label: 'Reveal' },
  { column: 'image4_url', label: 'Extra' },
] as const

type LookRow = {
  category_id: string
  intro: string | null
  image_url: string
  image2_url: string | null
  image3_url: string | null
  image4_url: string | null
  participant: { name: string, drag_name: string | null } | null
}

function toLook(row: LookRow) {
  return {
    queen: row.participant?.drag_name ?? row.participant?.name ?? null,
    real_name: row.participant?.name ?? null,
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
    : runwayQuery.eq('status', 'runway').order('week_number', { ascending: false }))
    .limit(1)
  if (runwayError) throw createError({ statusCode: 500, statusMessage: runwayError.message })

  const runway = runways?.[0]
  if (!runway) {
    throw createError({
      statusCode: 404,
      statusMessage: byWeek ? `No runway for week ${week}` : 'No runway is in the "runway" (Pasarela) stage',
    })
  }

  const { data: categories, error: categoriesError } = await db
    .from('categories')
    .select('id, title, intro_text')
    .eq('runway_id', runway.id)
    .order('created_at', { ascending: true })
  if (categoriesError) throw createError({ statusCode: 500, statusMessage: categoriesError.message })

  const categoryIds = (categories ?? []).map(category => category.id)
  const columns = 'category_id, intro, image_url, image2_url, image3_url, image4_url, participant:participants!{fk}(name, drag_name)'
  const [looks, juryLooks] = await Promise.all([
    db.from('looks').select(columns.replace('{fk}', 'looks_participant_id_fkey')).in('category_id', categoryIds).order('created_at', { ascending: true }),
    db.from('jury_looks').select(columns.replace('{fk}', 'jury_looks_participant_id_fkey')).in('category_id', categoryIds).order('created_at', { ascending: true }),
  ])
  if (looks.error) throw createError({ statusCode: 500, statusMessage: looks.error.message })
  if (juryLooks.error) throw createError({ statusCode: 500, statusMessage: juryLooks.error.message })

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
      intro: category.intro_text,
      looks: looksRows.filter(look => look.category_id === category.id).map(toLook),
      jury_looks: juryRows.filter(look => look.category_id === category.id).map(toLook),
    })),
  }
})
