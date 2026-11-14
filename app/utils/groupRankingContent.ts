import { APP_NAME } from './brand'
import { GROUP_RANKING, GROUP_RANKING_MAX_TOTAL, formatScore, rankValue } from './groupRanking'

/** Route of the help page that explains the group voting system */
export const GROUP_VOTING_HELP_PATH = '/votacion-bandas'

/** Short number for prose ("0,2", "1,2"): no trailing zeros */
const plain = (value: number): string => new Intl.NumberFormat('es-ES', { maximumFractionDigits: 3 }).format(value)

/** "½" for 0.5, otherwise a percentage ("40 %"), so the text follows the weights */
const share = (weight: number): string => weight === 0.5 ? '½' : `${Math.round(weight * 100)} %`

const values = (candidates: number, decimals: number): string[] =>
  Array.from({ length: candidates }, (_, index) => formatScore(rankValue(index + 1, candidates), decimals))

/** Spanish copy of `/votacion-bandas`. Every number comes from `GROUP_RANKING`. `**x**` marks bold text. */
export const GROUP_VOTING_COPY = {
  breadcrumb: 'Votación de bandas',
  helpLink: '¿Cómo funciona esta votación?',
  kicker: `${APP_NAME} · Categorías de grupo`,
  title: 'Cómo funciona la votación de las bandas',
  lead: `Tres votaciones, una nota entre 0 y 1 para cada concursante, y un regalo para la banda que gane la primera fase.`,

  phases: [
    {
      tag: 'Fase 1',
      title: 'Los Javis votan a las bandas',
      text: `Eligen qué banda ha trabajado mejor. La ganadora sale arriba en la clasificación provisional y cada una de sus integrantes recibe **${plain(GROUP_RANKING.bandBonus)}** en su nota final.`,
    },
    {
      tag: 'Fase 2',
      title: 'Votación cruzada',
      text: 'Cada concursante ordena a **todas** las de la banda contraria, según sus looks individuales. No se puede dejar a nadie sin ordenar.',
    },
    {
      tag: 'Fase 3',
      title: 'Pasarela de los Javis',
      text: 'Cada Javi ordena a **todas** las concursantes según su look individual. Con varios Javis se hace la media de sus notas.',
    },
  ],

  valuesTitle: 'Cuánto vale cada puesto',
  valuesText: 'La favorita siempre vale **1**. Los demás puestos valen menos, según cuántas haya que ordenar. La nota de la fase 2 es la **media** de lo que le ha dado cada votante, para ser justos con bandas de distinto tamaño.',
  valuesCross: { label: 'Fase 2, banda de 3', values: values(3, 2) },
  valuesJury: { label: 'Fase 3, 6 concursantes', values: values(6, 2) },

  formulaTitle: 'La nota final',
  formulaTerms: [
    `${share(GROUP_RANKING.weightCross)} de la fase 2`,
    `${share(GROUP_RANKING.weightJury)} de la fase 3`,
    `${plain(GROUP_RANKING.bandBonus)} si tu banda ganó la fase 1`,
  ],
  formulaResult: 'Nota final',
  formulaNote: `La nota máxima posible es ${plain(GROUP_RANKING_MAX_TOTAL)}. Si dos concursantes empatan, pasa delante la de la banda ganadora y, si siguen empatadas, la que tenga mejor nota de la fase 3.`,

  exampleTitle: 'Ejemplo completo',
  exampleWon: 'ganó la fase 1',
  exampleLost: 'perdió la fase 1',
  exampleHeaders: ['Concursante', 'Fase 2', 'Fase 3', 'Regalo', 'Nota final'],

  compareTitle: 'Diferencia con la simulación original',
  /** Bonus roughly equivalent to the +6 points of the original simulation */
  compareBonusOriginal: 0.4,
  compareNow: (winner: string): string =>
    `En la simulación, la banda ganadora recibe **+6 puntos** y gana A con 17. Aquí el regalo es de **${plain(GROUP_RANKING.bandBonus)}** y gana ${winner}.`,
  compareAlternative: (bonus: number): string =>
    `Con un regalo de **${plain(bonus)}**, más o menos el +6 de la simulación, la banda ganadora tendría una ventaja mucho mayor. Se cambia con un solo número.`,
}

export const GROUP_RESULT_COPY = {
  title: 'Clasificación final',
  headers: { position: 'Puesto', name: 'Reina', cross: 'Fase 2', jury: 'Fase 3', bonus: 'Regalo', total: 'Nota final' },
  winningBand: 'Banda ganadora',
  winningBands: 'Bandas ganadoras (empate)',
  empty: 'Todavía no hay votos para calcular la clasificación.',
  band: 'Banda',
}
