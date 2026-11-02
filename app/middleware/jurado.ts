/**
 * Named middleware for judge-only pages: `definePageMeta({ middleware: 'jurado' })`.
 * This only hides the UI; the real protection is RLS in the database.
 */
export default defineNuxtRouteMiddleware(async () => {
  const { load } = useCurrentParticipant()
  const participant = await load()

  if (participant?.role !== 'jurado') {
    return navigateTo('/')
  }
})
