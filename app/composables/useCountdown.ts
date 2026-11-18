/**
 * Ticks once per second on the client and exposes the time left until `target`.
 * `remaining` is null on the server, during hydration and without a target, so the
 * server and client markup match; the label only appears once the page is mounted.
 */
export function useCountdown(target: MaybeRefOrGetter<string | null | undefined>) {
  const now = ref<number | null>(null)
  let timer: ReturnType<typeof setInterval> | undefined

  onMounted(() => {
    now.value = Date.now()
    timer = setInterval(() => { now.value = Date.now() }, 1000)
  })
  onBeforeUnmount(() => clearInterval(timer))

  const remaining = computed<number | null>(() => {
    const at = toValue(target)
    if (!at || now.value === null) return null
    return new Date(at).getTime() - now.value
  })
  const label = computed(() => (remaining.value === null ? '' : formatCountdown(remaining.value)))

  return { remaining, label }
}
