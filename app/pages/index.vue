<script setup lang="ts">
import type { Tables } from '~/types/database.types'
import type { JuryMember } from '~/components/JuryLooks.vue'
import type { SharePhoto } from '~/composables/useShareLooks'
import type { RevealBand } from '~/composables/useRunwayResults'
import type { SummaryBand, SummaryQueen } from '~/components/RunwayVotingSummary.vue'

interface OpenRunway extends Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status' | 'top_three_revealed'> {
  categories: Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text' | 'kind'>[]
}

interface MyLook {
  intro: string | null
  categoryTitle: string
  photos: SharePhoto[]
}

interface MyGroup {
  name: string
  intro: string | null
  photos: SharePhoto[]
}

interface HomeData {
  runways: OpenRunway[]
  /** Voting runways where the current participant already cast a ballot */
  votedRunwayIds: string[]
  /** Top 3 queens of the runway being revealed (empty when there is none or the jury has not revealed it yet) */
  topThree: RunwayQueen[]
  /** Bands of the group category of the runway being revealed, with the winner (empty when there is none) */
  bands: RevealBand[]
  /** Judges' looks of the week's runway while it is on the runway (empty otherwise) */
  jury: JuryMember[]
  /** The signed-in queen's or jury member's own look(s) of the week's runway while it is on the runway (empty otherwise) */
  myLooks: MyLook[]
  /** The signed-in queen's own group (name, intro, photos) of the week's runway while it is on the runway (null otherwise) */
  myGroup: MyGroup | null
  /** Most recent closed runway with its winner (null when none has closed yet) */
  previousWeek: { runway: OpenRunway, winner: RunwayQueen | null } | null
  /** Bands and queens of the week's runway while it is in voting, for the animated summary */
  votingSummary: { bands: SummaryBand[], queens: SummaryQueen[] }
}

interface RunwayAction {
  to: string
  label: string
}

const RUNWAY_COLUMNS ='id, week_number, runway_date, status, top_three_revealed, categories(id, title, intro_text, kind)'

const supabase = useSupabaseClient()
const { loadTopThree, loadWinners, loadBandResult } = useRunwayResults()
const { participant } = useCurrentParticipant()

/** Categories whose sub-category the signed-in queen has not picked yet: until she does, the Werk Room card only shows the picker */
const pendingSubcategoryIds = ref<string[]>([])
const mustPickSubcategory = computed(() => pendingSubcategoryIds.value.length > 0)
function onSubcategoryPending(categoryId: string, pending: boolean): void {
  const others = pendingSubcategoryIds.value.filter(id => id !== categoryId)
  pendingSubcategoryIds.value = pending ? [...others, categoryId] : others
}

// RLS already hides drafts from contestants
const { data, error, refresh } = await useAsyncData('home', async (): Promise<HomeData> => {
  const { data: runways, error } = await supabase
    .from('runways')
    .select(RUNWAY_COLUMNS)
    .in('status', ['werk_room', 'runway', 'voting', 'reveal'])
    .order('week_number', { ascending: false })
    .order('created_at', { referencedTable: 'categories', ascending: true })

  if (error) throw error

  const revealRunway = runways.find(runway => runway.status === 'reveal')
  const revealGroup = revealRunway?.categories.find(category => category.kind === 'group')
  const featured = pickWeekRunway(runways)
  const [topThree, bands, votedRunwayIds, jury, myLooks, myGroup, previousWeek, votingSummary] = await Promise.all([
    // The database returns nothing until the jury reveals the Top 3 of a runway with a group category
    revealRunway ? loadTopThree(revealRunway.id) : [],
    revealGroup ? loadBandResult(revealGroup.id) : [],
    loadVotedRunwayIds(runways),
    featured?.status === 'runway' ? loadJury(featured) : [],
    featured?.status === 'runway' ? loadMyLooks(featured) : [],
    featured?.status === 'runway' ? loadMyGroup(featured) : null,
    // Last week only fills the page while this one has not started (Werk Room) or there is none: from the runway on it is noise
    !featured || featured.status === 'werk_room' ? loadPreviousWeek() : null,
    // Loaded together with the status, so the summary has its data the moment the runway opens for voting
    featured?.status === 'voting' ? loadVotingSummary(featured) : { bands: [], queens: [] },
  ])

  return { runways, votedRunwayIds, topThree, bands, jury, myLooks, myGroup, previousWeek, votingSummary }
})

