<script setup lang="ts">
import type { Tables } from '~/types/database.types'

type Runway = Pick<Tables<'runways'>, 'id' | 'week_number' | 'runway_date' | 'status'>
type Category = Pick<Tables<'categories'>, 'id' | 'title' | 'intro_text' | 'kind'>
type MyLook = Pick<Tables<'looks'>, 'id' | 'category_id' | 'participant_id' | 'intro'> & LookImages

interface TeamMember {
  id: string
  name: string
  avatar: string | null
  isMe: boolean
  /** Null while the queen has not uploaded her look yet */
  look: (Pick<Tables<'looks'>, 'id' | 'intro'> & LookImages) | null
}

/** The signed-in queen's group in a group category, with every member (herself included) */
interface Team {
  groupId: string
  name: string
  /** The group's landscape photos, or null while none has been uploaded */
  photos: GroupPhotos | null
  members: TeamMember[]
}

interface WerkRoom {
  runway: Runway
  categories: Category[]
  looks: MyLook[]
  /** Keyed by category id; only group categories where the queen has a group */
  teams: Record<string, Team>
}

const route = useRoute()
const supabase = useSupabaseClient()
const { participant } = useCurrentParticipant()

const weekNumber = Number(route.params.week)

/** RLS only shows a queen the members and looks of her own group while the Werk Room is open */
async function loadTeams(participantId: string, groupCategoryIds: string[]): Promise<Record<string, Team>> {
  if (!groupCategoryIds.length) return {}

  const [members, groups, looks, groupPhotos] = await Promise.all([
    supabase
      .from('category_group_members')
      .select('category_id, group_id, participant_id, participant:participants!category_group_members_participant_id_fkey(name, drag_name, avatar_url)')
      .in('category_id', groupCategoryIds),
    supabase.from('category_groups').select('id, name').in('category_id', groupCategoryIds),
    supabase
      .from('looks')
      .select('id, category_id, participant_id, image_url, image2_url, image3_url, image4_url, intro')
      .in('category_id', groupCategoryIds),
    supabase.from('category_group_photos').select('group_id, category_id, image_url, image2_url, image3_url, image4_url').in('category_id', groupCategoryIds),
  ])
  if (members.error) throw members.error
  if (groups.error) throw groups.error
  if (looks.error) throw looks.error
  if (groupPhotos.error) throw groupPhotos.error

  const teams: Record<string, Team> = {}
  for (const mine of members.data.filter(member => member.participant_id === participantId)) {
    const group = groups.data.find(candidate => candidate.id === mine.group_id)
    if (!group) continue
    teams[mine.category_id] = {
      groupId: group.id,
      name: group.name,
      photos: groupPhotos.data.find(photos => photos.group_id === group.id) ?? null,
      members: members.data
        .filter(member => member.group_id === mine.group_id)
        .map(member => ({
          id: member.participant_id,
          name: member.participant.drag_name ?? member.participant.name,
          avatar: member.participant.avatar_url,
          isMe: member.participant_id === participantId,
          look: looks.data.find(look => look.category_id === mine.category_id && look.participant_id === member.participant_id) ?? null,
        }))
        .sort((a, b) => Number(b.isMe) - Number(a.isMe) || a.name.localeCompare(b.name, 'es')),
    }
  }
  return teams
}

// RLS hides draft runways, so a week that does not exist or is not in the Werk Room looks the same: closed
const { data, error, refresh } = await useAsyncData(`werk-room-${route.params.week}`, async (): Promise<WerkRoom | null> => {
  if (!Number.isInteger(weekNumber) || weekNumber < 1) return null

  const runway = await supabase
    .from('runways')
    .select('id, week_number, runway_date, status')
    .eq('week_number', weekNumber)
    .maybeSingle()
  if (runway.error) throw runway.error
  if (runway.data?.status !== 'werk_room') return null

  const categories = await supabase
    .from('categories')
    .select('id, title, intro_text, kind')
    .eq('runway_id', runway.data.id)
    .order('created_at', { ascending: true })
  if (categories.error) throw categories.error

  const participantId = participant.value?.id
  const categoryIds = categories.data.map(category => category.id)
  if (!participantId || !categoryIds.length) return { runway: runway.data, categories: categories.data, looks: [], teams: {} }

  const looks = await supabase
    .from('looks')
    .select('id, category_id, participant_id, image_url, image2_url, image3_url, image4_url, intro')
    .eq('participant_id', participantId)
    .in('category_id', categoryIds)
  if (looks.error) throw looks.error

  return {
    runway: runway.data,
    categories: categories.data,
    looks: looks.data,
    teams: await loadTeams(participantId, categories.data.filter(category => category.kind === 'group').map(category => category.id)),
  }
})

