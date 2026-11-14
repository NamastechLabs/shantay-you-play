/**
 * Scoring constants of the group categories (DRG-8).
 *
 * They MUST match the constants at the top of `category_ranking_result`, as last defined in
 * `supabase/migrations/20261114000100_runway_reveal_stage.sql` (or a later migration that replaces it). The help page `/votacion-bandas` reads them from here,
 * so changing a value means: new migration for the function + this file. The worked
 * example of the help page is recomputed from these values.
 */
export const GROUP_RANKING = {
  /** Weight of the cross vote (contestants rank the rival band) */
  weightCross: 0.5,
  /** Weight of the jury runway vote */
  weightJury: 0.5,
  /** Fixed bonus for every member of the band that won the bands vote */
  bandBonus: 0.2,
} as const

/** Highest possible total: both scores at 1 plus the bonus */
export const GROUP_RANKING_MAX_TOTAL = GROUP_RANKING.weightCross + GROUP_RANKING.weightJury + GROUP_RANKING.bandBonus

/** Value of one vote: (N - rank + 1) / N, where N is the number of candidates on the ballot. The favourite always weighs 1. */
export function rankValue(rank: number, candidates: number): number {
  return (candidates - rank + 1) / candidates
}

/** Same rounding as the database function, so that equal fractions (e.g. 2/3) compare as equal */
function round6(value: number): number {
  return Math.round(value * 1e6) / 1e6
}

const scoreFormatters = new Map<number, Intl.NumberFormat>()

/** Normalized values are shown with 3 decimals (0,667), never rounded to whole numbers */
export function formatScore(value: number, decimals = 3): string {
  let formatter = scoreFormatters.get(decimals)
  if (!formatter) {
    formatter = new Intl.NumberFormat('es-ES', { minimumFractionDigits: decimals, maximumFractionDigits: decimals })
    scoreFormatters.set(decimals, formatter)
  }
  return formatter.format(value)
}

export interface RankingContestant {
  id: string
  /** Band the contestant belongs to */
  band: string
}

export interface RankingInput {
  contestants: RankingContestant[]
  /** Band that won the bands vote (phase 1) */
  winningBand: string
  /** Each ballot lists contestant ids from favourite to last */
  crossBallots: string[][]
  juryBallots: string[][]
}

export interface RankingRow {
  id: string
  band: string
  crossScore: number
  juryScore: number
  bandBonus: number
  total: number
  position: number
}

function averageValues(ballots: string[][], id: string): number {
  const values = ballots
    .map(ballot => ({ index: ballot.indexOf(id), size: ballot.length }))
    .filter(({ index }) => index !== -1)
    .map(({ index, size }) => rankValue(index + 1, size))
  return values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : 0
}

/**
 * Mirror of `category_ranking_result`, used only for the worked example of the help page.
 * The real results always come from the database.
 */
export function computeRanking(input: RankingInput): RankingRow[] {
  const rows = input.contestants.map((contestant) => {
    const crossScore = round6(averageValues(input.crossBallots, contestant.id))
    const juryScore = round6(averageValues(input.juryBallots, contestant.id))
    const bandBonus = contestant.band === input.winningBand ? GROUP_RANKING.bandBonus : 0
    const total = round6(GROUP_RANKING.weightCross * crossScore + GROUP_RANKING.weightJury * juryScore + bandBonus)
    return { id: contestant.id, band: contestant.band, crossScore, juryScore, bandBonus, total, position: 0 }
  })

  const isWinner = (row: RankingRow): number => row.band === input.winningBand ? 1 : 0
  rows.sort((a, b) => b.total - a.total || isWinner(b) - isWinner(a) || b.juryScore - a.juryScore)

  let position = 0
  rows.forEach((row, index) => {
    const previous = rows[index - 1]
    const tied = previous
      && previous.total === row.total
      && isWinner(previous) === isWinner(row)
      && previous.juryScore === row.juryScore
    // Shared positions, like rank() in SQL
    if (!tied) position = index + 1
    row.position = position
  })
  return rows
}

/** Worked example of the help page: bands HOT and COLD, six contestants */
export const GROUP_RANKING_EXAMPLE: RankingInput = {
  contestants: [
    { id: 'A', band: 'HOT' },
    { id: 'B', band: 'HOT' },
    { id: 'C', band: 'HOT' },
    { id: 'D', band: 'COLD' },
    { id: 'E', band: 'COLD' },
    { id: 'F', band: 'COLD' },
  ],
  winningBand: 'HOT',
  // Every HOT contestant ranks COLD as D, E, F and every COLD contestant ranks HOT as A, B, C
  crossBallots: [
    ['D', 'E', 'F'], ['D', 'E', 'F'], ['D', 'E', 'F'],
    ['A', 'B', 'C'], ['A', 'B', 'C'], ['A', 'B', 'C'],
  ],
  // One judge ranks the six looks
  juryBallots: [['D', 'E', 'B', 'F', 'A', 'C']],
}
