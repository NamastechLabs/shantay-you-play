<script setup lang="ts">
import type { NuxtError } from '#app'

const props = defineProps<{ error: NuxtError }>()

const { theme } = useTheme()
useHead({ htmlAttrs: { 'data-theme': theme, 'lang': 'es' }, title: 'Drag Race Game' })
useSeoMeta({ robots: 'noindex' })

const isForbidden = computed(() => props.error.statusCode === 403)
const isNotFound = computed(() => props.error.statusCode === 404)

const title = computed(() => {
  if (isForbidden.value) return 'Pasarela cerrada'
  if (isNotFound.value) return 'Página no encontrada'
  return 'Algo salió mal'
})

// 403 and 404 carry their own friendly Spanish message; anything else stays generic
const message = computed(() =>
  isForbidden.value || isNotFound.value
    ? props.error.statusMessage ?? ''
    : 'Ha ocurrido un error inesperado. Inténtalo de nuevo en un momento.',
)
</script>

<template>
  <main class="page error-page">
    <p class="kicker">
      Error {{ error.statusCode }}
    </p>
    <h1>{{ title }}</h1>
    <p class="lead">
      {{ message }}
    </p>
    <button type="button" class="btn btn--primary" @click="clearError({ redirect: '/' })">
      Volver al inicio
    </button>
  </main>
</template>

<style scoped>
.error-page {
  text-align: center;
  align-items: center;
}
</style>
