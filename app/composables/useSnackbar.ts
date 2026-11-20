export type SnackbarType = 'success' | 'error' | 'info'

export interface SnackbarMessage {
  /** Increases with every message, so the same text shown twice restarts the timer and the animation */
  id: number
  message: string
  type: SnackbarType
}

interface ShowOptions {
  message: string
  type?: SnackbarType
  /** Milliseconds before it closes by itself. Errors stay until dismissed unless a duration is given. */
  duration?: number
}

/** Success and info messages close after this long; errors stay until dismissed */
export const SNACKBAR_DURATION = 3000

let timer: ReturnType<typeof setTimeout> | undefined

/**
 * App-wide feedback messages (DRG-20). One snackbar at a time: a new message replaces the current one.
 * `<AppSnackbar>` is mounted once in `app.vue` and renders the state kept here.
 */
export function useSnackbar() {
  const current = useState<SnackbarMessage | null>('snackbar', () => null)
  /** Extra space (px) kept free at the bottom, e.g. the pinned ballot bar */
  const offset = useState('snackbar-offset', () => 0)

  function dismiss() {
    clearTimeout(timer)
    current.value = null
  }

  function show({ message, type = 'info', duration }: ShowOptions) {
    // Timers only make sense in the browser: on the server there is nothing to close
    if (import.meta.server) return
    clearTimeout(timer)
    current.value = { id: (current.value?.id ?? 0) + 1, message, type }
    const closeAfter = duration ?? (type === 'error' ? 0 : SNACKBAR_DURATION)
    if (closeAfter > 0) timer = setTimeout(dismiss, closeAfter)
  }

  return {
    current: readonly(current),
    offset,
    show,
    dismiss,
    success: (message: string) => show({ message, type: 'success' }),
    error: (message: string) => show({ message, type: 'error' }),
    info: (message: string) => show({ message, type: 'info' }),
  }
}

/**
 * Keeps snackbars above a pinned element (the ballot bar) while the page is open.
 * Pass a template ref to the element; the offset follows its height.
 */
export function useSnackbarOffset(el: Ref<HTMLElement | null | undefined>) {
  const { offset } = useSnackbar()
  let observer: ResizeObserver | undefined

  onMounted(() => {
    watch(el, (element) => {
      observer?.disconnect()
      if (!element) {
        offset.value = 0
        return
      }
      observer = new ResizeObserver(() => {
        // Height plus the gap the bar keeps from the screen edge
        offset.value = element.offsetHeight + 12
      })
      observer.observe(element)
    }, { immediate: true, flush: 'post' })
  })

  onBeforeUnmount(() => {
    observer?.disconnect()
    offset.value = 0
  })
}