const isOpen = computed(() => data.value !== null && data.value !== undefined)

// Not an error page, but the response still says "too early" (429) for crawlers and monitors
if (!error.value && !isOpen.value && import.meta.server) {
  setResponseStatus(useRequestEvent()!, 429, 'Too Many Requests')
}

useHead({ title: isOpen.value ? `Werk Room · Semana ${weekNumber}` : 'Werk Room cerrado' })
useSeoMeta({ robots: 'noindex' })

const viewingTeamId = ref<string | null>(null)
const viewingTeam = computed(() => {
  const categoryId = viewingTeamId.value
  const team = categoryId ? data.value?.teams[categoryId] : undefined
  return categoryId && team ? { categoryId, team } : null
})

const isContestant = computed(() => participant.value?.role === 'concursante')
const lookByCategory = computed(() => new Map(data.value?.looks.map(look => [look.category_id, look])))
const multipleCategories = computed(() => (data.value?.categories.length ?? 0) > 1)
</script>

<template>
  <main class="page">
    <AppNav />

    <p v-if="error" class="form-error" role="alert">
      {{ toErrorMessage(error) }}
    </p>

    <template v-else-if="data">
      <AppBreadcrumb
        :items="[
          { label: 'Inicio', to: '/' },
          { label: `Semana ${data.runway.week_number}` },
          { label: 'Werk Room' },
        ]"
      />

      <!-- Neon sign; the word is the whole message, so screen readers get the page title instead -->
      <div class="werk-sign" aria-hidden="true">
        <span class="werk-sign__text">WERK</span>
      </div>

      <header class="page-header">
        <div class="page-header__titles">
          <p class="kicker">
            Semana {{ data.runway.week_number }} · {{ formatRunwayDate(data.runway.runway_date) }}
          </p>
          <h1>Tu look para {{ runwayTitle(data.categories) }}</h1>
        </div>
      </header>

      <p v-if="!isContestant" class="hint">
        Esta zona es para las concursantes. Los looks de todas se gestionan desde el
        <NuxtLink to="/admin" class="link">panel del jurado</NuxtLink>.
      </p>
      <p v-else-if="!data.categories.length" class="empty">
        Esta semana aún no tiene categorías. ¡Vuelve pronto, reina!
      </p>
      <template v-else>
        <p class="hint">
          Sube hasta 4 fotos de tu look (frente, espalda, reveal y una extra) y cuéntanos de qué va.
          La foto de frente es obligatoria. Puedes cambiarlo todo mientras el Werk Room siga abierto.
        </p>
        <ul class="row-list">
          <template v-for="category in data.categories" :key="category.id">
            <li v-if="category.kind === 'group'" class="team__notice">
              <span class="badge">Categoría grupal</span>
              <span v-if="data.teams[category.id]" class="team__text">
                «{{ category.title }}»: compites con el grupo <strong>{{ data.teams[category.id]!.name }}</strong>.
              </span>
              <span v-else class="team__text">
                «{{ category.title }}»: el jurado aún no te ha asignado a un grupo.
              </span>
              <button v-if="data.teams[category.id]" type="button" class="btn btn--secondary btn--small" @click="viewingTeamId = category.id">
                Ver grupo
              </button>
            </li>
            <LookEditRow
              :category-id="category.id"
              :contestant="participant!"
              :look="lookByCategory.get(category.id) ?? null"
              :title="multipleCategories ? category.title : undefined"
              editable
              @changed="refresh()"
            />
          </template>
        </ul>

        <AppModal wide :open="viewingTeam !== null" :title="viewingTeam ? `Grupo ${viewingTeam.team.name}` : ''" @close="viewingTeamId = null">
          <section v-if="viewingTeam" class="team__photos" aria-labelledby="team-photos-title">
            <h3 id="team-photos-title">
              Fotos del grupo
            </h3>
            <GroupPhotosEditor
              :category-id="viewingTeam.categoryId"
              :group-id="viewingTeam.team.groupId"
              :group-name="viewingTeam.team.name"
              :photos="viewingTeam.team.photos"
              display="gallery"
              editable
              @changed="refresh()"
            />
          </section>

          <ul v-if="viewingTeam" class="team__members">
            <li v-for="member in viewingTeam.team.members" :key="member.id" class="team__member">
              <div class="team__who">
                <span class="avatar team__avatar">
                  <img v-if="member.avatar" :src="member.avatar" alt="" class="avatar__img">
                  <span v-else class="avatar__initial" aria-hidden="true">{{ member.name.charAt(0).toUpperCase() }}</span>
                </span>
                <span class="team__name">{{ member.name }}<template v-if="member.isMe"> (tú)</template></span>
              </div>
              <LookGallery
                v-if="member.look"
                class="team__gallery"
                :title="member.name"
                :photos="lookPhotos(member.look)"
                :intro="member.look.intro"
              />
              <p v-else class="hint">
                {{ member.isMe ? 'Aún no has subido tu look.' : 'Aún no ha subido su look.' }}
              </p>
            </li>
          </ul>
        </AppModal>
      </template>
    </template>

    <section v-else class="week-empty" aria-labelledby="closed-title">
      <span class="week-empty__icon" aria-hidden="true">✋</span>
      <h1 id="closed-title">
        ¡¿Dónde crees que vas, reina?!
      </h1>
      <p class="lead">
        ¡El Werk Room todavía no está abierto!
      </p>
      <NuxtLink to="/" class="btn btn--primary">
        Volver a la pasarela
      </NuxtLink>
    </section>
  </main>
