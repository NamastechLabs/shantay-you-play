<script setup lang="ts">
/**
 * Judge-only: uploads the weekly runway intro video. It is always stored as
 * `intro.mp4` in the 'runway-intro' bucket, overwriting the previous one, so the
 * free storage plan only ever holds a single video.
 */
const FILE_NAME = 'intro.mp4'
const MAX_BYTES = 50 * 1024 * 1024
const MAX_MB = MAX_BYTES / 1024 / 1024
/** 9:16 portrait, with some tolerance for encoders that round the size */
const TARGET_RATIO = 9 / 16
const RATIO_TOLERANCE = 0.03

const supabase = useSupabaseClient()
const bucket = useRuntimeConfig().public.runwayIntroBucket

const inputId = useId()
const uploading = ref(false)
const snackbar = useSnackbar()
// Busts the cache of the preview after each upload
const version = ref(Date.now())
const hasVideo = ref(true)

const previewSrc = computed(() => {
  const { data } = supabase.storage.from(bucket).getPublicUrl(FILE_NAME)
  return `${data.publicUrl}?t=${version.value}`
})

/** Reads the video size from its metadata, without uploading it. */
function readDimensions(file: File): Promise<{ width: number, height: number }> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const video = document.createElement('video')
    const done = () => URL.revokeObjectURL(url)
    video.preload = 'metadata'
    video.onloadedmetadata = () => {
      done()
      resolve({ width: video.videoWidth, height: video.videoHeight })
    }
    video.onerror = () => {
      done()
      reject(new Error('No se pudo leer el vídeo. Comprueba que sea un MP4 válido.'))
    }
    video.src = url
  })
}

async function validate(file: File): Promise<void> {
  if (file.type !== 'video/mp4') throw new Error('El vídeo debe ser un archivo MP4.')
  if (file.size > MAX_BYTES) throw new Error(`El vídeo pesa más de ${MAX_MB} MB. Comprímelo e inténtalo de nuevo.`)

  const { width, height } = await readDimensions(file)
  if (Math.abs(width / height - TARGET_RATIO) > RATIO_TOLERANCE) {
    throw new Error('El vídeo debe ser vertical, en formato 9:16 (por ejemplo 1080×1920).')
  }
}

async function onChange(event: Event): Promise<void> {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file || uploading.value) return

  uploading.value = true
  try {
    await validate(file)
    const { error } = await supabase.storage.from(bucket).upload(FILE_NAME, file, {
      contentType: 'video/mp4',
      // Replace last week's video; a short cache keeps the new one from being served stale
      upsert: true,
      cacheControl: '60',
    })
    if (error) throw error
    version.value = Date.now()
    hasVideo.value = true
    snackbar.success('Vídeo subido. Ya reemplaza al anterior.')
  }
  catch (error) {
    snackbar.error(toErrorMessage(error))
  }
  finally {
    uploading.value = false
  }
}
</script>

<template>
  <section class="section" aria-labelledby="intro-video-title">
    <div class="section-header">
      <div class="intro-video__titles">
        <h2 id="intro-video-title">
          Vídeo de introducción
        </h2>
        <p class="hint">
          Prepara la entrada a tu pasarela con un vídeo de presentación.
        </p>
      </div>
    </div>

    <div class="intro-video">
      <div class="intro-video__preview">
        <p class="kicker">
          Vista previa
        </p>
        <video
          v-if="hasVideo"
          :key="version"
          class="intro-video__player"
          :src="previewSrc"
          controls
          playsinline
          preload="metadata"
          @error="hasVideo = false"
        />
        <p v-else class="intro-video__player intro-video__player--empty muted">
          Aún no hay vídeo de introducción.
        </p>
        <p class="hint">
          {{ hasVideo ? 'Vídeo actual · Formato vertical' : 'Sin vídeo' }}
        </p>
      </div>

      <div class="intro-video__details">
        <div class="intro-video__titles">
          <h3>Vídeo actual</h3>
          <p class="muted">
            Se muestra al empezar la pasarela.
          </p>
        </div>
        <p>
          <span class="badge" :class="hasVideo ? 'badge--approved' : 'badge--pending'">
            {{ hasVideo ? 'Configurado' : 'Sin vídeo' }}
          </span>
        </p>

        <dl class="intro-video__specs">
          <div>
            <dt class="kicker">
              Formato
            </dt>
            <dd>MP4</dd>
          </div>
          <div>
            <dt class="kicker">
              Orientación
            </dt>
            <dd>Vertical · 9:16</dd>
          </div>
          <div>
            <dt class="kicker">
              Tamaño máximo
            </dt>
            <dd>{{ MAX_MB }} MB</dd>
          </div>
        </dl>

        <div v-if="hasVideo" class="intro-video__notice">
          <strong>El nuevo vídeo sustituirá al actual</strong>
          <span class="muted">Solo se guarda un vídeo. Revisa el archivo antes de reemplazarlo.</span>
        </div>

        <div class="intro-video__upload">
          <label :for="inputId" class="btn btn--primary" :aria-disabled="uploading">
            {{ uploading ? 'Subiendo…' : hasVideo ? '↑ Cambiar vídeo' : '↑ Subir vídeo' }}
          </label>
          <input
            :id="inputId"
            class="intro-video__input"
            type="file"
            accept="video/mp4"
            :disabled="uploading"
            @change="onChange"
          >
          <p class="hint">
            Selecciona un archivo MP4 de hasta {{ MAX_MB }} MB.
          </p>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped lang="scss">
.intro-video {
  display: grid;
  overflow: hidden;
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);

  @media (min-width: 48rem) {
    grid-template-columns: minmax(16rem, 5fr) 7fr;
  }
}

.intro-video__titles {
  display: grid;
  gap: var(--space-1);
}

.intro-video__preview {
  display: grid;
  gap: var(--space-4);
  justify-items: center;
  align-content: start;
  padding: var(--space-5);
  background-color: var(--color-surface-raised);

  .kicker {
    justify-self: start;
  }
}

.intro-video__player {
  width: 100%;
  max-width: 14.5rem;
  aspect-ratio: 9 / 16;
  background-color: #000;
  border-radius: var(--radius-md);
  object-fit: contain;

  &--empty {
    display: grid;
    padding: var(--space-4);
    text-align: center;
    place-items: center;
    background-color: var(--color-surface);
    border: 2px dashed var(--color-border);
  }
}

.intro-video__details {
  display: grid;
  gap: var(--space-4);
  align-content: start;
  padding: var(--space-5);
}

.intro-video__specs {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--space-4);
  padding-block: var(--space-4);
  border-block: 1px solid var(--color-border);

  dd {
    margin: var(--space-1) 0 0;
    font-weight: 700;
  }
}

.intro-video__notice {
  display: grid;
  gap: var(--space-1);
  padding: var(--space-4);
  background-color: var(--color-surface-raised);
  border-radius: var(--radius-md);
}

.intro-video__upload {
  display: grid;
  gap: var(--space-2);
  justify-items: start;
}

// Visually hidden but still keyboard-focusable; the label acts as the button
.intro-video__input {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip-path: inset(50%);
}

.intro-video__upload:has(.intro-video__input:focus-visible) .btn {
  outline: 2px solid var(--color-focus);
  outline-offset: 2px;
}
</style>
