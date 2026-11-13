<script setup lang="ts">
useHead({ title: `Novedades · ${APP_NAME}` })
useSeoMeta({ robots: 'noindex' })
</script>

<template>
  <main class="page novedades">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Novedades' }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          Lo último del taller
        </p>
        <h1>Novedades</h1>
      </div>
    </header>

    <p class="lead">
      Aquí tienes lo que hemos ido estrenando, con su fecha. ¡Lo más nuevo, primero!
    </p>

    <ol class="novedades__list">
      <li v-for="release in RELEASE_NOTES" :id="`v${release.version}`" :key="release.version" class="card novedades__release">
        <p class="kicker">
          <time :datetime="release.date">{{ formatReleaseDate(release.date) }}</time>
          · Versión {{ release.version }}
        </p>
        <h2>{{ release.title }}</h2>
        <ul class="novedades__features">
          <li v-for="feature in release.features" :key="feature">
            {{ feature }}
          </li>
        </ul>
      </li>
    </ol>

    <NuxtLink to="/" class="btn btn--primary novedades__back">
      Volver a la pasarela
    </NuxtLink>
  </main>
</template>

<style scoped lang="scss">
.novedades {
  display: grid;
  gap: var(--space-5);
}

.novedades__list {
  display: grid;
  gap: var(--space-4);
  max-width: 48rem;
  padding: 0;
  margin: 0;
  list-style: none;
}

.novedades__release {
  display: grid;
  gap: var(--space-2);
  // A link like /novedades#v0.2.0 lands with some air above the card
  scroll-margin-top: var(--space-5);

  h2 {
    font-size: 1.25rem;
    color: var(--color-title);
  }
}

.novedades__features {
  display: grid;
  gap: var(--space-2);
  padding-left: var(--space-4);
  margin: 0;
}

.novedades__back {
  justify-self: start;
}
</style>
