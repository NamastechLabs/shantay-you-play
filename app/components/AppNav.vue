<script setup lang="ts">
const supabase = useSupabaseClient()
const { participant, isJurado, clear } = useCurrentParticipant()

const menuOpen = ref(false)
/** Phones: the app menu (burger, left) and the user menu (avatar, right) are two panels */
const appDrawerOpen = ref(false)
const userDrawerOpen = ref(false)
const menuId = useId()
const menuRoot = ref<HTMLElement | null>(null)
const trigger = ref<HTMLButtonElement | null>(null)

const { canInstall, install } = useInstallApp()

const displayName = computed(() => participant.value?.drag_name ?? participant.value?.name ?? '')

function closeMenu(options: { focusTrigger?: boolean } = {}): void {
  menuOpen.value = false
  if (options.focusTrigger) trigger.value?.focus()
}

function onDocumentClick(event: MouseEvent): void {
  if (menuOpen.value && !menuRoot.value?.contains(event.target as Node)) closeMenu()
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape' && menuOpen.value) closeMenu({ focusTrigger: true })
}

onMounted(() => {
  document.addEventListener('click', onDocumentClick)
  document.addEventListener('keydown', onKeydown)
})
onBeforeUnmount(() => {
  document.removeEventListener('click', onDocumentClick)
  document.removeEventListener('keydown', onKeydown)
})

const initial = computed(() => displayName.value.charAt(0).toUpperCase())

// The user menu: things about the person. The app menu: places of the app. Wide screens show both in one dropdown.
const userItems = [
  { to: '/profile', label: 'Mi perfil' },
  { to: '/my-looks', label: 'Mis looks' },
]
const appItems = computed(() => [
  ...(isJurado.value
    ? [{ to: '/admin', label: 'Panel del jurado' }, { to: '/admin/participants', label: 'Participantes' }]
    : []),
  { to: '/runways/past', label: 'Semanas pasadas' },
  { to: '/help', label: 'Ayuda' },
  { to: '/release-notes', label: 'Novedades' },
])

async function installApp(): Promise<void> {
  closeMenu()
  appDrawerOpen.value = false
  await install()
}

async function signOut(): Promise<void> {
  closeMenu()
  appDrawerOpen.value = false
  userDrawerOpen.value = false
  await supabase.auth.signOut()
  clear()
  await navigateTo('/login')
}
</script>

<template>
  <nav class="app-nav" aria-label="Principal">
    <div class="app-nav__start">
      <!-- Phones: the app menu (places of the app), a panel from the left -->
      <button
        v-if="participant"
        type="button"
        class="app-nav__burger"
        aria-label="Abrir el menú de la aplicación"
        aria-haspopup="dialog"
        :aria-expanded="appDrawerOpen"
        @click="appDrawerOpen = true"
      >
        <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" aria-hidden="true">
          <path d="M4 6.5h16M4 12h16M4 17.5h16" />
        </svg>
      </button>

      <NuxtLink to="/" class="app-nav__brand">
        <img class="app-nav__logo" src="/logo.png" :alt="APP_NAME" width="1600" height="693">
      </NuxtLink>
    </div>

    <div class="app-nav__actions">
      <ThemeSwitcher :class="{ 'app-nav__theme--desktop': participant }" />

      <!-- Phones: the user menu (name, profile, looks, sign out), a panel from the right -->
      <button
        v-if="participant"
        type="button"
        class="app-nav__avatar"
        :aria-label="`Abrir el menú de usuario de ${displayName}`"
        aria-haspopup="dialog"
        :aria-expanded="userDrawerOpen"
        @click="userDrawerOpen = true"
      >
        <span class="avatar">
          <img v-if="participant.avatar_url" :src="participant.avatar_url" alt="" class="avatar__img">
          <span v-else class="avatar__initial" aria-hidden="true">{{ initial }}</span>
        </span>
      </button>

      <!-- Tablets and desktop: one dropdown with both menus -->
      <div v-if="participant" ref="menuRoot" class="user-menu">
        <button
          ref="trigger"
          type="button"
          class="user-menu__trigger"
          :aria-expanded="menuOpen"
          :aria-controls="menuId"
          @click="menuOpen = !menuOpen"
        >
          <span class="user-menu__crown" aria-hidden="true">♛</span>
          <span class="user-menu__name">{{ displayName }}</span>
          <span class="user-menu__caret" aria-hidden="true">▾</span>
        </button>

        <ul v-show="menuOpen" :id="menuId" class="user-menu__list">
          <li v-for="item in userItems" :key="item.to">
            <NuxtLink :to="item.to" class="user-menu__item" @click="closeMenu()">
              {{ item.label }}
            </NuxtLink>
          </li>
          <li class="user-menu__divider" role="separator" />
          <li v-for="item in appItems" :key="item.to">
            <NuxtLink :to="item.to" class="user-menu__item" @click="closeMenu()">
              {{ item.label }}
            </NuxtLink>
          </li>
          <li v-if="canInstall">
            <button type="button" class="user-menu__item" @click="installApp">
              {{ PWA_COPY.menuLabel }}
            </button>
          </li>
          <li class="user-menu__divider" role="separator" />
          <li>
            <button type="button" class="user-menu__item" @click="signOut">
              Salir
            </button>
          </li>
        </ul>
      </div>
    </div>

    <template v-if="participant">
      <InstallAppModal />

      <!-- App menu: places of the app and the theme -->
      <AppDrawer :open="appDrawerOpen" title="Menú" side="left" narrow @close="appDrawerOpen = false">
        <nav aria-label="Menú de la aplicación">
          <ul class="drawer-menu">
            <li v-for="item in appItems" :key="item.to">
              <NuxtLink :to="item.to" class="drawer-menu__item" @click="appDrawerOpen = false">
                {{ item.label }}
              </NuxtLink>
            </li>
            <li v-if="canInstall">
              <button type="button" class="drawer-menu__item" @click="installApp">
                {{ PWA_COPY.menuLabel }}
              </button>
            </li>
          </ul>
        </nav>
        <ThemeSwitcher class="drawer-menu__theme" />
      </AppDrawer>

      <!-- User menu: the user's name, profile, looks and sign out -->
      <AppDrawer :open="userDrawerOpen" :title="displayName" side="right" narrow @close="userDrawerOpen = false">
        <nav aria-label="Menú de usuario">
          <ul class="drawer-menu">
            <li v-for="item in userItems" :key="item.to">
              <NuxtLink :to="item.to" class="drawer-menu__item" @click="userDrawerOpen = false">
                {{ item.label }}
              </NuxtLink>
            </li>
          </ul>
        </nav>
        <template #footer>
          <button type="button" class="btn btn--secondary btn--block" @click="signOut">
            Salir
          </button>
        </template>
      </AppDrawer>
    </template>
  </nav>
</template>
