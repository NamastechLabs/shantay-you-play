<script setup lang="ts">
// OAuth callback: the Supabase client exchanges the ?code for a session,
// then we send the user back to the page they originally requested.
// If Supabase rejected the sign-up (email not in the participant list) the provider
// redirects here with error params (in the query or the hash): go back to /login.
const user = useSupabaseUser()
const route = useRoute()
const redirectInfo = useSupabaseCookieRedirect()

const hashParams = import.meta.client ? new URLSearchParams(window.location.hash.slice(1)) : null
const hasAuthError = Boolean(route.query.error || route.query.error_code || hashParams?.get('error'))

if (hasAuthError) {
  await navigateTo({ path: '/login', query: { error: 'not_registered' } }, { replace: true })
}

let done = false
function finish() {
  if (done) return
  done = true
  const path = redirectInfo.pluck()
  navigateTo(path || '/', { replace: true })
}

watch(
  user,
  () => {
    if (user.value) finish()
  },
  { immediate: true },
)

// Mobile Safari (iOS) can finish the code exchange without useSupabaseUser ever updating,
// so also listen to the client directly, and give up with a message instead of hanging.
if (import.meta.client) {
  const supabase = useSupabaseClient()
  const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
    if (session) finish()
  })

  onMounted(async () => {
    const { data } = await supabase.auth.getSession()
    if (data.session) finish()

    setTimeout(() => {
      if (!done) navigateTo({ path: '/login', query: { error: 'session' } }, { replace: true })
    }, 10000)
  })

  onBeforeUnmount(() => listener.subscription.unsubscribe())
}
</script>

<template>
  <main class="auth-center">
    <p class="lead" role="status">
      Confirmando sesión…
    </p>
  </main>
</template>
