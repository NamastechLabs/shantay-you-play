<script setup lang="ts">
const { participant, updateProfile } = useCurrentParticipant()
const { uploadAvatar, removeByUrl } = useAvatarUpload()

const name = ref(participant.value?.name ?? '')
const dragName = ref(participant.value?.drag_name ?? '')

/** A newly picked file, not uploaded until the form is saved */
const newFile = ref<File | null>(null)
const previewUrl = ref<string | null>(null)
const removeAvatar = ref(false)

const saving = ref(false)
const saved = ref(false)
const errorMessage = ref<string | null>(null)

const currentAvatar = computed(() => (removeAvatar.value ? null : previewUrl.value ?? participant.value?.avatar_url ?? null))
const initial = computed(() => (dragName.value || name.value || '?').trim().charAt(0).toUpperCase())

const trimmedName = computed(() => name.value.trim())
const trimmedDragName = computed(() => dragName.value.trim())
const isValid = computed(() =>
  trimmedName.value.length >= 1 && trimmedName.value.length <= 100
  && trimmedDragName.value.length >= 2 && trimmedDragName.value.length <= 50,
)
const isDirty = computed(() =>
  trimmedName.value !== participant.value?.name
  || trimmedDragName.value !== (participant.value?.drag_name ?? '')
  || newFile.value !== null
  || removeAvatar.value,
)

function revokePreview(): void {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
  previewUrl.value = null
}
onBeforeUnmount(revokePreview)

function onFilePicked(event: Event): void {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return

  revokePreview()
  newFile.value = file
  previewUrl.value = URL.createObjectURL(file)
  removeAvatar.value = false
  saved.value = false
}

function clearAvatar(): void {
  revokePreview()
  newFile.value = null
  removeAvatar.value = true
  saved.value = false
}

async function submit(): Promise<void> {
  const current = participant.value
  if (!current || !isValid.value || saving.value) return

  saving.value = true
  saved.value = false
  errorMessage.value = null

  const previousAvatar = current.avatar_url
  let uploaded: { path: string, publicUrl: string } | null = null
  try {
    let avatarUrl = previousAvatar
    if (newFile.value) {
      uploaded = await uploadAvatar(current.id, newFile.value)
      avatarUrl = uploaded.publicUrl
    }
    else if (removeAvatar.value) {
      avatarUrl = null
    }

    await updateProfile({ name: trimmedName.value, drag_name: trimmedDragName.value, avatar_url: avatarUrl })

    if (avatarUrl !== previousAvatar) await removeByUrl(previousAvatar)

    name.value = trimmedName.value
    dragName.value = trimmedDragName.value
    revokePreview()
    newFile.value = null
    removeAvatar.value = false
    saved.value = true
  }
  catch (error) {
    // Don't leave an orphaned file behind if the row couldn't be written
    if (uploaded) await removeByUrl(uploaded.publicUrl)
    errorMessage.value = toErrorMessage(error)
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <main class="page">
    <AppNav />
    <AppBreadcrumb :items="[{ label: 'Inicio', to: '/' }, { label: 'Mi perfil' }]" />

    <header class="page-header">
      <div class="page-header__titles">
        <p class="kicker">
          {{ APP_NAME }}
        </p>
        <h1>Mi perfil</h1>
      </div>
    </header>

    <form class="card profile" @submit.prevent="submit">
      <div class="profile__avatar">
        <span class="avatar avatar--large">
          <img v-if="currentAvatar" :src="currentAvatar" alt="Foto de perfil" class="avatar__img">
          <span v-else class="avatar__initial" aria-hidden="true">{{ initial }}</span>
        </span>

        <div class="profile__avatar-actions">
          <label class="btn btn--ghost">
            {{ currentAvatar ? 'Cambiar foto' : 'Subir foto' }}
            <input type="file" accept="image/*" class="sr-only" @change="onFilePicked">
          </label>
          <button v-if="currentAvatar" type="button" class="btn btn--ghost" @click="clearAvatar">
            Quitar foto
          </button>
          <p class="hint">
            Opcional. JPG, PNG o WebP.
          </p>
        </div>
      </div>

      <div class="form">
        <div class="field">
          <label for="profile-name" class="field__label">Nombre</label>
          <input
            id="profile-name"
            v-model="name"
            class="field__input"
            type="text"
            autocomplete="name"
            maxlength="100"
            required
          >
        </div>

        <div class="field">
          <label for="profile-drag-name" class="field__label">Nombre drag</label>
          <input
            id="profile-drag-name"
            v-model="dragName"
            class="field__input"
            type="text"
            autocomplete="nickname"
            minlength="2"
            maxlength="50"
            required
            placeholder="Ej. Miss Fierce"
          >
        </div>

        <p v-if="errorMessage" class="form-error" role="alert">
          {{ errorMessage }}
        </p>
        <p v-else-if="saved" class="hint" role="status">
          ¡Perfil actualizado!
        </p>

        <div class="form-actions">
          <button type="submit" class="btn btn--primary" :disabled="!isValid || !isDirty || saving">
            {{ saving ? 'Guardando…' : 'Guardar cambios' }}
          </button>
        </div>
      </div>
    </form>
  </main>
</template>
