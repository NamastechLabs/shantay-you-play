export type HelpRole = 'concursante' | 'jurado' | 'invitado'

export interface HelpStage {
  icon: string
  title: string
  who: string
  /** Roles that do something in this stage: the card says "Para ti" to them */
  roles: HelpRole[]
  text: string
}

export interface HelpForYou {
  title: string
  points: string[]
}

export interface HelpFact {
  title: string
  text: string
}

export const HELP_COPY = {
  kicker: 'Manual de la reina',
  title: 'Ayuda: cómo se juega',
  lead: '¡Bienvenida al taller, reina! Aquí tienes todo lo que necesitas saber para desfilar, votar y no quedar en el lip sync.',
  breadcrumb: 'Ayuda',
  outlineTitle: 'En esta página',

  forYouKicker: 'Para ti',
  forYouBadge: 'Para ti',
  forYou: {
    concursante: {
      title: 'Si eres concursante',
      points: [
        'Werk Room: sube hasta 4 fotos de tu look y escribe tu presentación.',
        'Pasarela: pulsa «A desfilar» en la página de inicio para compartir tu look en el grupo de WhatsApp.',
        'Votación: elige tu Top 3 de reinas (no puedes votarte a ti misma).',
        'Cerrada: tus puntos y tu puesto quedan guardados en «Mis looks».',
      ],
    },
    jurado: {
      title: 'Si eres del jurado',
      points: [
        'Prepara la semana, sus categorías, los grupos y las participantes desde el «Panel del jurado».',
        'Cambia la semana de etapa cuando toque: todas lo verán al instante.',
        'Sube el vídeo de introducción de la pasarela antes de abrirla.',
        'En la revelación, pulsa «Revelar el Top 3 de la semana» cuando toque.',
      ],
    },
    invitado: {
      title: 'Si eres invitada especial',
      points: [
        'Werk Room: sube tu look de jurado desde la página de inicio.',
        'Pasarela: pulsa «A desfilar» para compartir tu look en el grupo de WhatsApp.',
        'Votación: eliges tu Top 3 de reinas y tus votos son anónimos.',
        'Tus looks quedan guardados en «Mis looks».',
      ],
    },
  } satisfies Record<HelpRole, HelpForYou>,

  gameTitle: 'La lógica del juego',
  gameIntro: `${APP_NAME} es una competencia semanal de looks entre amigas. Cada semana es una pasarela con una o varias categorías, y todo funciona en cuatro pasos:`,
  gameSteps: [
    { title: 'Te registra el jurado', text: 'Solo entra quien el jurado haya invitado con su correo. Sin invitación, no hay corona.' },
    { title: 'Creas tu look', text: 'En el Werk Room subes hasta 4 fotos de tu look para cada categoría y cuentas de qué va.' },
    { title: 'Desfilas y votas', text: 'Cuando se abre la pasarela todas ven los looks. Después eliges tu Top 3 de reinas.' },
    { title: 'Se corona la ganadora', text: 'Se suman los puntos, se revela el Top 3 y la semana pasa al archivo con su ranking final.' },
  ] satisfies HelpFact[],

  rolesTitle: 'Dos tipos de reina',
  roles: [
    { title: 'Concursante', text: 'Sube sus looks, desfila, vota y compite por la corona de la semana.' },
    { title: 'Jurado', text: 'Gestiona semanas, categorías, grupos y participantes, sube el vídeo de introducción de la pasarela (vertical 9:16, MP4, máximo 50 MB; reemplaza al anterior) cambia la etapa de cada pasarela (para pasar del Werk Room a la Pasarela, cada grupo de una categoría grupal necesita al menos una foto) y descarga un ZIP de la semana (datos y fotos) para escribir los comentarios con una IA. También desfila, pero sus looks no se votan ni puntúan. Sus looks y presentaciones, igual que los de las invitadas especiales, están en «Mis looks». En las categorías grupales vota qué grupo gana.' },
  ] satisfies HelpFact[],

  stagesTitle: 'Las etapas de cada semana',
  stagesIntro: 'Cada semana avanza por seis etapas, siempre en este orden. Quien cambia de etapa es el jurado, y verás el cambio en pantalla al instante.',
  stages: [
    {
      icon: '✂️',
      title: 'Borrador',
      who: 'Solo el jurado',
      roles: ['jurado'],
      text: 'El jurado prepara la semana, sus categorías y los looks. Las concursantes todavía no ven nada: es el backstage.',
    },
    {
      icon: '🧵',
      title: 'Werk Room',
      who: 'Concursantes',
      roles: ['concursante', 'invitado'],
      text: 'Hora de coser, pegar y brillar. Sube hasta 4 fotos de tu look y escribe tu presentación. La Foto 1 es obligatoria y puedes cambiarlo todo mientras el Werk Room siga abierto. Aquí solo ves tus propios looks (y, en una categoría grupal, los de tu grupo): ¡el misterio es parte del show! En la página de inicio, una cuenta atrás te dice cuánto falta para que abra la pasarela.',
    },
    {
      icon: '👠',
      title: 'Pasarela',
      who: 'Todas',
      roles: ['concursante', 'jurado', 'invitado'],
      text: 'Se abre el telón: todos los looks son públicos y puedes verlos en grande. Tus looks quedan congelados, así que ya no se pueden cambiar. Admira, aplaude y ve pensando tu Top 3. Si eres concursante, pulsa «A desfilar» en la página de inicio para compartir tu look (fotos y presentación) en el grupo de WhatsApp.',
    },
    {
      icon: '🗳️',
      title: 'Votación',
      who: 'Todas',
      roles: ['concursante', 'jurado', 'invitado'],
      text: 'Eliges tu Top 3 de reinas (no de looks sueltos): la primera que toques será tu Top 1. No puedes votarte a ti misma, y puedes cambiar tu voto las veces que quieras mientras la votación siga abierta. Los votos de cada persona son secretos hasta que la semana se cierra. Si hay una categoría grupal, también se vota por grupos: lo cuenta la sección «Categorías grupales».',
    },
    {
      icon: '🎭',
      title: 'Revelación',
      who: 'Todas',
      roles: ['concursante', 'jurado', 'invitado'],
      text: 'Se cierran las urnas y se revela el Top 3 de la semana con todo el dramatismo que merece. Si hay una categoría grupal, primero se revela la banda ganadora y, cuando el jurado lo decide, el Top 3. Los votos individuales siguen siendo privados hasta que se cierra la semana.',
    },
    {
      icon: '👑',
      title: 'Cerrada',
      who: 'Todas',
      roles: ['concursante', 'jurado', 'invitado'],
      text: 'La semana pasa al archivo. Aparece el ranking completo con la ganadora coronada, y tus puntos y tu puesto se guardan en «Mis looks». Con el botón «Resultados» de la página de la semana ves a quién votó cada persona en su Top 3 (los votos de las invitadas especiales siguen siendo anónimos). En una semana con categoría grupal, ese botón es «Ver resultados» y muestra la clasificación.',
    },
  ] satisfies HelpStage[],

  groupTitle: 'Categorías grupales',
  groupIntro: 'A veces una categoría se juega por equipos: las reinas se reparten en dos grupos que compiten entre sí. Esto es lo que cambia:',
  group: [
    { title: 'Tu grupo', text: 'El jurado te asigna a uno de los dos grupos. En el Werk Room verás la insignia «Categoría grupal» y el nombre de tu grupo, y con «Ver grupo» abres su ficha.' },
    { title: 'Las fotos del grupo', text: 'Entre todas las integrantes pueden subir hasta 4 fotos apaisadas (16:9 o 5:3) del grupo. Se muestran juntas para ver el conjunto y cualquiera de tu grupo puede cambiarlas mientras el Werk Room siga abierto.' },
    { title: 'Tus compañeras', text: 'Debajo de tu look, en «El resto de reinas de la banda», ves los looks de tus compañeras de grupo. Los del otro grupo no los verás hasta que empiece la votación.' },
    { title: 'Tu votación, paso a paso', text: 'En la página de votación un indicador de pasos te guía: el jurado vota la mejor banda, ordena a las reinas y elige su Top 3 (que se propone con las tres primeras de su orden); las concursantes ordenan a la banda rival y eligen su Top 3. Si la categoría grupal es la única de la semana, el jurado no elige Top 3: le basta con votar la banda y ordenar a las reinas. Puedes ir a cualquier paso en cualquier orden: una marca ✓ indica los que ya has guardado.' },
    { title: 'Fase 1: el voto del jurado', text: 'El jurado vota qué banda ha trabajado mejor. Si hay empate, las dos bandas ganan. Cada integrante de la banda ganadora recibe un regalo en su nota de bandas.' },
    { title: 'Fase 2: tu voto cruzado', text: 'Ordenas a todas las reinas de la banda rival, de mejor a peor. El voto debe estar completo y puedes cambiarlo mientras la votación siga abierta. No puedes votar a tu propia banda.' },
    { title: 'Fase 3: la pasarela del jurado', text: 'Cada juez ordena a todas las concursantes según su look individual. Se hace la media de sus notas.' },
    { title: 'El Top 3 también cuenta', text: 'En una semana con categoría grupal hay una sola clasificación: la nota final es la mitad de la nota de bandas (fases 2 y 3 más el regalo) y la otra mitad la nota del Top 3 de la semana. Esa nota es los puntos de la reina entre el máximo posible, contando solo las papeletas que se han entregado.' },
    { title: 'La revelación', text: 'En la revelación primero aparece la banda ganadora, con su efecto de ruleta y confeti. Después una persona del jurado pulsa «Revelar el Top 3 de la semana» y se revela a la ganadora para todas a la vez. El podio sale de la misma clasificación que la tabla de resultados. Hasta ese momento nadie puede ver el Top 3, ni siquiera mirando otras páginas.' },
    { title: 'Los resultados', text: 'Cuando el jurado revela el Top 3, el botón «Ver resultados» de la página de la semana abre la clasificación final con la nota de cada fase, el regalo, la nota del Top 3 y la nota final de cada reina.' },
  ] satisfies HelpFact[],

  groupHelpLink: 'Ver cómo funciona la votación de las bandas',

  scoringTitle: 'Cómo se cuentan los puntos',
  scoringIntro: 'Cada voto reparte puntos según el lugar en que pongas a cada reina:',
  scoring: [
    { place: 'Top 1', points: '3 puntos' },
    { place: 'Top 2', points: '2 puntos' },
    { place: 'Top 3', points: '1 punto' },
  ],
  scoringTies: '¿Empate? Gana la reina con más Top 1; si sigue el empate, la que tenga más Top 2; y si aún así no hay quién desempate, la que se registró primero. Sí, la antigüedad cuenta. En una semana con categoría grupal el Top 3 es solo una parte de la nota: se combina con la votación de las bandas.',

  securityTitle: 'Seguridad: aquí no entra cualquiera',
  securityIntro: 'Esta es una fiesta con lista de invitadas. Si tu correo no está en la lista, la puerta no se abre, y no es solo un letrero en la pantalla: el bloqueo vive en la base de datos.',
  security: [
    {
      title: 'Lista de invitadas',
      text: 'El jurado registra a cada participante con su correo. Esa lista es la única forma de entrar.',
    },
    {
      title: 'Correo verificado',
      text: 'Entras con Google o Microsoft, y solo aceptamos correos que el proveedor haya verificado. Nadie puede hacerse pasar por otra persona (ni por el jurado) con un correo ajeno.',
    },
    {
      title: 'Sin invitación no se crea la cuenta',
      text: 'Si inicias sesión con un correo que nadie registró, el registro se rechaza antes de crear la cuenta. No queda ningún acceso a medio hacer ni una cuenta «fantasma» esperando.',
    },
    {
      title: 'Una cuenta por reina',
      text: 'Cada invitación se vincula a un único inicio de sesión. Un correo ya reclamado no puede usarse para entrar como otra persona.',
    },
    {
      title: 'Sin sesión, sin pasarela',
      text: 'Todas las páginas piden sesión y te mandan al inicio de sesión si no la tienes. Además, la base de datos solo responde a perfiles registrados, así que aunque alguien lo intentara a mano, no vería datos.',
    },
    {
      title: 'Cada reina en su carril',
      text: 'Solo puedes tocar tus propios looks y tu propio voto, y solo en la etapa que corresponde. No puedes votarte a ti misma, y los votos de las demás son secretos.',
    },
  ] satisfies HelpFact[],

  blockedTitle: '¿Qué pasa si no estoy en la lista?',
  blockedText: 'Verás el mensaje «Tu correo no está en la lista de participantes» y volverás al inicio de sesión, sin acceso a nada. Prueba con el correo con el que te registraron o pídele a una persona del jurado que te añada.',

  installTitle: 'Instala la app en tu móvil',
  installIntro: `${APP_NAME} funciona como una app: ponla en la pantalla de inicio de tu móvil y ábrela con un toque, sin barra del navegador. No ocupa casi espacio y no hace falta ninguna tienda de aplicaciones.`,
  install: [
    { title: 'En Android', text: 'Abre el menú (las tres rayas de arriba a la izquierda) y pulsa «Instalar app». Si no aparece, usa el menú de Chrome (los tres puntos) y elige «Instalar aplicación» o «Añadir a la pantalla de inicio».' },
    { title: 'En iPhone y iPad', text: 'Abre el menú y pulsa «Instalar app» para ver los pasos, o hazlo a mano: pulsa «Compartir» (el cuadrado con una flecha), elige «Añadir a pantalla de inicio» y pulsa «Añadir». Funciona desde Safari; si no ves la opción, abre la página en Safari.' },
    { title: 'Siempre al día', text: 'La app se actualiza sola cuando hay una versión nueva. Necesita conexión a internet para mostrar los looks y guardar tus votos: sin conexión verás un aviso para reintentar.' },
  ] satisfies HelpFact[],
  installInApp: 'Si ya la tienes instalada, no verás la opción «Instalar app».',

  faqTitle: 'Dudas frecuentes',
  faq: [
    { title: 'Entré con otro correo y me rechazó. ¿Qué hago?', text: 'Inicia sesión con el mismo correo con el que te registró el jurado. Si quieres usar otro, pídele que cambie tu correo en Participantes.' },
    { title: 'Mi sesión se queda en «Confirmando sesión…»', text: 'Suele pasar en el navegador interno de apps como Instagram o WhatsApp. Abre el enlace en Safari o Chrome e inténtalo de nuevo.' },
    { title: '¿Cómo comparto mi look en el grupo de WhatsApp?', text: 'Cuando la semana esté en la pasarela, pulsa «A desfilar» en la página de inicio desde tu móvil. Se abre el menú de compartir con todas las fotos de tu look y tu presentación: elige WhatsApp y el grupo. En el ordenador solo se copia el texto, así que usa el móvil para enviar las fotos. Si tu categoría es grupal, también verás «A desfilar con mi banda», que comparte del mismo modo la presentación y las fotos de tu banda (el jurado no lo tiene). Si hay varias fotos, WhatsApp puede mostrar la presentación solo en la primera, o no mostrarla.' },
    { title: 'Mi foto de grupo no se sube', text: 'Las fotos de grupo deben ser apaisadas, en formato 16:9 o 5:3. Recórtala con el editor de tu móvil y vuelve a subirla.' },
    { title: '¿Dónde están «Mi perfil», «Mis looks» y «Salir»?', text: 'En el móvil, pulsa tu foto de arriba a la derecha: se abre un panel con tu nombre, «Mi perfil», «Mis looks» y «Salir». Las demás páginas (semanas pasadas, ayuda, novedades y las del jurado) el cambio de tema y «Instalar app» (si la app aún no está instalada) están en el botón de las tres rayas de arriba a la izquierda. En pantallas grandes todo está en el menú con tu nombre, arriba a la derecha.' },
    { title: '¿Puedo cambiar mi nombre drag?', text: 'Claro, en «Mi perfil». Es el nombre que verán todas en la pasarela y en el Top 3.' },
    { title: '¿Por qué no veo la semana nueva?', text: 'Porque sigue en borrador. Cuando el jurado la pase al Werk Room, aparecerá.' },
  ] satisfies HelpFact[],

  backHome: 'Volver a la pasarela',
}
