import { serverSupabaseServiceRole } from '#supabase/server'

/** Dev only: every participant, for the "impersonate" picker. */
export default defineEventHandler(async (event) => {
  assertDevOnly(event)

  const { data, error } = await serverSupabaseServiceRole(event)
    .from('participants')
    .select('id, name, drag_name, email, role, user_id')
    .order('name', { ascending: true })
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })

  return data
})
