const ONBOARDING_PATH = '/onboarding'

/**
 * Sends signed-in users without a drag name to onboarding, remembering where
 * they were headed. Unauthenticated routing is handled by @nuxtjs/supabase.
 */
export default defineNuxtRouteMiddleware(async (to) => {
  const user = useSupabaseUser()
  if (!user.value) return

  const { login, callback } = useRuntimeConfig().public.supabase.redirectOptions
  if (to.path === login || to.path === callback) return

  const { load } = useCurrentParticipant()
  const participant = await load()
  if (!participant) return

  const isOnboarding = to.path === ONBOARDING_PATH

  if (!participant.drag_name && !isOnboarding) {
    return navigateTo({ path: ONBOARDING_PATH, query: { redirect: to.fullPath } })
  }
  if (participant.drag_name && isOnboarding) {
    return navigateTo('/')
  }
})