/** Looks are readable from voting on (RLS), and so are the photos of the bands */
async function loadVotingSummary(runway: OpenRunway): Promise<HomeData['votingSummary']> {
  const groupCategoryIds = runway.categories.filter(category => category.kind === 'group').map(category => category.id)
  const individualCategories = runway.categories.filter(category => category.kind === 'individual')

  const [looks, groups, photos] = await Promise.all([
    supabase
      .from('looks')
      .select('category_id, image_url, participant:participants!looks_participant_id_fkey(id, name, drag_name), category:categories!looks_category_id_fkey!inner(runway_id)')
      .eq('category.runway_id', runway.id)
      .order('created_at', { ascending: true }),
    groupCategoryIds.length
      ? supabase.from('category_groups').select('id, name').in('category_id', groupCategoryIds).order('position')
      : { data: [], error: null },
    groupCategoryIds.length
      ? supabase.from('category_group_photos').select('group_id, image_url, image2_url, image3_url, image4_url').in('category_id', groupCategoryIds)
      : { data: [], error: null },
  ])
  if (looks.error) throw looks.error
  if (groups.error) throw groups.error
  if (photos.error) throw photos.error

  // One photo per band and queen: the first one. All the looks are on the vote page and the runway.
  const bands = groups.data.flatMap((group) => {
    const url = groupPhotoUrls(photos.data.find(row => row.group_id === group.id))[0]
    return url ? [{ id: group.id, name: group.name, url }] : []
  })

  // Queens in the order of their first look (her first look is the one shown); the category only matters
  // when there is more than one
  const titleByCategory = new Map(runway.categories.map(category => [category.id, category.title]))
  const byQueen = new Map<string, SummaryQueen>()
  for (const look of looks.data) {
    if (byQueen.has(look.participant.id)) continue
    byQueen.set(look.participant.id, {
      id: look.participant.id,
      name: look.participant.drag_name ?? look.participant.name,
      categoryTitle: individualCategories.length > 1 ? titleByCategory.get(look.category_id) ?? null : null,
      url: look.image_url,
    })
  }

  return { bands, queens: [...byQueen.values()] }
}

async function loadMyLooks(runway: OpenRunway): Promise<MyLook[]> {
  const categoryIds = runway.categories.map(category => category.id)
  if (!categoryIds.length || !participant.value) return []

  // The jury (judges and special guests) keeps its looks in jury_looks, queens in looks
  const table = participant.value.role === 'concursante' ? 'looks' : 'jury_looks'
  const { data: rows, error: looksError } = await supabase
    .from(table)
    .select('category_id, intro, image_url, image2_url, image3_url, image4_url')
    .eq('participant_id', participant.value.id)
    .in('category_id', categoryIds)
  if (looksError) throw looksError

  const titleByCategory = new Map(runway.categories.map(category => [category.id, category.title]))
  return rows.map(row => ({
    intro: row.intro,
    categoryTitle: titleByCategory.get(row.category_id) ?? '',
    photos: lookPhotos(row),
  }))
}

// Only queens share their group: the jury (judges and special guests) is not in any group
async function loadMyGroup(runway: OpenRunway): Promise<MyGroup | null> {
  const category = runway.categories.find(candidate => candidate.kind === 'group')
  if (!category || participant.value?.role !== 'concursante') return null

  const { data: member, error: memberError } = await supabase
    .from('category_group_members')
    .select('group_id')
    .eq('category_id', category.id)
    .eq('participant_id', participant.value.id)
    .maybeSingle()
  if (memberError) throw memberError
  if (!member) return null

  // Members always see their own group's intro and photos
  const [group, photos] = await Promise.all([
    supabase.from('category_groups').select('name, intro').eq('id', member.group_id).single(),
    supabase.from('category_group_photos').select('image_url, image2_url, image3_url, image4_url').eq('group_id', member.group_id).maybeSingle(),
  ])
  if (group.error) throw group.error
  if (photos.error) throw photos.error

  const shared = GROUP_PHOTO_SLOTS.flatMap(slot => (photos.data?.[slot.key] ? [{ url: photos.data[slot.key]!, label: slot.label }] : []))
  if (!shared.length && !group.data.intro) return null
  return { name: group.data.name, intro: group.data.intro, photos: shared }
}

async function loadPreviousWeek(): Promise<HomeData['previousWeek']> {
  const { data: closed, error: closedError } = await supabase
    .from('runways')
    .select(RUNWAY_COLUMNS)
    .eq('status', 'closed')
    .order('week_number', { ascending: false })
    .order('created_at', { referencedTable: 'categories', ascending: true })
    .limit(1)
  if (closedError) throw closedError

  const runway = closed[0]
  if (!runway) return null
  const winners = await loadWinners([runway.id])
  return { runway, winner: winners[runway.id] ?? null }
}

