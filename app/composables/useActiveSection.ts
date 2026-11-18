/**
 * Which section of a long page is being read: the first of `ids` whose element is in the upper part of
 * the screen. Elements that are hidden (inside something collapsed) never count.
 */
export function useActiveSection(ids: MaybeRefOrGetter<string[]>) {
  const activeId = ref(toValue(ids)[0] ?? '')

  onMounted(() => {
    const visible = new Set<string>()
    const observer = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) visible.add(entry.target.id)
        else visible.delete(entry.target.id)
      }
      const first = toValue(ids).find(id => visible.has(id))
      if (first) activeId.value = first
    }, { rootMargin: '0px 0px -60% 0px' })

    for (const id of toValue(ids)) {
      const element = document.getElementById(id)
      if (element) observer.observe(element)
    }
    onBeforeUnmount(() => observer.disconnect())
  })

  return { activeId }
}
