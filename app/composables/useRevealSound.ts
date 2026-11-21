const SOUND_SRC = '/audio/winner.mp3'
const MUTED_KEY = 'reveal-sound-muted'

/**
 * Sound of the winner reveal. The mp3 is optional: it is looked for once (`public/audio/winner.mp3`) and,
 * if it is not there, nothing is loaded, nothing plays and `available` stays false (so no mute button).
 * Browsers block sound until the person has touched the page; then `play` fails silently and the reveal
 * runs without sound. The mute choice is remembered on the device.
 * Client-only: call it from a component that is mounted on the client.
 */
export function useRevealSound() {
  const available = ref(false)
  const muted = ref(false)
  let audio: HTMLAudioElement | null = null

  onMounted(async () => {
    try {
      muted.value = localStorage.getItem(MUTED_KEY) === '1'
    }
    catch {
      // Storage can be blocked: the sound simply starts on
    }

    try {
      const response = await fetch(SOUND_SRC, { method: 'HEAD' })
      if (!response.ok || !response.headers.get('content-type')?.startsWith('audio')) return
      audio = new Audio(SOUND_SRC)
      audio.preload = 'auto'
      available.value = true
    }
    catch {
      // Offline or blocked: no sound
    }
  })

  function play(): void {
    if (!audio || muted.value) return
    audio.currentTime = 0
    audio.play().catch(() => {
      // Blocked until the person interacts with the page
    })
  }

  function stop(): void {
    audio?.pause()
  }

  function toggleMuted(): void {
    muted.value = !muted.value
    if (muted.value) stop()
    try {
      localStorage.setItem(MUTED_KEY, muted.value ? '1' : '0')
    }
    catch {
      // Not remembered, still applies to this reveal
    }
  }

  onBeforeUnmount(stop)

  return { available, muted, play, stop, toggleMuted }
}