// Status changes (voting -> reveal -> closed) reach everyone without a page refresh
useRunwaysRealtime(refresh)

async function loadJury(runway: OpenRunway): Promise<JuryMember[]> {
  const categoryIds = runway.categories.map(category => category.id)
  if (!categoryIds.length) return []

  const { data: rows, error: juryError } = await supabase
    .from('jury_looks')
    .select('id, category_id, image_url, image2_url, image3_url, image4_url, intro, participant:participants!jury_looks_participant_id_fkey(name, drag_name)')
    .in('category_id', categoryIds)
    .order('created_at', { ascending: true })
  if (juryError) throw juryError

  const titleByCategory = new Map(runway.categories.map(category => [category.id, category.title]))
  return rows.map(row => ({
    id: row.id,
    photos: lookPhotos(row),
    intro: row.intro,
    name: row.participant.drag_name ?? row.participant.name,
    categoryTitle: runway.categories.length > 1 ? titleByCategory.get(row.category_id) ?? null : null,
  }))
}

async function loadVotedRunwayIds(runways: OpenRunway[]): Promise<string[]> {
  const votingIds = runways.filter(runway => runway.status === 'voting').map(runway => runway.id)
  if (!votingIds.length || !participant.value) return []

  const { data: ballots, error: ballotsError } = await supabase
    .from('votes')
    .select('runway_id')
    .eq('voter_id', participant.value.id)
    .in('runway_id', votingIds)

  if (ballotsError) throw ballotsError
  return ballots.map(ballot => ballot.runway_id)
}

// Several runways can be open at once (last week still voting while the new one opens):
// a runway being revealed takes the stage, otherwise the newest one is the week's runway.
// The rest stay reachable below it.
function pickWeekRunway(runways: OpenRunway[]): OpenRunway | null {
  return runways.find(runway => runway.status === 'reveal') ?? runways[0] ?? null
}
const weekRunway = computed(() => pickWeekRunway(data.value?.runways ?? []))
const otherOpenRunways = computed(() =>
  data.value?.runways.filter(runway => runway.id !== weekRunway.value?.id) ?? [],
)
const revealedTopThree = computed(() => (weekRunway.value?.status === 'reveal' ? data.value?.topThree ?? [] : []))

// --- Staged reveal of a runway with a group category: first the winning band, then (when a judge says so) the Top 3
const hasGroupReveal = computed(() => weekRunway.value?.status === 'reveal' && weekRunway.value.categories.some(category => category.kind === 'group'))
const revealBands = computed(() => (hasGroupReveal.value ? data.value?.bands ?? [] : []))
const inBandStage = computed(() => hasGroupReveal.value && !weekRunway.value?.top_three_revealed)
const bandRevealDone = ref(false)
/** The Top 3 reveal has finished playing: the "Ver la pasarela" button appears */
const topThreeRevealDone = ref(false)
const revealingTopThree = ref(false)
const snackbar = useSnackbar()

// A new band stage (another runway, or a reopened reveal) plays its animation again
watch(() => [weekRunway.value?.id, inBandStage.value], () => { bandRevealDone.value = false })
watch(() => [weekRunway.value?.id, weekRunway.value?.status, revealedTopThree.value.length], () => { topThreeRevealDone.value = false })

// Soft move: when the Top 3 appears above the band, the band slides down to its new place instead of
// jumping there (FLIP: note where it was, then animate from there to where it ended up)
const SLIDE_MS = 800
const bandSection = ref<HTMLElement | null>(null)
let bandTopBefore: number | null = null

watch(inBandStage, (stage, wasStage) => {
  bandTopBefore = wasStage && !stage ? bandSection.value?.getBoundingClientRect().top ?? null : null
}, { flush: 'pre' })

