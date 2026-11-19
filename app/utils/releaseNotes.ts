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
 * Release notes shown to users at /release-notes, newest first. Every version has an
 * entry, added in the release commit (see CLAUDE.md and the `release` skill),
 * describing the functional changes users will notice, not the technical ones
 * (those go in CHANGELOG.md). A release with nothing users can see gets the
 * single feature "Mejoras y correcciones internas.".
 */
export const RELEASE_NOTES: ReleaseNote[] = [
  {
    version: '0.13.0',
    date: '2026-11-19',
    title: 'De invitada especial a concursante',
    features: [
      'El jurado puede pasar a una invitada especial a concursante desde «Participantes», sin perder nada: conserva sus invitaciones, sus looks y sus votos.',
      'En «Mis looks» se ven por separado los looks como concursante y los looks como jurado o invitada especial.',
    ],
  },
  {
    version: '0.12.0',
    date: '2026-11-19',
    title: 'Instala la app en tu móvil',
    features: [
      'Ahora puedes instalar Shantay You Play en la pantalla de inicio de tu móvil y abrirla con un toque, sin barra del navegador y con su propio icono.',
      'En el menú, «Instalar app» te lo pone fácil: en Android abre la instalación y en iPhone te enseña los pasos. Si ya la tienes instalada, no aparece.',
      'La app se actualiza sola y, si te quedas sin conexión, te avisa para que puedas reintentar.',
      'El color de la barra del móvil cambia con el tema que elijas.',
      'En la página de votar, desde el móvil, el título de la semana tiene todo el ancho y el botón se ha convertido en «Enviar» con un icono, para que quepa mejor.',
      'La Ayuda tiene una sección nueva, «Instala la app en tu móvil».',
    ],
  },
  {
    version: '0.11.0',
    date: '2026-11-18',
    title: 'Pensada para el móvil',
    features: [
      'Nuevo menú en el móvil: tu foto, arriba a la derecha, abre tu menú (perfil, looks y salir) y las tres rayas, arriba a la izquierda, abren el resto de páginas y el cambio de tema.',
      'Mientras la semana está en el Werk Room, la página de inicio muestra una cuenta atrás hasta que abra la pasarela.',
      'En la votación, el inicio y la página de la semana te dicen si ya has votado («Votado» o «Pendiente») y puedes cambiar tu Top 3 desde ahí.',
      'Votar es más rápido en el móvil: dos reinas por fila, una lupa para ver el look completo sin elegirla y una barra de tu Top 3 más pequeña.',
      'La página de la semana enseña las reinas de dos en dos, con un botón para votar también al final y otro para volver arriba.',
      'Los looks del jurado se deslizan de lado en el móvil y su presentación se abre al tocarlos.',
      'Los textos largos de los retos y de los looks se acortan con «Leer reto completo» y «Ver más», y las fotos muestran el logo mientras cargan.',
      'En una semana con varias categorías hay pestañas fijas para saltar de una a otra.',
      'Ayuda y Novedades tienen un índice fijo y un botón para volver arriba; la Ayuda empieza con un resumen «Para ti» según tu rol.',
      'La explicación de la votación de las bandas se lee mejor en el móvil, con una tarjeta por reina en el ejemplo.',
    ],
  },
  {
    version: '0.10.0',
    date: '2026-11-17',
    title: 'Los looks del jurado, en «Mis looks»',
    features: [
      'El jurado y las invitadas especiales ya ven sus propios looks y presentaciones en «Mis looks».',
    ],
  },
  {
    version: '0.9.0',
    date: '2026-11-17',
    title: 'Quién votó a quién',
    features: [
      'Cuando una semana está cerrada, el botón «Resultados» muestra a quién votó cada persona en su Top 3, con las fotos de perfil y los puntos de cada reina.',
      'Los votos de las invitadas especiales siguen siendo anónimos.',
      'En una semana con categoría grupal, la clasificación de «Ver resultados» se ve en el móvil como una tarjeta por reina y muestra su foto de perfil.',
    ],
  },
  {
    version: '0.8.1',
    date: '2026-11-17',
    title: 'Una categoría grupal va sola',
    features: [
      'Una pasarela con categoría grupal ya no admite más categorías: el botón de nueva categoría se desactiva y se explica por qué.',
      'Para guardar una categoría como grupal hay que quitar antes las categorías individuales; el panel avisa de ello.',
    ],
  },
  {
    version: '0.8.0',
    date: '2026-11-17',
    title: 'Looks del jurado según la etapa de la semana',
    features: [
      'En el panel del jurado, los looks de las reinas y las fotos de los grupos quedan ocultos durante el Werk Room: se ven con «Ver los looks» o «Ver las fotos» y se cambian con «Editar».',
      'Desde la Pasarela, los looks y las fotos se muestran solo para verlos, con la opción de editarlos mientras todavía se puedan cambiar.',
      'La pestaña de jurados ahora incluye también los looks de los invitados especiales de la semana.',
    ],
  },
  {
    version: '0.7.1',
    date: '2026-11-17',
    title: 'Todas las bandas con foto antes de desfilar',
    features: [
      'El jurado no puede pasar una semana del Werk Room a la Pasarela mientras alguna banda no tenga al menos una foto, y se le avisa de cuáles faltan.',
    ],
  },
  {
    version: '0.7.0',
    date: '2026-11-15',
    title: 'Una sola ganadora en las semanas de bandas',
    features: [
      'En las semanas con bandas, el Top 3 de la semana suma a la clasificación: el podio que se revela es el mismo que el de la tabla de resultados.',
      'La tabla de resultados tiene una columna nueva con la nota del Top 3.',
      'La página «Cómo funciona esta votación» explica la nueva nota final con un ejemplo.',
    ],
  },
  {
    version: '0.6.0',
    date: '2026-11-15',
    title: 'Bandas en los comentarios y logo con corona',
    features: [
      'El ZIP de la semana para los comentarios con IA incluye ahora las bandas: su nombre, presentación, integrantes y fotos.',
      'Estrenamos logo con corona en la barra de navegación, además de un nuevo icono de la app.',
    ],
  },
  {
    version: '0.5.1',
    date: '2026-11-15',
    title: 'Fotos de los looks más claras',
    features: [
      'Las fotos de cada look ahora se llaman Foto 1, Foto 2, Foto 3 y Foto 4, igual que las de los grupos.',
      'Las fotos subidas desde Safari y desde el iPhone también se guardan optimizadas y más ligeras.',
    ],
  },
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
