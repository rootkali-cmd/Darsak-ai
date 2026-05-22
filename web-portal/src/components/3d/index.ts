import dynamic from 'next/dynamic'

const FloatingOrbInner = dynamic(
  () => import('./FloatingOrb').then((m) => ({ default: m.FloatingOrb })),
  { ssr: false }
)

const OrbSceneInner = dynamic(
  () => import('./FloatingOrb').then((m) => ({ default: m.OrbScene })),
  { ssr: false }
)

const Hero3DBackgroundInner = dynamic(
  () => import('./Hero3DBackground').then((m) => ({ default: m.Hero3DBackground })),
  { ssr: false }
)

export { FloatingOrbInner as FloatingOrb, OrbSceneInner as OrbScene, Hero3DBackgroundInner as Hero3DBackground }