watch(inBandStage, () => {
  const element = bandSection.value
  if (bandTopBefore === null || !element) return
  const distance = bandTopBefore - element.getBoundingClientRect().top
  bandTopBefore = null
  if (!distance || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
  element.animate([{ transform: `translateY(${distance}px)` }, { transform: 'none' }], { duration: SLIDE_MS, easing: 'ease-in-out' })
}, { flush: 'post' })

async function revealTopThree(): Promise<void> {
  if (!weekRunway.value) return
  revealingTopThree.value = true
  const { error: revealFailure } = await supabase.rpc('reveal_runway_top_three', { p_runway_id: weekRunway.value.id })
  revealingTopThree.value = false
  if (revealFailure) {
    snackbar.error(toErrorMessage(revealFailure))
    return
  }
  await refresh()
  snackbar.success('Top 3 revelado.')
}
// Werk Room: counts down to the runway's date
const { remaining: countdownRemaining, units: countdownUnits } = useCountdown(
  () => (weekRunway.value?.status === 'werk_room' ? weekRunway.value.runway_date : null),
)
// Whether the signed-in person already cast a ballot in the week's runway (voting only)
const hasVotedThisWeek = computed(() => !!weekRunway.value && (data.value?.votedRunwayIds.includes(weekRunway.value.id) ?? false))
const runwayJury = computed(() => (weekRunway.value?.status === 'runway' ? data.value?.jury ?? [] : []))

// The queen's own look, ready to paste into the WhatsApp group where everyone comments
const myLooks = computed(() => (weekRunway.value?.status === 'runway' ? data.value?.myLooks ?? [] : []))
const sharePayload = computed(() => ({
  photos: myLooks.value.flatMap(look => look.photos),
  owner: participant.value?.drag_name ?? participant.value?.name ?? '',
  text: myLooks.value
    .map(look => [myLooks.value.length > 1 ? `*${look.categoryTitle}*` : '', look.intro ?? ''].filter(Boolean).join('\n'))
    .filter(Boolean)
    .join('\n\n'),
}))

// The queen's own group, ready to paste into the WhatsApp group like her look
const myGroup = computed(() => (weekRunway.value?.status === 'runway' ? data.value?.myGroup ?? null : null))
const groupSharePayload = computed(() => ({
  photos: myGroup.value?.photos ?? [],
  owner: myGroup.value?.name ?? '',
  text: [myGroup.value ? `*${myGroup.value.name}*` : '', myGroup.value?.intro ?? ''].filter(Boolean).join('\n\n'),
}))

const { sharing, prefetch, share } = useShareLooks()

// Download the images while the page is idle so the share sheet opens right on tap
watch([sharePayload, groupSharePayload], ([look, group]) => {
  if (import.meta.client) prefetch([...look.photos, ...group.photos])
}, { immediate: true })

/** Which button is preparing the share sheet, so only that one shows "Preparando…" */
const sharingTarget = ref<'look' | 'group' | null>(null)
const shareMyLook = () => runShare(sharePayload.value, 'look')
const shareMyGroup = () => runShare(groupSharePayload.value, 'group')

async function runShare(payload: typeof sharePayload.value, target: 'look' | 'group') {
  sharingTarget.value = target
  try {
    const result = await share(payload)
    if (result === 'copied') snackbar.info('Texto copiado. Tu navegador no permite compartir imágenes desde aquí.')
  }
  catch (error) {
    snackbar.error(toErrorMessage(error))
  }
  finally {
    sharingTarget.value = null
  }
}

// Intro video of the runway. It only plays by itself when the status flips from
// werk_room to runway while this screen is open; anyone arriving later gets a button.
// The video is one file overwritten every week in the public 'runway-intro' bucket; the
// week number in the URL keeps a replaced video from being served stale from cache.
const introBucket = useRuntimeConfig().public.runwayIntroBucket
const introVideoSrc = computed(() => {
  const { data } = supabase.storage.from(introBucket).getPublicUrl('intro.mp4')
  return `${data.publicUrl}?v=${weekRunway.value?.week_number ?? 0}`
})
const FADE_OUT_MS = 700
const introOpen = ref(false)
const contentFading = ref(false)
let overlayTimer: ReturnType<typeof setTimeout> | undefined

function playIntro(): void {
  clearTimeout(overlayTimer)
  introOpen.value = true
}

function closeIntro(): void {
  introOpen.value = false
  contentFading.value = false
}

// Animated summary of the week, played when the runway opens for voting (same pattern as the intro)
const votingSummary = computed(() => (weekRunway.value?.status === 'voting' ? data.value?.votingSummary ?? null : null))
const hasVotingSummary = computed(() => !!votingSummary.value && (votingSummary.value.bands.length > 0 || votingSummary.value.queens.length > 0))
const summaryOpen = ref(false)

function playSummary(): void {
  clearTimeout(overlayTimer)
  summaryOpen.value = true
}

function closeSummary(): void {
  summaryOpen.value = false
  contentFading.value = false
}

// Voting ended (or the runway changed) while the summary was open: leave it and show the page again
watch(votingSummary, (summary) => {
  if (!summary && summaryOpen.value) closeSummary()
})

/** Content fades out first, then the overlay comes in over a clean page */
function playAfterFade(play: () => void): void {
  contentFading.value = true
  overlayTimer = setTimeout(play, FADE_OUT_MS)
}

watch(
  () => weekRunway.value && { id: weekRunway.value.id, status: weekRunway.value.status },
  (current, previous) => {
    if (!previous || !current || current.id !== previous.id) return
    if (previous.status === 'werk_room' && current.status === 'runway') playAfterFade(playIntro)
    else if (previous.status === 'runway' && current.status === 'voting' && hasVotingSummary.value) playAfterFade(playSummary)
  },
)

onBeforeUnmount(() => clearTimeout(overlayTimer))

const STATUS_HINTS:Record<OpenRunway['status'], string> = {
  draft: '',
  werk_room: 'Las reinas se preparan en el Werk Room.',
  runway: 'La votación abrirá pronto.',
  voting: '',
  reveal: 'Pronto se revelará el Top 3.',
  closed: '',
}

// The runway stays hidden until voting opens, so only voting runways have an action
function primaryAction(runway: OpenRunway): RunwayAction | null {
  if (runway.status !== 'voting') return null
  const hasVoted = data.value?.votedRunwayIds.includes(runway.id) ?? false
  return { to: `/runways/${runway.id}/vote`, label: hasVoted ? 'Cambiar mi Top 3' : 'Votar a las mejores reinas' }
}
</script>

<template>
  <main class="page" :class="{ 'page--fading': contentFading }">
    <!-- Outside the faded content: teleported so it does not inherit the page's opacity -->
    <Teleport to="body">
      <RunwayIntro v-if="introOpen" :src="introVideoSrc" @close="closeIntro" />
      <RunwayVotingSummary
        v-if="summaryOpen && votingSummary && weekRunway && primaryAction(weekRunway)"
        :week-number="weekRunway.week_number"
        :bands="votingSummary.bands"
        :queens="votingSummary.queens"
        :vote-to="primaryAction(weekRunway)!.to"
        :vote-label="primaryAction(weekRunway)!.label"
        @close="closeSummary"
      />
    </Teleport>

    <AppNav />

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <section v-else-if="weekRunway" class="week-hero" aria-labelledby="week-title">
      <div class="week-hero__head">
        <p class="kicker">
          {{ weekRunway.categories.length > 1 ? 'Categorías de la semana' : 'Categoría de la semana' }}
        </p>
        <!-- The date and time only matter while the countdown runs (Werk Room); after that they are in the past -->
        <p class="kicker week-hero__when">
          Semana {{ weekRunway.week_number }}<template v-if="weekRunway.status === 'werk_room'"> · {{ formatRunwayDate(weekRunway.runway_date) }}</template>
        </p>
        <StatusBadge :status="weekRunway.status" />
      </div>

      <h1 id="week-title" class="display week-hero__title">
        {{ runwayTitle(weekRunway.categories) }}
      </h1>
      <span class="rule" aria-hidden="true" />

      <p v-if="!mustPickSubcategory" class="week-hero__status">
        <!-- While voting, say whether this person already voted -->
        <span
          v-if="weekRunway.status === 'voting'"
          class="badge week-hero__vote-state"
          :class="hasVotedThisWeek ? 'badge--approved' : 'badge--pending'"
        >{{ hasVotedThisWeek ? '✓ Votado' : 'Pendiente' }}</span>
        {{ weekRunway.status === 'voting'
          ? hasVotedThisWeek
            ? 'Ya has votado. Puedes cambiar tu voto mientras la votación siga abierta.'
            : '¡La votación está abierta! Elige tu Top 3 de reinas de la semana.'
          : weekRunway.status === 'reveal'
            ? inBandStage
              ? '¡La votación terminó! Primero, la banda ganadora de la semana.'
              : '¡La votación terminó! Estas son las tres mejores reinas de la semana.'
            : weekRunway.status === 'werk_room'
              ? 'Las reinas se están preparando en el Werk Room.'
              : 'Las reinas ya están en la pasarela. La votación abrirá pronto.' }}
      </p>

      <!-- Werk Room: time left until the runway opens (counts down to its date) -->
      <div v-if="countdownRemaining !== null && weekRunway.status === 'werk_room' && !mustPickSubcategory" class="countdown">
        <template v-if="countdownRemaining > 0">
          <p class="kicker">
            La pasarela abre en
          </p>
          <div class="countdown__units" role="timer">
            <div v-for="unit in countdownUnits" :key="unit.label.slice(0, 2)" class="countdown__unit">
              <span class="countdown__tile">{{ unit.value }}</span>
              <span class="countdown__label">{{ unit.label }}</span>
            </div>
          </div>
        </template>
        <p v-else class="countdown__time countdown__time--soon">
          ¡La pasarela está a punto de abrir!
        </p>
      </div>

      <!-- Top 3 of the week. With a group category it only exists after the jury reveals it, and fades in while the band slides down -->
      <TopThreeReveal
        v-if="revealedTopThree.length"
        :key="weekRunway.id"
        class="week-hero__reveal"
        :class="{ 'week-hero__reveal--after-band': hasGroupReveal }"
        :queens="revealedTopThree"
        @done="topThreeRevealDone = true"
      />

      <!-- Winning band: revealed first, then it keeps the full width under the Top 3 -->
      <section
        v-if="hasGroupReveal && revealBands.length"
        ref="bandSection"
        class="week-hero__band"
        :aria-labelledby="inBandStage ? undefined : 'band-winner-title'"
      >
        <h2 v-if="!inBandStage" id="band-winner-title" class="week-hero__band-title">
          {{ revealBands.filter(band => band.place === 1).length > 1 ? 'Bandas ganadoras' : 'Banda ganadora' }}
        </h2>
        <BandReveal
          :key="weekRunway.id"
          class="week-hero__band-reveal"
          :bands="revealBands"
          :animate="inBandStage"
          :compact="!inBandStage"
          @done="bandRevealDone = true"
        />
      </section>

      <!-- Only the jury moves on from the band to the Top 3 -->
      <template v-if="inBandStage">
        <div v-if="participant?.role === 'jurado' && (bandRevealDone || !revealBands.length)" class="actions">
          <button type="button" class="btn btn--primary" :disabled="revealingTopThree" @click="revealTopThree">
            {{ revealingTopThree ? 'Revelando…' : 'Revelar el Top 3 de la semana' }}
          </button>
        </div>
        <p v-else-if="participant?.role !== 'jurado' && (bandRevealDone || !revealBands.length)" class="muted" role="status">
          El jurado revelará enseguida el Top 3 de la semana.
        </p>
      </template>

      <!-- Once the reveal has finished, everyone can go and see the runway (as while voting) -->
      <div v-if="weekRunway.status === 'reveal' && topThreeRevealDone" class="actions">
        <NuxtLink :to="`/runways/${weekRunway.id}`" class="btn btn--primary">
          Ver la pasarela
        </NuxtLink>
      </div>

      <!-- Queens upload their own look while the week is in the Werk Room -->
      <div v-if="weekRunway.status === 'werk_room' && participant?.role === 'concursante' && !mustPickSubcategory" class="actions">
        <NuxtLink :to="`/semana/${weekRunway.week_number}/werk-room`" class="btn btn--primary">
          Ya tienes tu look, súbelo
        </NuxtLink>
      </div>

      <!-- Special guests of the jury upload their own look while the week is in the Werk Room -->
      <div v-if="weekRunway.status === 'werk_room' && participant?.role === 'invitado'" class="actions">
        <NuxtLink :to="`/semana/${weekRunway.week_number}/invitado`" class="btn btn--primary">
          Sube tu look de jurado
        </NuxtLink>
      </div>

      <!-- Queens and the jury (judges and special guests) share their look in the WhatsApp group once the week is on the runway; queens also share their group -->
      <div v-if="myLooks.length || myGroup" class="actions">
        <button v-if="myLooks.length" type="button" class="btn btn--primary" :disabled="sharing" @click="shareMyLook">
          <svg class="btn__icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <circle cx="18" cy="5" r="3" />
            <circle cx="6" cy="12" r="3" />
            <circle cx="18" cy="19" r="3" />
            <path d="m8.6 13.5 6.8 4M15.4 6.5l-6.8 4" />
          </svg>
          {{ sharing && sharingTarget === 'look' ? 'Preparando…' : 'A desfilar' }}
        </button>
        <button v-if="myGroup" type="button" class="btn btn--secondary" :disabled="sharing" @click="shareMyGroup">
          <svg class="btn__icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <circle cx="18" cy="5" r="3" />
            <circle cx="6" cy="12" r="3" />
            <circle cx="18" cy="19" r="3" />
            <path d="m8.6 13.5 6.8 4M15.4 6.5l-6.8 4" />
          </svg>
          {{ sharing && sharingTarget === 'group' ? 'Preparando…' : 'A desfilar con mi banda' }}
        </button>
      </div>

      <div v-if="weekRunway.status === 'runway'" class="actions">
        <button type="button" class="btn btn--secondary" @click="playIntro">
          Ver la intro de la pasarela
        </button>
      </div>

      <div v-if="primaryAction(weekRunway)" class="actions">
        <NuxtLink :to="primaryAction(weekRunway)!.to" class="btn btn--primary">
          {{ primaryAction(weekRunway)!.label }}
        </NuxtLink>
        <NuxtLink :to="`/runways/${weekRunway.id}`" class="btn btn--secondary">
          Ver la pasarela
        </NuxtLink>
        <button v-if="hasVotingSummary" type="button" class="btn btn--secondary" @click="playSummary">
          Ver el resumen de la votación
        </button>
      </div>

      <!-- The challenge text is only useful until the runway opens: from the voting on it is gone.
           After the buttons, so on phones it never pushes them off screen. -->
      <RunwayCategories
        v-if="weekRunway.status === 'werk_room' || weekRunway.status === 'runway'"
        :categories="weekRunway.categories"
      />

      <!-- Sub-categories are picked in the Werk Room, in ranking order (individual categories only) -->
      <template v-if="weekRunway.status === 'werk_room'">
        <CategorySubcategories
          v-for="category in weekRunway.categories.filter(candidate => candidate.kind === 'individual')"
          :key="category.id"
          :category="category"
          :show-title="weekRunway.categories.length > 1"
          @pending="onSubcategoryPending"
        />
      </template>
    </section>

    <section v-else class="week-empty" aria-labelledby="week-empty-title">
      <span class="week-empty__icon" aria-hidden="true">♛</span>
      <h1 id="week-empty-title">
        La pasarela está en pausa
      </h1>
      <p class="lead">
        El jurado está preparando la próxima categoría. ¡Vuelve pronto, reina!
      </p>
    </section>

    <JuryLooks :members="runwayJury" title="El jurado en la pasarela" />

    <section v-if="otherOpenRunways.length" class="section" aria-labelledby="open-title">
      <h2 id="open-title">
        Siguen abiertas
      </h2>
      <ul class="row-list">
        <li v-for="runway in otherOpenRunways" :key="runway.id">
          <NuxtLink v-if="primaryAction(runway)" :to="primaryAction(runway)!.to" class="row row--link">
            <span class="row__main">
              <span class="row__title">Semana {{ runway.week_number }} · {{ runwayTitle(runway.categories) }}</span>
              <span class="muted">{{ primaryAction(runway)!.label }}</span>
            </span>
            <StatusBadge :status="runway.status" />
          </NuxtLink>
          <div v-else class="row">
            <span class="row__main">
              <span class="row__title">Semana {{ runway.week_number }} · {{ runwayTitle(runway.categories) }}</span>
              <span class="muted">{{ STATUS_HINTS[runway.status] }}</span>
            </span>
            <StatusBadge :status="runway.status" />
          </div>
        </li>
      </ul>
    </section>

    <section v-if="data?.previousWeek" class="section" aria-labelledby="previous-title">
      <h2 id="previous-title">
        La semana pasada
      </h2>
      <PastRunwayCard :runway="data.previousWeek.runway" :winner="data.previousWeek.winner" featured />
    </section>

    <NuxtLink to="/runways/past" class="row row--link past-link">
      <span class="row__main">
        <span class="row__title">Semanas pasadas</span>
        <span class="muted">Revive cada pasarela de la temporada.</span>
      </span>
      <span aria-hidden="true">→</span>
    </NuxtLink>
  </main>
</template>

<style scoped lang="scss">
.page {
  transition: opacity 0.7s ease;
}

// Content fades out before the intro's black backdrop comes in
.page--fading {
  opacity: 0;
  pointer-events: none;
}

@media (prefers-reduced-motion: reduce) {
  .page {
    transition-duration: 0.01s;
  }
}

.week-hero {
  position: relative;
  display: grid;
  gap: var(--space-4);
  justify-items: start;
  padding: var(--space-5) var(--space-4);
  overflow: hidden;
  background:
    radial-gradient(28rem 18rem at 100% 0%, color-mix(in srgb, var(--color-primary) 28%, transparent), transparent 70%),
    radial-gradient(22rem 16rem at 0% 100%, color-mix(in srgb, var(--color-accent) 24%, transparent), transparent 70%),
    var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card), var(--glow-primary);

  @media (min-width: 48rem) {
    padding: var(--space-7) var(--space-6);
  }
}

