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
  <main class="auth-split">
    <div class="auth-split__media">
      <!-- Placeholder photo: replace with your own artwork -->
      <img src="/images/login-hero.jpg" alt="" width="1030" height="1544">
    </div>

    <div class="auth-split__panel">
      <p class="kicker">
        Bienvenida a la competencia
      </p>
      <h1 class="display">
        Drag Race Game
      </h1>
      <span class="rule" />
      <p class="lead">
        Inicia sesión para entrar a la competencia.
      </p>

      <button type="button" class="btn btn--primary" :disabled="loading" @click="signInWithGoogle">
        {{ loading ? 'Redirigiendo…' : 'Entrar con Google' }}
      </button>

      <p v-if="errorMessage" class="form-error" role="alert">
        {{ errorMessage }}
      </p>
    </div>
  </main>
</template>
