<script setup lang="ts">
const copy = GROUP_VOTING_COPY

useHead({ title: `${copy.breadcrumb} · ${APP_NAME}` })
useSeoMeta({ robots: 'noindex' })

/** Splits `**bold**` markers of the copy into segments, so no HTML is injected */
function segments(text: string): { text: string, bold: boolean }[] {
  return text.split('**').map((part, index) => ({ text: part, bold: index % 2 === 1 })).filter(part => part.text)
}

// The worked example is computed from the same constants as the results
const example = GROUP_RANKING_EXAMPLE
const rows = computeRanking(example)
const winner = rows[0]
const bands = [
  { name: example.winningBand, won: true },
  ...[...new Set(example.contestants.map(contestant => contestant.band))]
    .filter(band => band !== example.winningBand)
    .map(band => ({ name: band, won: false })),
].map(band => ({
  ...band,
  members: example.contestants.filter(contestant => contestant.band === band.name).map(contestant => contestant.id).join(', '),
}))

/** Pairs of contestants that tie on the total and are separated by the tie-break */
const tiedPair = computed(() => {
  for (let index = 1; index < rows.length; index++) {
    const previous = rows[index - 1]!
    const current = rows[index]!
    if (previous.total === current.total) return { first: previous, second: current }
  }
  return null
})

const mentionsAlternative = GROUP_RANKING.bandBonus < copy.compareBonusOriginal

// What the reader does in this voting, by role
const { participant } = useCurrentParticipant()
const myPart = computed(() => {
  const role = participant.value?.role as keyof typeof copy.forYou | undefined
  return role ? copy.forYou[role] ?? null : null
})

// Sticky row of sections on phones and tablets (the page is short enough on desktop)
const tabs = [
  { id: 'fases', title: copy.tabs.phases },
  { id: 'valores', title: copy.tabs.values },
  { id: 'nota-final', title: copy.tabs.formula },
  { id: 'ejemplo', title: copy.tabs.example },
  { id: 'simulacion', title: copy.tabs.compare },
]
</script>