// Werk Room countdown
.countdown {
  display: grid;
  gap: var(--space-1);
  justify-self: stretch;
  padding: var(--space-3) var(--space-4);
  background-color: color-mix(in srgb, var(--color-surface) 70%, transparent);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.countdown__time {
  font-family: var(--font-display);
  font-size: 1.125rem;
  line-height: 1.2;
  color: var(--color-title);
}

// Flip-clock tiles: days, hours, minutes and seconds, each with its label underneath
.countdown__units {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 5rem));
  gap: var(--space-2);
  justify-content: start;
  justify-items: center;
}

.countdown__unit {
  min-width: 0;
  display: grid;
  gap: var(--space-2);
  justify-items: center;
  width: 100%;
  max-width: 5rem;
}

.countdown__tile {
  position: relative;
  display: grid;
  place-items: center;
  width: 100%;
  aspect-ratio: 1;
  font-family: var(--font-display);
  font-size: clamp(1.25rem, 0.9rem + 2.5vw, 2rem);
  font-weight: 700;
  line-height: 1;
  font-variant-numeric: tabular-nums;
  color: var(--color-on-primary);
  background-color: var(--color-primary);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card), var(--glow-primary);

  // The thin line across the middle of the tile, like a flip clock
  &::after {
    content: '';
    position: absolute;
    inset-inline: 0;
    top: 50%;
    height: 1px;
    background-color: color-mix(in srgb, var(--color-on-primary) 35%, transparent);
  }
}

