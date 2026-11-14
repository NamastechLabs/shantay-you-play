interface Piece {
  x: number
  y: number
  vx: number
  vy: number
  size: number
  angle: number
  spin: number
  color: string
  life: number
}

const DURATION_MS = 4500

/**
 * Winner confetti: two cannons from the bottom corners plus a light rain, drawn on a
 * temporary full-screen canvas (no dependency). Colors come from the active theme.
 * Client-only: call `launch` from an event or `onMounted`. The canvas is removed when the
 * animation ends, on `stop`, or when the component unmounts.
 */
export function useConfetti() {
  let frame = 0
  let canvas: HTMLCanvasElement | null = null

  function stop(): void {
    cancelAnimationFrame(frame)
    canvas?.remove()
    canvas = null
  }

  function launch(): void {
    stop()
    const element = document.createElement('canvas')
    element.setAttribute('aria-hidden', 'true')
    element.style.cssText = 'position:fixed;inset:0;z-index:10;width:100vw;height:100vh;pointer-events:none'
    document.body.append(element)
    canvas = element

    const context = element.getContext('2d')
    if (!context) return stop()

    const ratio = window.devicePixelRatio || 1
    const width = window.innerWidth
    const height = window.innerHeight
    element.width = width * ratio
    element.height = height * ratio
    context.scale(ratio, ratio)

    const style = getComputedStyle(document.documentElement)
    const colors = ['--color-primary', '--color-accent', '--color-highlight', '--color-title']
      .map(name => style.getPropertyValue(name).trim())
      .filter(Boolean)

    const piece = (x: number, y: number, vx: number, vy: number): Piece => ({
      x,
      y,
      vx,
      vy,
      size: 6 + Math.random() * 8,
      angle: Math.random() * Math.PI * 2,
      spin: (Math.random() - 0.5) * 0.3,
      color: colors[Math.floor(Math.random() * colors.length)] ?? '#fff',
      life: 0,
    })

    const pieces: Piece[] = []
    for (let i = 0; i < 90; i++) {
      const speed = 12 + Math.random() * 12
      const spread = (Math.random() - 0.5) * 0.7
      pieces.push(piece(0, height, speed * Math.sin(0.9 + spread), -speed * Math.cos(0.9 + spread)))
      pieces.push(piece(width, height, -speed * Math.sin(0.9 + spread), -speed * Math.cos(0.9 + spread)))
    }
    for (let i = 0; i < 60; i++) {
      pieces.push(piece(Math.random() * width, -20 - Math.random() * height * 0.5, (Math.random() - 0.5) * 2, 2 + Math.random() * 3))
    }

    const started = performance.now()
    const draw = (now: number): void => {
      const elapsed = now - started
      context.clearRect(0, 0, width, height)
      for (const p of pieces) {
        p.vy += 0.28
        p.vx *= 0.99
        p.x += p.vx
        p.y += p.vy
        p.angle += p.spin
        p.life += 1
        context.save()
        context.globalAlpha = Math.max(0, Math.min(1, (DURATION_MS - elapsed) / 1000))
        context.translate(p.x, p.y)
        context.rotate(p.angle)
        context.fillStyle = p.color
        context.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2)
        context.restore()
      }
      if (elapsed < DURATION_MS) frame = requestAnimationFrame(draw)
      else stop()
    }
    frame = requestAnimationFrame(draw)
  }

  onBeforeUnmount(stop)

  return { launch, stop }
}
