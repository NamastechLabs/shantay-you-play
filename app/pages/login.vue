<script setup lang="ts">
const user = useSupabaseUser()
const { loadingProvider, errorMessage, signInWithGoogle, signInWithMicrosoft } = useAuth()

const busy = computed(() => loadingProvider.value !== null)

// Already signed in: skip the login screen
watchEffect(() => {
  if (user.value) navigateTo('/')
})
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

      <div class="auth-split__providers">
        <button type="button" class="btn btn--primary" :disabled="busy" @click="signInWithGoogle">
          {{ loadingProvider === 'google' ? 'Redirigiendo…' : 'Entrar con Google' }}
        </button>
        <button type="button" class="btn btn--secondary" :disabled="busy" @click="signInWithMicrosoft">
          {{ loadingProvider === 'azure' ? 'Redirigiendo…' : 'Entrar con Microsoft (Hotmail, Outlook)' }}
        </button>
      </div>

      <p v-if="errorMessage" class="form-error" role="alert">
        {{ errorMessage }}
      </p>
    </div>
  </main>
</template>
