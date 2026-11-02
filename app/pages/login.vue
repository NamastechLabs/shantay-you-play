<script setup lang="ts">
const user = useSupabaseUser()
const { loadingProvider, errorMessage, signInWithGoogle, signInWithMicrosoft } = useAuth()

const route = useRoute()

const busy = computed(() => loadingProvider.value !== null)

const NOT_REGISTERED_MESSAGE
  = 'Tu correo no está en la lista de participantes. Inicia sesión con el correo con el que te registraron o pídele a un jurado que te añada.'
const SESSION_FAILED_MESSAGE
  = 'No pudimos confirmar tu sesión. Inténtalo de nuevo; si usas el navegador de otra app (Instagram, WhatsApp…), abre el enlace en Safari.'
const displayedError = computed(() =>
  errorMessage.value
  ?? (route.query.error === 'not_registered'
    ? NOT_REGISTERED_MESSAGE
    : route.query.error === 'session' ? SESSION_FAILED_MESSAGE : null),
)

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

      <p v-if="displayedError" class="form-error" role="alert">
        {{ displayedError }}
      </p>
      <p v-if="route.query.detail" class="form-error">
        Detalle: {{ route.query.detail }}
      </p>
    </div>
  </main>
</template>
