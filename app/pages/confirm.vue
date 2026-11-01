<script setup lang="ts">
// OAuth callback: the Supabase client exchanges the ?code for a session,
// then we send the user back to the page they originally requested.
const user = useSupabaseUser()
const redirectInfo = useSupabaseCookieRedirect()

watch(
  user,
  () => {
    if (user.value) {
      const path = redirectInfo.pluck()
      navigateTo(path || '/', { replace: true })
    }
  },
  { immediate: true },
)
</script>

<template>
  <main class="confirm">
    <p>Confirmando sesión…</p>
  </main>
</template>

<style scoped>
.confirm {
  display: grid;
  place-items: center;
  min-height: 100dvh;
}
</style>
