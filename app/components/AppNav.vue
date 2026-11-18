<script setup lang="ts">
const supabase = useSupabaseClient()
const { participant, isJurado, clear } = useCurrentParticipant()

const menuOpen = ref(false)
/** Phones: the same options in a panel that slides in from the left */
const drawerOpen = ref(false)
const menuId = useId()
const menuRoot = ref<HTMLElement | null>(null)
const trigger = ref<HTMLButtonElement | null>(null)

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

// One list for the dropdown (wide screens) and the panel (phones)
const menuItems = computed(() => [
  { to: '/profile', label: 'Mi perfil' },
  { to: '/my-looks', label: 'Mis looks' },
  ...(isJurado.value
    ? [{ to: '/admin', label: 'Panel del jurado' }, { to: '/admin/participants', label: 'Participantes' }]
    : []),
  { to: '/help', label: 'Ayuda' },
  { to: '/novedades', label: 'Novedades' },
])

async function signOut(): Promise<void> {
  closeMenu()
  drawerOpen.value = false
  await supabase.auth.signOut()
  clear()
  await navigateTo('/login')
}
</script>

<template>
  <nav class="app-nav" aria-label="Principal">
    <div class="app-nav__start">
      <!-- Phones: opens the user menu as a panel from the left -->
      <button
        v-if="participant"
        type="button"
        class="app-nav__burger"
        aria-label="Abrir el menú"
        aria-haspopup="dialog"
        :aria-expanded="drawerOpen"
        @click="drawerOpen = true"
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

      <!-- Tablets and desktop: dropdown -->
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
          <li v-for="item in menuItems" :key="item.to">
            <NuxtLink :to="item.to" class="user-menu__item" @click="closeMenu()">
              {{ item.label }}
            </NuxtLink>
          </li>
          <li>
            <button type="button" class="user-menu__item" @click="signOut">
              Salir
            </button>
          </li>
        </ul>
      </div>
    </div>

    <!-- Phones: the user's name and every option of the menu -->
    <AppDrawer v-if="participant" :open="drawerOpen" :title="displayName" side="left" narrow @close="drawerOpen = false">
      <nav aria-label="Menú de usuario">
        <ul class="drawer-menu">
          <li v-for="item in menuItems" :key="item.to">
            <NuxtLink :to="item.to" class="drawer-menu__item" @click="drawerOpen = false">
              {{ item.label }}
            </NuxtLink>
          </li>
        </ul>
      </nav>
      <ThemeSwitcher class="drawer-menu__theme" />
      <template #footer>
        <button type="button" class="btn btn--secondary btn--block" @click="signOut">
          Salir
        </button>
      </template>
    </AppDrawer>
  </nav>
</template>