<template>
  <main class="page group-help">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Ayuda', to: '/help' }, { label: copy.breadcrumb }]" />

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

    <p v-if="myPart" class="card group-help__for-you">
      <span class="kicker">{{ copy.forYouKicker }}</span>
      {{ myPart }}
    </p>

    <SectionTabs :items="tabs" :label="copy.outlineTitle" until="desktop" />

    <!-- Phones: the four phases slide sideways (the next card peeks out), so they do not take a whole screen each -->
    <section id="fases" class="group-help__phases-wrap" :aria-label="copy.phasesLabel">
      <ol class="group-help__phases" tabindex="0">
        <li v-for="(phase, index) in copy.phases" :key="phase.tag" class="card">
          <span class="badge" :class="`group-help__tag--${index + 1}`">{{ phase.tag }}</span>
          <h2 class="group-help__card-title">
            {{ phase.title }}
          </h2>
          <p>
            <template v-for="(part, partIndex) in segments(phase.text)" :key="partIndex">
              <strong v-if="part.bold">{{ part.text }}</strong>
              <template v-else>{{ part.text }}</template>
            </template>
          </p>
        </li>
      </ol>
      <p class="hint group-help__swipe" aria-hidden="true">
        {{ copy.phasesHint }} →
      </p>
    </section>

    <section class="group-help__section" aria-labelledby="valores">
      <h2 id="valores">
        {{ copy.valuesTitle }}
      </h2>
      <p>
        <template v-for="(part, partIndex) in segments(copy.valuesText)" :key="partIndex">
          <strong v-if="part.bold">{{ part.text }}</strong>
          <template v-else>{{ part.text }}</template>
        </template>
      </p>
      <ul class="group-help__chips">
        <li v-for="chip in [copy.valuesCross, copy.valuesJury]" :key="chip.label" class="group-help__chip">
          <span>{{ chip.label }}:</span>
          <strong>{{ chip.values.join(' · ') }}</strong>
        </li>
      </ul>
    </section>

    <section class="group-help__section" aria-labelledby="nota-final">
      <h2 id="nota-final">
        {{ copy.formulaTitle }}
      </h2>
      <div class="card group-help__formula">
        <p class="group-help__equation">
          <template v-for="(term, index) in copy.formulaTerms" :key="term">
            <span class="group-help__term">{{ term }}</span>
            <span class="group-help__operator" aria-hidden="true">{{ index < copy.formulaTerms.length - 1 ? '+' : '=' }}</span>
          </template>
          <span class="group-help__term group-help__term--result">{{ copy.formulaResult }}</span>
        </p>
        <h3 class="group-help__subtitle">
          {{ copy.formulaGroupTitle }}
        </h3>
        <p class="group-help__equation">
          <template v-for="(term, index) in copy.formulaGroupTerms" :key="term">
            <span class="group-help__term">{{ term }}</span>
            <span class="group-help__operator" aria-hidden="true">{{ index < copy.formulaGroupTerms.length - 1 ? '+' : '=' }}</span>
          </template>
          <span class="group-help__term group-help__term--result">{{ copy.formulaGroupResult }}</span>
        </p>
        <p class="hint">
          {{ copy.formulaNote }}
        </p>
      </div>
    </section>

    <section class="group-help__section" aria-labelledby="ejemplo">
      <h2 id="ejemplo">
        {{ copy.exampleTitle }}
      </h2>
      <ul class="group-help__chips">
        <li v-for="band in bands" :key="band.name" class="group-help__chip">
          <strong>{{ band.name }}</strong>
          <span>{{ band.won ? copy.exampleWon : copy.exampleLost }} · {{ band.members }}</span>
        </li>
      </ul>

      <div class="group-help__table-wrap" tabindex="0" role="region" :aria-label="copy.exampleTitle">
        <table class="group-help__table">
          <thead>
            <tr>
              <th v-for="header in copy.exampleHeaders" :key="header" scope="col">
                {{ header }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row.id" :class="{ 'group-help__winner': row.id === winner?.id }">
              <th scope="row">
                <span class="group-help__position">{{ row.position }}.º</span>
                {{ row.id }}
                <span class="group-help__band">{{ row.band }}</span>
              </th>
              <td>{{ formatScore(row.crossScore) }}</td>
              <td>{{ formatScore(row.juryScore) }}</td>
              <td>{{ row.bandBonus ? formatScore(row.bandBonus, 1) : '0' }}</td>
              <td>{{ formatScore(row.top3Score) }}</td>
              <td class="group-help__total">
                {{ formatScore(row.total) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Phones: a card per queen, so the final score is never off screen -->
      <ol class="group-help__queens" :aria-label="copy.exampleTitle">
        <li v-for="row in rows" :key="row.id" class="group-help__queen" :class="{ 'group-help__queen--winner': row.id === winner?.id }">
          <div class="group-help__queen-head">
            <span class="group-help__position">{{ row.position }}.º</span>
            <span class="group-help__queen-name">
              {{ row.id }}
              <span class="group-help__band">{{ row.band }}</span>
            </span>
            <span class="group-help__queen-total">
              <span class="group-help__queen-label">{{ copy.exampleHeaders[5] }}</span>
              {{ formatScore(row.total) }}
            </span>
          </div>
          <dl class="group-help__queen-stats">
            <div>
              <dt>{{ copy.exampleHeaders[1] }}</dt>
              <dd>{{ formatScore(row.crossScore) }}</dd>
            </div>
            <div>
              <dt>{{ copy.exampleHeaders[2] }}</dt>
              <dd>{{ formatScore(row.juryScore) }}</dd>
            </div>
            <div>
              <dt>{{ copy.exampleHeaders[3] }}</dt>
              <dd>{{ row.bandBonus ? formatScore(row.bandBonus, 1) : '0' }}</dd>
            </div>
            <div>
              <dt>{{ copy.exampleHeaders[4] }}</dt>
              <dd>{{ formatScore(row.top3Score) }}</dd>
            </div>
          </dl>
        </li>
      </ol>

      <div v-if="winner" class="group-help__notes">
        <p class="card">
          <strong>Ganadora individual: {{ winner.id }}</strong>, de la banda {{ winner.band === example.winningBand ? 'ganadora' : 'perdedora' }}.
          Su nota final es {{ formatScore(winner.total) }}, la más alta de todas.
        </p>
        <p v-if="tiedPair" class="card">
          <strong>{{ tiedPair.first.id }} y {{ tiedPair.second.id }} empatan</strong> a {{ formatScore(tiedPair.first.total) }}.
          {{ tiedPair.first.id }} queda por delante porque los Javis le dieron mejor nota
          ({{ formatScore(tiedPair.first.juryScore) }} frente a {{ formatScore(tiedPair.second.juryScore) }}).
        </p>
        <p class="card">
          <strong>Cuenta de {{ winner.id }}:</strong>
          <span class="group-help__step">{{ formatScore(GROUP_RANKING.weightGroup) }} × ({{ formatScore(GROUP_RANKING.weightCross) }} × {{ formatScore(winner.crossScore) }}</span>
          <span class="group-help__step">+ {{ formatScore(GROUP_RANKING.weightJury) }} × {{ formatScore(winner.juryScore) }}</span>
          <span class="group-help__step">+ {{ formatScore(winner.bandBonus, 1) }})</span>
          <span class="group-help__step">+ {{ formatScore(GROUP_RANKING.weightTop3) }} × {{ formatScore(winner.top3Score) }}</span>
          <span class="group-help__step group-help__step--result">= {{ formatScore(winner.total) }}.</span>
        </p>
      </div>
    </section>

    <section class="card group-help__compare" aria-labelledby="simulacion">
      <h2 id="simulacion">
        {{ copy.compareTitle }}
      </h2>
      <PhoneCollapse :show-label="copy.compareShow" :hide-label="copy.compareHide">
        <p>
          <template v-for="(part, partIndex) in segments(copy.compareNow(winner?.id ?? ''))" :key="partIndex">
            <strong v-if="part.bold">{{ part.text }}</strong>
            <template v-else>{{ part.text }}</template>
          </template>
        </p>
        <p v-if="mentionsAlternative">
          <template v-for="(part, partIndex) in segments(copy.compareAlternative(copy.compareBonusOriginal))" :key="partIndex">
            <strong v-if="part.bold">{{ part.text }}</strong>
            <template v-else>{{ part.text }}</template>
          </template>
        </p>
      </PhoneCollapse>
    </section>

    <NuxtLink to="/help" class="btn btn--secondary group-help__back">
      Volver a la ayuda
    </NuxtLink>

    <BackToTop />
  </main>
</template>

<style scoped lang="scss">
.group-help {
  display: grid;
  gap: var(--space-6);
}

.group-help__section {
  display: grid;
  gap: var(--space-3);
}

.group-help__for-you {
  // `.card` is a grid: the kicker and the sentence stay in one block
  display: block;
  border-color: var(--color-primary);
  box-shadow: var(--glow-primary);

  .kicker {
    display: block;
    margin-bottom: var(--space-1);
  }
}

.group-help__phases-wrap {
  display: grid;
  gap: var(--space-2);
}

.group-help__phases {
  display: grid;
  gap: var(--space-3);

  // Phones: one card at a time, sliding sideways; the next one peeks out
  @media (max-width: 47.99rem) {
    grid-auto-columns: 82%;
    grid-auto-flow: column;
    padding-bottom: var(--space-2);
    margin-inline: calc(var(--space-4) * -1);
    padding-inline: var(--space-4);
    overflow-x: auto;
    overscroll-behavior-x: contain;
    scroll-padding-inline: var(--space-4);
    scroll-snap-type: x mandatory;
    scrollbar-width: none;

    &::-webkit-scrollbar {
      display: none;
    }

    > li {
      scroll-snap-align: start;
    }
  }

  @media (min-width: 48rem) {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  @media (min-width: 64rem) {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  > li {
    align-content: start;
    justify-items: start;
  }
}

.group-help__swipe {
  text-align: right;

  @media (min-width: 48rem) {
    display: none;
  }
}

.group-help__card-title {
  font-size: 1.125rem;
}

// One accent per phase, from the theme tokens
.group-help__tag--1 {
  background-color: var(--color-primary);
}

.group-help__tag--2 {
  background-color: var(--color-accent);
}

.group-help__tag--3 {
  background-color: var(--color-highlight);
}

.group-help__tag--4 {
  background-color: var(--color-success);
}

.group-help__subtitle {
  margin-top: var(--space-3);
  font-size: 1rem;
}

.group-help__chips {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

// Rounded rectangles, not pills: the text wraps onto two lines on a phone
.group-help__chip {
  display: flex;
  flex-wrap: wrap;
  gap: 0 var(--space-2);
  padding: var(--space-1) var(--space-4);
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);

  strong {
    color: var(--color-title);
  }
}

.group-help__formula {
  background-color: color-mix(in srgb, var(--color-primary) 10%, var(--color-surface));
}

.group-help__equation {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: center;
  font-weight: 600;
}

.group-help__term {
  padding: var(--space-2) var(--space-3);
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.group-help__term--result {
  color: var(--color-on-accent);
  background-color: var(--color-primary);
  border-color: transparent;
}

.group-help__operator {
  font-weight: 800;
  color: var(--color-title);
}

// The table scrolls on its own so the page never scrolls sideways on tablets; phones show cards instead
.group-help__table-wrap {
  overflow-x: auto;

  @media (max-width: 47.99rem) {
    display: none;
  }

  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
}

.group-help__table {
  width: 100%;
  min-width: 34rem;
  border-collapse: collapse;
  font-variant-numeric: tabular-nums;

  th,
  td {
    padding: var(--space-3);
    text-align: right;
  }

  th:first-child {
    text-align: left;
  }

  thead th {
    font-size: 0.75rem;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--color-text-muted);
  }

  tbody tr + tr > * {
    border-top: 1px solid var(--color-border);
  }

  tbody th {
    font-weight: 600;
  }
}

// Phones: a card per queen with the final score big and the phases below
.group-help__queens {
  display: grid;
  gap: var(--space-3);
  padding: 0;
  margin: 0;
  list-style: none;

  @media (min-width: 48rem) {
    display: none;
  }
}

.group-help__queen {
  display: grid;
  gap: var(--space-3);
  padding: var(--space-3) var(--space-4);
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);

  &--winner {
    background-color: color-mix(in srgb, var(--color-highlight) 25%, var(--color-surface));
  }
}

.group-help__queen-head {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: var(--space-2);
  align-items: center;
}

.group-help__queen-name {
  font-weight: 700;
}

.group-help__queen-total {
  display: grid;
  justify-items: end;
  font-family: var(--font-display);
  font-size: 1.5rem;
  line-height: 1.1;
  color: var(--color-title);
  font-variant-numeric: tabular-nums;
}

.group-help__queen-label {
  font-family: var(--font-body);
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  color: var(--color-text-muted);
  text-transform: uppercase;
}

.group-help__queen-stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--space-2);
  padding-top: var(--space-2);
  margin: 0;
  border-top: 1px solid var(--color-border);
  font-variant-numeric: tabular-nums;

  dt {
    font-size: 0.6875rem;
    font-weight: 700;
    letter-spacing: 0.06em;
    color: var(--color-text-muted);
    text-transform: uppercase;
  }

  dd {
    margin: 0;
    font-weight: 600;
  }
}

.group-help__winner > * {
  background-color: color-mix(in srgb, var(--color-highlight) 25%, var(--color-surface));
}

.group-help__position {
  display: inline-block;
  min-width: 1.75rem;
  font-weight: 800;
  color: var(--color-title);
}

.group-help__band {
  font-size: 0.8125rem;
  font-weight: 400;
  color: var(--color-text-muted);
}

.group-help__total {
  font-weight: 800;
}

.group-help__notes {
  display: grid;
  gap: var(--space-3);

  // `.card` is a grid: without this the bold lead and the rest of the sentence land on separate rows
  > .card {
    display: block;
  }
}

// The calculation: one step per line on phones, running text from tablets up
.group-help__step {
  @media (max-width: 47.99rem) {
    display: block;
    padding-left: var(--space-3);

    &:first-of-type {
      padding-left: 0;
    }
  }

  &--result {
    font-weight: 700;
  }
}

.group-help__compare {
  background-color: color-mix(in srgb, var(--color-accent) 10%, var(--color-surface));
}

.group-help__back {
  justify-self: start;
}
</style>
