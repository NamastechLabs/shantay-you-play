<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()

const loading = ref(false)
const errorMessage = ref<string | null>(null)

// Already signed in: skip the login screen
watchEffect(() => {
  if (user.value) navigateTo('/')
})

async function signInWithGoogle(): Promise<void> {
  loading.value = true
  errorMessage.value = null

  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      // Must be listed under Auth > URL Configuration > Redirect URLs in Supabase
      redirectTo: `${useRequestURL().origin}/confirm`,
    },
  })

  // On success the browser navigates to Google, so only errors land here
  if (error) {
    errorMessage.value = error.message
    loading.value = false
  }
}
</script>

<template>
  <main class="login">
    <h1>Drag Race</h1>
    <p>Inicia sesión para entrar a la competencia.</p>

    <button type="button" :disabled="loading" @click="signInWithGoogle">
      {{ loading ? 'Redirigiendo…' : 'Entrar con Google' }}
    </button>

    <p v-if="errorMessage" class="error" role="alert">
      {{ errorMessage }}
    </p>
  </main>
</template>

<style scoped>
.login {
  display: grid;
  place-items: center;
  align-content: center;
  gap: 1rem;
  min-height: 100dvh;
  padding: 0 1rem;
  text-align: center;
}

button {
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
  border-radius: 999px;
  cursor: pointer;
}

button:disabled {
  cursor: progress;
  opacity: 0.6;
}

.error {
  color: #d33;
}
</style>