</template>

<style scoped lang="scss">
.team__photos {
  display: grid;
  gap: var(--space-2);
}

.team__text {
  flex: 1 1 12rem;
}

.team__members {
  display: grid;
  gap: var(--space-4);
  padding: 0;
  margin: 0;
  list-style: none;
}

.team__member {
  display: grid;
  gap: var(--space-2);
}

.team__who {
  display: flex;
  gap: var(--space-3);
  align-items: center;
  font-weight: 600;
}

.team__avatar .avatar__initial {
  font-size: 1rem;
}

// Several galleries share the modal, so their photos are shorter than in the single-look dialog
.team__gallery :deep(.look-gallery__slide img) {
  max-height: 45dvh;
}

.team__notice {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  align-items: center;
  color: var(--color-text-muted);
  list-style: none;
}

// Pink neon sign on a dark curtain, built from the theme's primary color
.werk-sign {
  display: grid;
  place-items: center;
  padding: var(--space-6) var(--space-4);
  overflow: hidden;
  background:
    repeating-linear-gradient(
      90deg,
      color-mix(in srgb, var(--color-primary) 22%, black) 0 0.75rem,
      color-mix(in srgb, var(--color-primary) 10%, black) 0.75rem 1.5rem
    );
  border-radius: var(--radius-lg);
  box-shadow: inset 0 0 4rem black;
}

.werk-sign__text {
  --neon: var(--color-primary);
  --core: color-mix(in srgb, var(--color-primary) 25%, white);

  font-family: var(--font-body);
  font-size: clamp(3rem, 2rem + 8vw, 6rem);
  font-weight: 500;
  line-height: 1;
  letter-spacing: 0.12em;
  // The trailing letter-spacing would push the word off-center
  padding-left: 0.12em;
  color: var(--core);
  text-shadow:
    0 0 0.05em var(--core),
    0 0 0.12em var(--neon),
    0 0 0.3em var(--neon),
    0 0 0.6em var(--neon),
    0 0 1em var(--neon);

  @media (prefers-reduced-motion: no-preference) {
    animation: neon-flicker 5s infinite;
  }
}

@keyframes neon-flicker {
  0%, 18%, 22%, 62%, 64%, 100% {
    opacity: 1;
  }

  20%, 63% {
    opacity: 0.75;
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
  background-color: color-mix(in srgb, var(--color-highlight) 30%, var(--color-surface));
  border-radius: var(--radius-pill);
  box-shadow: var(--glow-accent);
}

.week-empty .lead {
  max-width: 28rem;
}
</style>
