<script setup lang="ts">
const copy = HELP_COPY

useHead({ title: `Ayuda · ${APP_NAME}` })
useSeoMeta({ robots: 'noindex' })
</script>

<template>
  <main class="page help">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: copy.breadcrumb }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          {{ copy.kicker }}
        </p>
        <h1>{{ copy.title }}</h1>
      </div>
    </header>

    <p class="lead">
      {{ copy.lead }}
    </p>

    <section class="help__section" aria-labelledby="juego">
      <h2 id="juego">
        {{ copy.gameTitle }}
      </h2>
      <p>{{ copy.gameIntro }}</p>
      <ol class="help__grid help__steps">
        <li v-for="(step, index) in copy.gameSteps" :key="step.title" class="card">
          <span class="help__number" aria-hidden="true">{{ index + 1 }}</span>
          <h3>{{ step.title }}</h3>
          <p>{{ step.text }}</p>
        </li>
      </ol>
    </section>

    <section class="help__section" aria-labelledby="roles">
      <h2 id="roles">
        {{ copy.rolesTitle }}
      </h2>
      <ul class="help__grid">
        <li v-for="role in copy.roles" :key="role.title" class="card">
          <h3>{{ role.title }}</h3>
          <p>{{ role.text }}</p>
        </li>
      </ul>
    </section>

    <section class="help__section" aria-labelledby="etapas">
      <h2 id="etapas">
        {{ copy.stagesTitle }}
      </h2>
      <p>{{ copy.stagesIntro }}</p>
      <ol class="help__stages">
        <li v-for="(stage, index) in copy.stages" :key="stage.title" class="card help__stage">
          <span class="help__icon" aria-hidden="true">{{ stage.icon }}</span>
          <div class="help__stage-body">
            <p class="kicker">
              Etapa {{ index + 1 }} · {{ stage.who }}
            </p>
            <h3>{{ stage.title }}</h3>
            <p>{{ stage.text }}</p>
          </div>
        </li>
      </ol>
    </section>

    <section class="help__section" aria-labelledby="categorias-grupales">
      <h2 id="categorias-grupales">
        {{ copy.groupTitle }}
      </h2>
      <p>{{ copy.groupIntro }}</p>
      <ul class="help__grid">
        <li v-for="item in copy.group" :key="item.title" class="card">
          <h3>{{ item.title }}</h3>
          <p>{{ item.text }}</p>
        </li>
      </ul>
      <NuxtLink :to="GROUP_VOTING_HELP_PATH" class="btn btn--secondary help__back">
        {{ copy.groupHelpLink }}
      </NuxtLink>
    </section>

    <section class="help__section" aria-labelledby="puntos">
      <h2 id="puntos">
        {{ copy.scoringTitle }}
      </h2>
      <p>{{ copy.scoringIntro }}</p>
      <ul class="help__points">
        <li v-for="row in copy.scoring" :key="row.place" class="card">
          <span class="help__place">{{ row.place }}</span>
          <strong>{{ row.points }}</strong>
        </li>
      </ul>
      <p class="hint">
        {{ copy.scoringTies }}
      </p>
    </section>

    <section class="help__section" aria-labelledby="seguridad">
      <h2 id="seguridad">
        {{ copy.securityTitle }}
      </h2>
      <p>{{ copy.securityIntro }}</p>
      <ul class="help__grid">
        <li v-for="item in copy.security" :key="item.title" class="card">
          <h3>{{ item.title }}</h3>
          <p>{{ item.text }}</p>
        </li>
      </ul>

      <div class="card help__callout">
        <h3>{{ copy.blockedTitle }}</h3>
        <p>{{ copy.blockedText }}</p>
      </div>
    </section>

    <section class="help__section" aria-labelledby="dudas">
      <h2 id="dudas">
        {{ copy.faqTitle }}
      </h2>
      <div class="help__faq">
        <details v-for="item in copy.faq" :key="item.title" class="card">
          <summary>{{ item.title }}</summary>
          <p>{{ item.text }}</p>
        </details>
      </div>
    </section>

    <NuxtLink to="/" class="btn btn--primary help__back">
      {{ copy.backHome }}
    </NuxtLink>
  </main>
</template>

<style scoped lang="scss">
.help {
  display: grid;
  gap: var(--space-6);
}

.help__section h2 {
  // Keeps the title off the screen edge when a link jumps to it (e.g. /help#categorias-grupales)
  scroll-margin-top: var(--space-5);
}

.help__section {
  display: grid;
  gap: var(--space-3);
}

.help__grid {
  display: grid;
  gap: var(--space-3);

  @media (min-width: 48rem) {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

.help__steps > li {
  align-content: start;
}

.help__number {
  display: grid;
  place-items: center;
  width: 2rem;
  height: 2rem;
  font-weight: 700;
  color: var(--color-primary-contrast, var(--color-surface));
  background-color: var(--color-primary);
  border-radius: var(--radius-pill);
}

.help__stages {
  display: grid;
  gap: var(--space-3);
}

.help__stage {
  grid-template-columns: auto minmax(0, 1fr);
  align-items: start;
}

.help__icon {
  display: grid;
  place-items: center;
  width: 3rem;
  height: 3rem;
  font-size: 1.5rem;
  background-color: color-mix(in srgb, var(--color-highlight) 30%, var(--color-surface));
  border-radius: var(--radius-pill);
}

.help__stage-body {
  display: grid;
  gap: var(--space-2);
  min-width: 0;

  h3 {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
    align-items: center;
  }
}

.help__points {
  display: grid;
  gap: var(--space-3);
  grid-template-columns: repeat(3, minmax(0, 1fr));

  li {
    justify-items: center;
    text-align: center;
  }
}

.help__place {
  font-family: var(--font-display);
  color: var(--color-title);
}

.help__callout {
  border-color: var(--color-primary);
  box-shadow: var(--glow-primary);
}

.help__faq {
  display: grid;
  gap: var(--space-3);

  summary {
    font-weight: 600;
    cursor: pointer;
  }

  p {
    margin-top: var(--space-2);
  }
}

.help__back {
  justify-self: start;
}
</style>
