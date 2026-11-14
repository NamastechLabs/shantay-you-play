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
    version: '0.5.0',
    date: '2026-11-14',
    title: 'Descarga de la semana para los comentarios',
    features: [
      'El jurado puede descargar desde la página de la semana un ZIP con los datos y todas las fotos de los looks, listo para pedir los comentarios a una IA.',
    ],
  },
  {
    version: '0.4.0',
    date: '2026-11-14',
    title: 'Vídeo de intro de la pasarela',
    features: [
      'Las juezas pueden subir el vídeo de intro de la semana desde el área de administración, y reemplazarlo cuando quieran.',
      'El área de administración estrena pestañas «Semanas» y «Vídeo de intro», con una tabla de semanas en la que puedes pulsar cualquier fila.',
    ],
  },
  {
    version: '0.3.2',
    date: '2026-11-14',
    title: 'Ayuda con índice y nuevo logo',
    features: [
      'La página de ayuda tiene un índice a un lado para saltar directamente a cada sección y ver en cuál estás.',
      'Todas las páginas tienen ahora el mismo ancho, así que el contenido ya no «salta» al cambiar de una a otra.',
      'Estrenamos logo de Shantay You Play en la barra superior, con su favicon y sus iconos de app.',
    ],
  },
  {
    version: '0.3.1',
    date: '2026-11-14',
    title: 'Votación más simple en semanas de bandas',
    features: [
      'Si la categoría grupal es la única de la semana, el jurado ya no tiene que elegir un Top 3: le basta con votar la banda y ordenar a las reinas.',
      'En la clasificación de las bandas, la columna «Regalo» aparece antes de la Fase 2 y un icono explica de dónde viene.',
    ],
  },
  {
    version: '0.3.0',
    date: '2026-11-14',
    title: 'Votación por bandas y revelación en dos tiempos',
    features: [
      'En las categorías grupales, cada reina ordena a todas las reinas de la banda rival y cada jueza ordena a todas las concursantes, paso a paso y pudiendo volver atrás.',
      'La jueza también elige qué banda gana, y su Top 3 se rellena a partir del orden que ha dado.',
      'En la revelación, primero se descubre la banda ganadora con ruleta y confeti, y después el jurado revela el Top 3 de la semana para todas.',
      'El ranking final de las categorías grupales mezcla el voto de las reinas y el del jurado, con un punto extra para la banda ganadora.',
      'Nueva página «Votación por bandas» con un ejemplo paso a paso de cómo se calculan los puntos.',
      'Las fotos de los grupos se ven con contador y se abren todas juntas, y los resultados de la categoría grupal se abren desde «Ver resultados».',
      'Los grupos pueden tener un texto de presentación, que sus integrantes editan desde «Ver grupo».',
      'Nueva página «Novedades» en el menú de usuario con lo que trae cada versión.',
    ],
  },
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
