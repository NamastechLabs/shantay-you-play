import { serverSupabaseServiceRole } from '#supabase/server'

/**
 * Dev only: issues a one-time magic-link token for a participant's email so the
 * browser can sign in as them (`supabase.auth.verifyOtp`). The session is a real
 * one, so RLS and storage policies behave exactly as for that participant.
 * Only participants who already signed in once have a login to impersonate.
 */
export default defineEventHandler(async (event) => {
  assertDevOnly(event)

  const { participantId } = await readBody<{ participantId?: string }>(event)
  if (!participantId) throw createError({ statusCode: 400, statusMessage: 'participantId is required' })

  const admin = serverSupabaseServiceRole(event)
  const participant = await admin.from('participants').select('email, user_id').eq('id', participantId).maybeSingle()
  if (participant.error) throw createError({ statusCode: 500, statusMessage: participant.error.message })
  if (!participant.data) throw createError({ statusCode: 404, statusMessage: 'Participant not found' })
  if (!participant.data.user_id) {
    throw createError({ statusCode: 409, statusMessage: 'Esta participante aún no ha iniciado sesión, no hay cuenta que suplantar' })
  }

  const { data, error } = await admin.auth.admin.generateLink({ type: 'magiclink', email: participant.data.email })
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })

  return { tokenHash: data.properties.hashed_token }
})
