export interface ReleaseNote {
  /** Semantic version, same as `package.json` and the Jira fix version (e.g. `0.2.0`) */
  version: string
  /** Day it went live, `YYYY-MM-DD` */
  date: string
  /** Short headline of the release */
  title: string
  /** What users can now do, one sentence each, in Spanish and without technical terms */
  features: string[]
}

/**
 * Release notes shown to users at /novedades, newest first. Every version has an
 * entry, added in the release commit (see CLAUDE.md and the `release` skill),
 * describing the functional changes users will notice, not the technical ones
 * (those go in CHANGELOG.md). A release with nothing users can see gets the
 * single feature "Mejoras y correcciones internas.".
 */
export const RELEASE_NOTES: ReleaseNote[] = [
  {
    version: '0.2.0',
    date: '2026-11-13',
    title: 'Categorías grupales',
    features: [
      'Algunas categorías se juegan por equipos: el jurado reparte a las reinas en dos grupos que compiten entre sí.',
      'Cada grupo sube hasta 4 fotos apaisadas que se ven juntas. Las integrantes las gestionan desde «Ver grupo» en el Werk Room.',
      'En el Werk Room ves los looks de tus compañeras de grupo, justo debajo del tuyo.',
      'Votación por grupos: el jurado elige el grupo ganador (si hay empate, ganan los dos) y cada reina vota a su Top 1 entre las del grupo rival.',
      'Desde la revelación se ven el grupo ganador y la reina Top 1 de la categoría.',
    ],
  },
  {
    version: '0.1.2',
    date: '2026-11-09',
    title: 'Nuevo nombre',
    features: [
      'La app pasa a llamarse Shantay You Play.',
    ],
  },
  {
    version: '0.1.1',
    date: '2026-11-09',
    title: 'La pasarela, bajo llave',
    features: [
      'Hasta que empieza la votación, los looks de la pasarela no se pueden ver antes de tiempo.',
      'Las páginas de error tienen ahora un mensaje con estilo drag, en español.',
    ],
  },
]

/** "2026-11-13" -> "13 de noviembre de 2026" */
export function formatReleaseDate(date: string): string {
  return new Date(`${date}T00:00:00Z`).toLocaleDateString('es', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  })
}