.countdown__label {
  max-width: 100%;
  // Phones: small enough for "SEGUNDOS" to fit under its tile, so all four columns stay the same width
  font-size: 0.625rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  white-space: nowrap;
  color: var(--color-text-muted);

  @media (min-width: 48rem) {
    font-size: 0.75rem;
    letter-spacing: 0.04em;
  }
}

// Kicker, date and status badge: one line each, so nothing wraps awkwardly on a phone
.week-hero__head {
  display: grid;
  gap: var(--space-2);
  justify-items: start;
  justify-self: stretch;
}

.week-hero__when {
  color: var(--color-text-muted);
}

// Wider screens: the kicker on its own line, then the date and the status badge side by side
@media (min-width: 48rem) {
  .week-hero__head {
    grid-template-columns: auto 1fr;
    column-gap: var(--space-3);
    align-items: center;

    > .kicker:first-child {
      grid-column: 1 / -1;
    }
  }
}

.week-hero__title {
  font-size: clamp(2rem, 1.5rem + 2.5vw, 3rem);
  overflow-wrap: anywhere;
}

.week-hero__status {
  font-weight: 600;
}

// "Votado" / "Pendiente" in front of the voting status line
.week-hero__vote-state {
  margin-right: var(--space-1);
  vertical-align: 0.1em;
}

