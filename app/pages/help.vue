<script setup lang="ts">
import type { HelpRole, HelpStage } from '~/utils/helpContent'

const copy = HELP_COPY

const sections = [
  { id: 'juego', label: copy.gameTitle },
  { id: 'roles', label: copy.rolesTitle },
  { id: 'etapas', label: copy.stagesTitle },
  { id: 'categorias-grupales', label: copy.groupTitle },
  { id: 'puntos', label: copy.scoringTitle },
  { id: 'seguridad', label: copy.securityTitle },
  { id: 'instalar', label: copy.installTitle },
  { id: 'dudas', label: copy.faqTitle }
]

// Highlights the outline entry of the section being read
const { activeId } = useActiveSection(sections.map(section => section.id))

// What matters to the person reading: their role's summary, and the stages they take part in
const { participant } = useCurrentParticipant()
const role = computed(() => participant.value?.role as HelpRole | undefined)
const forYou = computed(() => (role.value ? copy.forYou[role.value] ?? null : null))
const isForYou = (stage: HelpStage): boolean => !!role.value && stage.roles.includes(role.value)

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

    <section v-if="forYou" class="card help__for-you" aria-labelledby="para-ti">
      <p class="kicker">
        {{ copy.forYouKicker }}
      </p>
      <h2 id="para-ti">
        {{ forYou.title }}
      </h2>
      <ul>
        <li v-for="point in forYou.points" :key="point">
          {{ point }}
        </li>
      </ul>
    </section>

    <!-- Phones and tablets: sticky row of sections; desktop has the side outline instead -->
    <SectionTabs :items="sections.map(section => ({ id: section.id, title: section.label }))" :label="copy.outlineTitle" until="desktop" />

    <div class="help__layout">
      <aside class="help__aside">
        <nav class="help__outline" :aria-label="copy.outlineTitle">
          <p class="kicker">
            {{ copy.outlineTitle }}
          </p>
          <ul>
            <li v-for="section in sections" :key="section.id">
              <a
                :href="`#${section.id}`"
                :aria-current="activeId === section.id ? 'location' : undefined"
                @click="activeId = section.id"
              >{{ section.label }}</a>
            </li>
          </ul>
        </nav>
      </aside>

      <div class="help__content">
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
          <PhoneCollapse show-label="Ver las seis etapas" hide-label="Ocultar las etapas">
            <ol class="help__stages">
              <li v-for="(stage, index) in copy.stages" :key="stage.title" class="card help__stage" :class="{ 'help__stage--for-you': isForYou(stage) }">
                <span class="help__icon" aria-hidden="true">{{ stage.icon }}</span>
                <div class="help__stage-body">
                  <p class="kicker">
                    Etapa {{ index + 1 }} · {{ stage.who }}
                  </p>
                  <h3>
                    {{ stage.title }}
                    <span v-if="isForYou(stage)" class="badge help__badge">{{ copy.forYouBadge }}</span>
                  </h3>
                  <p>{{ stage.text }}</p>
                </div>
              </li>
            </ol>
          </PhoneCollapse>
        </section>

        <section class="help__section" aria-labelledby="categorias-grupales">
          <h2 id="categorias-grupales">
            {{ copy.groupTitle }}
          </h2>
          <p>{{ copy.groupIntro }}</p>
          <PhoneCollapse show-label="Ver cómo cambia con un grupo" hide-label="Ocultar los detalles">
            <ul class="help__grid">
              <li v-for="item in copy.group" :key="item.title" class="card">
                <h3>{{ item.title }}</h3>
                <p>{{ item.text }}</p>
              </li>
            </ul>
          </PhoneCollapse>
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
          <PhoneCollapse show-label="Ver cómo se protege" hide-label="Ocultar los detalles">
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
          </PhoneCollapse>
        </section>

        <section class="help__section" aria-labelledby="instalar">
          <h2 id="instalar">
            {{ copy.installTitle }}
          </h2>
          <p>{{ copy.installIntro }}</p>
          <ul class="help__grid">
            <li v-for="item in copy.install" :key="item.title" class="card">
              <h3>{{ item.title }}</h3>
              <p>{{ item.text }}</p>
            </li>
          </ul>
          <p class="hint">
            {{ copy.installInApp }}
          </p>
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
      </div>
    </div>

    <BackToTop />
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

.help__layout {
  display: grid;
  gap: var(--space-5);
  align-items: start;

  @media (min-width: 64rem) {
    grid-template-columns: 15rem minmax(0, 1fr);
    gap: var(--space-6);
  }
}

.help__content {
  display: grid;
  gap: var(--space-6);
  min-width: 0;
}

// Below desktop the sticky tabs are the outline
.help__aside {
  display: none;

  @media (min-width: 64rem) {
    position: sticky;
    top: var(--space-5);
    display: block;
  }
}

.help__for-you {
  display: grid;
  gap: var(--space-2);
  border-color: var(--color-primary);
  box-shadow: var(--glow-primary);

  h2 {
    font-size: 1.25rem;
  }

  ul {
    display: grid;
    gap: var(--space-2);
    padding: 0;
    margin: 0;
    list-style: none;
  }

  li {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    gap: var(--space-2);
  }

  li::before {
    color: var(--color-kicker);
    content: '✦';
  }
}

.help__outline {
  display: grid;
  gap: var(--space-2);

  ul {
    display: grid;
    gap: var(--space-1);
    padding-left: var(--space-3);
    border-left: 2px solid var(--color-border, currentcolor);
  }

  a {
    display: block;
    padding: var(--space-1) var(--space-2);
    font-size: 0.9rem;
    color: inherit;
    text-decoration: none;
    border-radius: var(--radius-sm, 0);

    &:hover {
      color: var(--color-primary);
    }

    &[aria-current='location'] {
      font-weight: 700;
      color: var(--color-title);
      background-color: color-mix(in srgb, var(--color-primary) 15%, transparent);
    }
  }
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

  // Phones: the icon sits next to the title and the text uses the full width of the card
  @media (max-width: 47.99rem) {
    grid-template:
      'icon kicker' auto
      'icon title' auto
      'text text' auto / auto minmax(0, 1fr);
    column-gap: var(--space-3);
    row-gap: var(--space-2);

    .help__icon {
      grid-area: icon;
    }

    .help__stage-body {
      display: contents;
    }

    .kicker {
      grid-area: kicker;
      align-self: end;
    }

    h3 {
      grid-area: title;
      align-self: start;
    }

    .help__stage-body > p:last-child {
      grid-area: text;
    }
  }

  &--for-you {
    border-color: var(--color-primary);
  }
}

.help__badge {
  color: var(--color-on-primary);
  background-color: var(--color-primary);
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
