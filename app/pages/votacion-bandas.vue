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

    <ol class="group-help__phases">
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
          {{ chip.label }}:
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
          {{ band.won ? copy.exampleWon : copy.exampleLost }} · {{ band.members }}
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
              <td class="group-help__total">
                {{ formatScore(row.total) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

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
          {{ formatScore(GROUP_RANKING.weightCross) }} × {{ formatScore(winner.crossScore) }}
          + {{ formatScore(GROUP_RANKING.weightJury) }} × {{ formatScore(winner.juryScore) }}
          + {{ formatScore(winner.bandBonus, 1) }}
          = {{ formatScore(winner.total) }}.
        </p>
      </div>
    </section>

    <section class="card group-help__compare" aria-labelledby="simulacion">
      <h2 id="simulacion">
        {{ copy.compareTitle }}
      </h2>
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
    </section>

    <NuxtLink to="/help" class="btn btn--secondary group-help__back">
      Volver a la ayuda
    </NuxtLink>
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

.group-help__phases {
  display: grid;
  gap: var(--space-3);

  @media (min-width: 48rem) {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  > li {
    align-content: start;
    justify-items: start;
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

.group-help__chips {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.group-help__chip {
  padding: var(--space-1) var(--space-4);
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);

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

// The table scrolls on its own so the page never scrolls sideways on phones
.group-help__table-wrap {
  overflow-x: auto;
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
}

.group-help__compare {
  background-color: color-mix(in srgb, var(--color-accent) 10%, var(--color-surface));
}

.group-help__back {
  justify-self: start;
}
</style>