.week-hero__reveal {
  justify-self: stretch;
}

.week-hero__band {
  position: relative;
  z-index: 1;
  display: grid;
  // The space under the title is its margin, not a gap
  gap: 0;
  justify-items: center;
  width: 100%;
}

.week-hero__band-reveal {
  justify-self: stretch;
}

// The Top 3 fades in while the band slides down (the band stays on top of it while it moves)
.week-hero__reveal--after-band {
  animation: reveal-fade-in 0.8s ease-out;
}

@keyframes reveal-fade-in {
  from {
    opacity: 0;
  }

  to {
    opacity: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .week-hero__reveal--after-band {
    animation: none;
  }
}

.week-hero__band-title {
  margin-block: var(--space-6) var(--space-5);
  font-size: 1.25rem;
}

.week-hero .actions {
  width: 100%;

  // Phones and small tablets: one full-width button per row, primary first
  @media (max-width: 47.99rem) {
    flex-direction: column;
    align-items: stretch;

    > .btn {
      flex: none;
      width: 100%;
    }
  }
}

.week-empty {
  display: grid;
  gap: var(--space-3);
  justify-items: center;
  padding: var(--space-7) var(--space-4);
  text-align: center;
  background-color: var(--color-surface);
  border: 2px dashed var(--color-border);
  border-radius: var(--radius-lg);
}

.week-empty__icon {
  display: grid;
  place-items: center;
  width: 4rem;
  height: 4rem;
  font-size: 2rem;
  color: var(--color-title);
  background-color: color-mix(in srgb, var(--color-highlight) 30%, var(--color-surface));
  border-radius: var(--radius-pill);
  box-shadow: var(--glow-accent);
}

.week-empty .lead {
  max-width: 28rem;
}

.past-link .row__title {
  font-size: 1.125rem;
}
</style>
