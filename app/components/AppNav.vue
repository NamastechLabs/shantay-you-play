<script setup lang="ts">
const supabase = useSupabaseClient()
const { participant, isJurado, clear } = useCurrentParticipant()

const menuOpen = ref(false)
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

async function signOut(): Promise<void> {
  closeMenu()
  await supabase.auth.signOut()
  clear()
  await navigateTo('/login')
}
</script>

<template>
  <nav class="app-nav" aria-label="Principal">
    <NuxtLink to="/" class="app-nav__brand">
      <!-- Logo placeholder until the brand mark is ready -->
      <span class="app-nav__logo" aria-hidden="true">DR</span>
      <span class="app-nav__name">Drag Race Game</span>
    </NuxtLink>

    <div class="app-nav__actions">
      <ThemeSwitcher />

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
          <li v-if="isJurado">
            <NuxtLink to="/admin" class="user-menu__item" @click="closeMenu()">
              Panel del jurado
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
  </nav>
</template>
