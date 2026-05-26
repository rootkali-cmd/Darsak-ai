'use client'

import { useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import Lenis from 'lenis'
import { auth } from '@/lib/auth'

const CONFIG = {
  itemCount: 4,
  starCount: 20,
  zGap: 1000,
  loopSize: 0,
  camSpeed: 2.5,
}

const TEXTS_EN = ['DARSAK AI', 'VELOCITY', 'BRUTAL', 'SYSTEM', 'FUTURE', 'DESIGN', 'PIXEL', 'HYPER', 'NEON', 'VOID']
const TEXTS_AR = ['درسك أي', 'سرعة', 'قوة', 'نظام', 'مستقبل', 'تصميم', 'بكسل', 'هايبر', 'نيون', 'فراغ']

interface Item {
  el: HTMLElement
  type: 'text' | 'card' | 'star'
  x: number
  y: number
  rot?: number
  baseZ: number
}

export default function LandingPage() {
  const router = useRouter()
  const viewportRef = useRef<HTMLDivElement>(null)
  const worldRef = useRef<HTMLDivElement>(null)
  const overlayRef = useRef<HTMLDivElement>(null)
  const beamRef = useRef<HTMLDivElement>(null)
  const itemsRef = useRef<Item[]>([])
  const stateRef = useRef({ scroll: 0, velocity: 0, targetSpeed: 0, mouseX: 0, mouseY: 0, entered: false })
  const [lang, setLang] = useState<'en' | 'ar'>('en')
  const [loggedIn, setLoggedIn] = useState(false)
  const [welcome, setWelcome] = useState(false)
  const lightStart = 4000
  const isAr = lang === 'ar'
  const texts = isAr ? TEXTS_AR : TEXTS_EN

  useEffect(() => {
    setLoggedIn(auth.isAuthenticated())
  }, [])

  useEffect(() => {
    CONFIG.loopSize = CONFIG.itemCount * CONFIG.zGap

    const html = document.documentElement
    const body = document.body
    html.style.setProperty('height', '10000vh', 'important')
    html.style.setProperty('overflow-y', 'auto', 'important')
    body.style.setProperty('overflow', 'hidden', 'important')
    body.style.setProperty('height', '10000vh', 'important')

    const lenis = new Lenis({
      lerp: 0.08,
      smoothWheel: true,
      syncTouch: true,
      orientation: 'vertical',
      gestureOrientation: 'vertical',
    })
    lenis.on('scroll', ({ scroll, velocity }) => {
      stateRef.current.scroll = scroll
      stateRef.current.targetSpeed = velocity
    })

    const handleMouseMove = (e: MouseEvent) => {
      stateRef.current.mouseX = (e.clientX / window.innerWidth - 0.5) * 2
      stateRef.current.mouseY = (e.clientY / window.innerHeight - 0.5) * 2
    }
    window.addEventListener('mousemove', handleMouseMove)

    const world = worldRef.current
    if (!world) return

    const items: Item[] = []

    for (let i = 0; i < CONFIG.itemCount; i++) {
      const el = document.createElement('div')
      el.className = 'ds-item'
      const isHeading = i % 4 === 0

      if (isHeading) {
        const txt = document.createElement('div')
        txt.className = 'ds-big-text'
        txt.innerText = texts[i % texts.length]
        el.appendChild(txt)
        items.push({ el, type: 'text', x: 0, y: 0, rot: 0, baseZ: -i * CONFIG.zGap })
      } else {
        const card = document.createElement('div')
        card.className = 'ds-card'
        const randId = Math.floor(Math.random() * 9999)
        const angle = (i / CONFIG.itemCount) * Math.PI * 6
        const x = Math.cos(angle) * (window.innerWidth * 0.3)
        const y = Math.sin(angle) * (window.innerHeight * 0.3)
        const rot = (Math.random() - 0.5) * 30
        card.innerHTML = `
          <div class="ds-card-header">
            <span class="ds-card-id">ID-${randId}</span>
            <div style="width:10px;height:10px;background:#ff003c;"></div>
          </div>
          <h2>${texts[i % texts.length]}</h2>
          <div class="ds-card-footer">
            <span>GRID: ${Math.floor(Math.random() * 10)}x${Math.floor(Math.random() * 10)}</span>
            <span>DATA: ${(Math.random() * 100).toFixed(1)}MB</span>
          </div>
          <div class="ds-card-num">0${i}</div>
        `
        el.appendChild(card)
        items.push({ el, type: 'card', x, y, rot, baseZ: -i * CONFIG.zGap })
      }
      world.appendChild(el)
    }

    for (let i = 0; i < CONFIG.starCount; i++) {
      const el = document.createElement('div')
      el.className = 'ds-star'
      world.appendChild(el)
      items.push({
        el, type: 'star',
        x: (Math.random() - 0.5) * 3000,
        y: (Math.random() - 0.5) * 3000,
        baseZ: -Math.random() * CONFIG.loopSize,
      })
    }

    itemsRef.current = items

    let lastTime = 0
    const velEl = document.getElementById('ds-vel')
    const fpsEl = document.getElementById('ds-fps')
    const coordEl = document.getElementById('ds-coord')

    function raf(time: number) {
      lenis.raf(time)
      const delta = time - lastTime
      lastTime = time
      if (fpsEl && time % 10 < 1) fpsEl.innerText = Math.round(1000 / Math.max(delta, 1)).toString()

      const s = stateRef.current
      s.velocity += (s.targetSpeed - s.velocity) * 0.1

      if (velEl) velEl.innerText = Math.abs(s.velocity).toFixed(2)
      if (coordEl) coordEl.innerText = s.scroll.toFixed(0)

      const tiltX = s.mouseY * 5 - s.velocity * 0.5
      const tiltY = s.mouseX * 5
      if (world) world.style.transform = `rotateX(${tiltX}deg) rotateY(${tiltY}deg)`

      const baseFov = 1000
      const fov = baseFov - Math.min(Math.abs(s.velocity) * 10, 600)
      if (viewportRef.current) viewportRef.current.style.perspective = `${fov}px`

      const cameraZ = s.scroll * CONFIG.camSpeed
      const loopSize = CONFIG.loopSize

      for (const item of itemsRef.current) {
        if (!item.el) continue
        let relZ = item.baseZ + cameraZ
        let vizZ = ((relZ % loopSize) + loopSize) % loopSize
        if (vizZ > 500) vizZ -= loopSize

        let alpha = 1
        if (vizZ < -3000) alpha = 0
        else if (vizZ < -2000) alpha = (vizZ + 3000) / 1000
        if (vizZ > 100 && item.type !== 'star') alpha = 1 - (vizZ - 100) / 400
        if (alpha < 0) alpha = 0
        item.el.style.opacity = alpha.toString()

        if (alpha > 0) {
          let trans = `translate3d(${item.x}px, ${item.y}px, ${vizZ}px)`
          if (item.type === 'star') {
            const stretch = Math.max(1, Math.min(1 + Math.abs(s.velocity) * 0.1, 10))
            trans += ` scale3d(1, 1, ${stretch})`
          } else if (item.type === 'text') {
            trans += ` rotateZ(${item.rot || 0}deg)`
            if (Math.abs(s.velocity) > 1) {
              const offset = s.velocity * 2
              item.el.style.textShadow = `${offset}px 0 #ff003c, ${-offset}px 0 #00f3ff`
            } else {
              item.el.style.textShadow = 'none'
            }
          } else {
            const t = time * 0.001
            const float = Math.sin(t + item.x) * 10
            trans += ` rotateZ(${item.rot || 0}deg) rotateY(${float}deg)`
          }
          item.el.style.transform = trans
        }
      }

      const rawScroll = s.scroll
      if (rawScroll > lightStart && !s.entered) {
        const intensity = Math.min((rawScroll - lightStart) / lightStart, 1)
        if (overlayRef.current) overlayRef.current.style.opacity = String(intensity)
        if (beamRef.current) {
          beamRef.current.style.opacity = String(intensity * 0.5)
          beamRef.current.style.transform = `scale(${1 + intensity * 4})`
        }
      }
      if (rawScroll > 8000 && !s.entered) {
        s.entered = true
        setWelcome(true)
        setTimeout(() => router.push('/login'), 1500)
      }

      requestAnimationFrame(raf)
    }
    requestAnimationFrame(raf)

    return () => {
      lenis.destroy()
      window.removeEventListener('mousemove', handleMouseMove)
      for (const item of items) item.el?.remove()
      html.style.removeProperty('height')
      html.style.removeProperty('overflow-y')
      body.style.removeProperty('overflow')
      body.style.removeProperty('height')
    }
  }, [lang, router])

  return (
    <>
      <div className="ds-hud">
        <div className="ds-hud-top">
          <span>SYS.READY</span>
          <div className="ds-hud-line" />
          <span>FPS: <strong id="ds-fps">60</strong></span>
        </div>
        <div className="ds-hud-side">
          SCROLL VELOCITY // <strong id="ds-vel">0.00</strong>
        </div>
        <div className="ds-hud-bottom">
          <span>COORD: <strong id="ds-coord">000.000</strong></span>
          <div className="ds-hud-line" />
          <span>VER 2.0.4 [RELEASE]</span>
        </div>
      </div>

      <button className="ds-lang-btn" onClick={() => setLang(isAr ? 'en' : 'ar')}>
        {isAr ? 'EN' : 'عربي'}
      </button>

      <div className="ds-cta" style={{ opacity: welcome ? 0 : 1, transition: 'opacity 0.3s' }}>
        {loggedIn ? (
          <button className="ds-btn-primary ds-btn-grid-full" onClick={() => router.push('/dashboard')}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="7" />
              <rect x="3" y="14" width="7" height="7" /><rect x="14" y="14" width="7" height="7" />
            </svg>
            {isAr ? 'لوحة التحكم' : 'DASHBOARD'}
          </button>
        ) : (
          <>
            <button className="ds-btn-primary" onClick={() => router.push('/login')}>
              {isAr ? 'تسجيل الدخول' : 'LOGIN'}
            </button>
            <button className="ds-btn-secondary" onClick={() => router.push('/register')}>
              {isAr ? 'ابدأ مجاناً' : 'START FREE'}
            </button>
          </>
        )}
        <button className="ds-btn-download" onClick={() => router.push('/pricing')}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <rect x="2" y="3" width="20" height="18" rx="2" ry="2" />
            <line x1="12" y1="15" x2="12" y2="3" />
            <polyline points="7 8 12 3 17 8" />
          </svg>
          {isAr ? 'الباقات' : 'PRICING'}
        </button>
        <button className="ds-btn-download" onClick={() => router.push('/download')}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          {isAr ? 'التطبيقات' : 'APPS'}
        </button>
      </div>

      <div ref={viewportRef} className="ds-viewport">
        <div ref={worldRef} className="ds-world" />
      </div>

      <div ref={overlayRef} className="ds-light-overlay" style={{ opacity: 0 }} />
      <div ref={beamRef} className="ds-light-beam" style={{ opacity: 0, transform: 'scale(1)' }} />

      {welcome && (
        <div className="ds-welcome">
          <div className="ds-welcome-inner">
            <span className="ds-welcome-ar">أهلاً في</span>
            <span className="ds-welcome-brand">درسك AI</span>
          </div>
        </div>
      )}

      <div className="ds-scroll-proxy" />

      <style dangerouslySetInnerHTML={{__html: `
.ds-hud {
  position: fixed; inset: 2rem; z-index: 20; pointer-events: none;
  display: flex; flex-direction: column; justify-content: space-between;
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px; color: rgba(255,255,255,0.5); text-transform: uppercase;
}
.ds-hud-top, .ds-hud-bottom { display: flex; justify-content: space-between; align-items: center; }
.ds-hud strong { color: #00f3ff; }
.ds-hud-line { flex: 1; height: 1px; background: rgba(255,255,255,0.2); margin: 0 1rem; position: relative; }
.ds-hud-line::after { content: ''; position: absolute; right: 0; top: -2px; width: 5px; height: 5px; background: #ff003c; }
.ds-hud-side { writing-mode: vertical-rl; transform: rotate(180deg); align-self: flex-start; margin-top: auto; margin-bottom: auto; }
.ds-viewport { position: fixed; inset: 0; perspective: 1000px; overflow: hidden; z-index: 1; }
.ds-world { position: absolute; top: 50%; left: 50%; transform-style: preserve-3d; will-change: transform; }
.ds-item { position: absolute; left: 0; top: 0; backface-visibility: hidden; transform-origin: center center; display: flex; align-items: center; justify-content: center; }
.ds-card { width: 320px; height: 460px; background: rgba(10,10,10,0.4); border: 1px solid rgba(255,255,255,0.1); position: relative; padding: 2rem; display: flex; flex-direction: column; justify-content: space-between; backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px); box-shadow: 0 0 0 1px rgba(0,0,0,0.5), 0 20px 50px rgba(0,0,0,0.5); transition: all 0.3s cubic-bezier(0.25,0.46,0.45,0.94); transform: translate(-50%, -50%); }
.ds-card::before, .ds-card::after { content: ''; position: absolute; width: 10px; height: 10px; border: 1px solid transparent; transition: 0.3s; pointer-events: none; }
.ds-card::before { top: -1px; left: -1px; border-top-color: rgba(255,255,255,0.6); border-left-color: rgba(255,255,255,0.6); }
.ds-card::after { bottom: -1px; right: -1px; border-bottom-color: rgba(255,255,255,0.6); border-right-color: rgba(255,255,255,0.6); }
.ds-card:hover { border-color: #ff003c; box-shadow: 0 0 30px rgba(255,0,60,0.2); background: rgba(20,20,20,0.8); }
.ds-card:hover::before, .ds-card:hover::after { width: 100%; height: 100%; border-color: #ff003c; }
.ds-card-header { border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 1rem; margin-bottom: 1rem; display: flex; justify-content: space-between; align-items: center; }
.ds-card-id { font-family: 'JetBrains Mono', monospace; color: #ff003c; font-size: 0.8rem; }
.ds-card h2 { font-size: 2.5rem; line-height: 0.9; margin: 0; text-transform: uppercase; font-weight: 700; color: #fff; mix-blend-mode: hard-light; }
.ds-card-footer { margin-top: auto; font-family: 'JetBrains Mono', monospace; font-size: 0.7rem; color: rgba(255,255,255,0.4); display: flex; justify-content: space-between; }
.ds-card-num { position: absolute; bottom: 2rem; right: 2rem; font-size: 4rem; opacity: 0.1; font-weight: 900; }
.ds-big-text { font-size: 15vw; font-weight: 800; color: transparent; -webkit-text-stroke: 2px rgba(255,255,255,0.15); text-transform: uppercase; white-space: nowrap; transform: translate(-50%, -50%); pointer-events: none; letter-spacing: -0.5rem; mix-blend-mode: overlay; font-family: 'Syncopate', sans-serif; }
.ds-star { position: absolute; width: 2px; height: 2px; background: white; transform: translate(-50%, -50%); }
.ds-scroll-proxy { height: 10000vh; position: absolute; width: 100%; z-index: -1; }
.ds-lang-btn { position: fixed; top: 1.5rem; right: 1.5rem; z-index: 50; padding: 0.5rem 1rem; border: 1px solid rgba(255,255,255,0.2); font-size: 0.75rem; font-family: 'JetBrains Mono', monospace; color: white; background: rgba(0,0,0,0.5); backdrop-filter: blur(8px); cursor: pointer; transition: all 0.2s; }
.ds-lang-btn:hover { border-color: #00f3ff; color: #00f3ff; }
.ds-cta { position: fixed; bottom: 2rem; left: 50%; transform: translateX(-50%); z-index: 50; display: flex; gap: 1rem; }
.ds-btn-primary { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 2rem; background: #ff003c; color: white; font-weight: 700; font-size: 0.875rem; letter-spacing: 0.1em; border: 1px solid #ff003c; cursor: pointer; transition: background 0.2s; font-family: 'JetBrains Mono', monospace; text-transform: uppercase; }
.ds-btn-primary:hover { background: #cc0030; }
.ds-btn-secondary { padding: 0.75rem 2rem; border: 1px solid rgba(255,255,255,0.3); color: white; font-weight: 700; font-size: 0.875rem; letter-spacing: 0.1em; background: rgba(0,0,0,0.5); backdrop-filter: blur(8px); cursor: pointer; transition: all 0.2s; font-family: 'JetBrains Mono', monospace; text-transform: uppercase; }
.ds-btn-secondary:hover { border-color: #00f3ff; color: #00f3ff; }
.ds-btn-download { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1.5rem; border: 1px solid rgba(255,255,255,0.3); color: #00f3ff; font-weight: 700; font-size: 0.75rem; letter-spacing: 0.1em; background: rgba(0,243,255,0.08); backdrop-filter: blur(8px); cursor: pointer; transition: all 0.2s; text-decoration: none; font-family: 'JetBrains Mono', monospace; text-transform: uppercase; }
.ds-btn-download:hover { border-color: #00f3ff; background: rgba(0,243,255,0.15); box-shadow: 0 0 20px rgba(0,243,255,0.2); }
.ds-light-overlay { position: fixed; inset: 0; z-index: 2; background: white; pointer-events: none; transition: opacity 0.05s; }
.ds-light-beam { position: fixed; inset: -200vh; z-index: 3; background: radial-gradient(circle at center, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0.4) 25%, transparent 70%); pointer-events: none; transition: opacity 0.05s, transform 0.05s; }
.ds-welcome { position: fixed; inset: 0; z-index: 100; display: flex; align-items: center; justify-content: center; }
.ds-welcome-inner { text-align: center; animation: dsReveal 0.6s cubic-bezier(0.16, 1, 0.3, 1); }
.ds-welcome-ar { display: block; font-family: 'Tajawal', system-ui, sans-serif; font-size: clamp(2rem, 5vw, 3.5rem); font-weight: 600; color: rgba(0,0,0,0.6); letter-spacing: 0.1em; margin-bottom: 0.25rem; }
.ds-welcome-brand { display: block; font-family: 'Syncopate', sans-serif; font-size: clamp(3rem, 8vw, 6rem); font-weight: 900; color: #000; letter-spacing: 0.15em; }
@keyframes dsReveal { 0% { opacity: 0; transform: translateY(40px) scale(0.9); } 100% { opacity: 1; transform: translateY(0) scale(1); } }
@media (max-width: 640px) {
  .ds-cta { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; bottom: 1rem; width: calc(100% - 2rem); max-width: 400px; }
  .ds-cta button, .ds-cta a { width: 100%; justify-content: center; padding: 0.6rem 0.5rem; font-size: 0.7rem; }
  .ds-cta .ds-btn-grid-full { grid-column: 1 / -1; }
  .ds-hud { inset: 0.75rem; font-size: 7px; }
  .ds-hud-side { display: none; }
  .ds-lang-btn { top: 1.5rem !important; left: 0.75rem !important; right: auto !important; padding: 0.35rem 0.6rem; font-size: 0.6rem; }
  .ds-card { width: 75vw; max-width: 260px; height: auto; min-height: 280px; padding: 1.25rem; backdrop-filter: none; -webkit-backdrop-filter: none; }
  .ds-card h2 { font-size: 1.5rem; }
  .ds-card-num { font-size: 2.5rem; bottom: 1rem; right: 1rem; }
  .ds-big-text { font-size: 12vw; letter-spacing: -0.15rem; }
}
      `}}></style>
    </>
  )
}
