'use client'

import { useEffect, useRef } from 'react'

export default function CustomCursor() {
  const circleRef = useRef<HTMLDivElement>(null)
  const dotRef = useRef<HTMLDivElement>(null)
  const hoveringRef = useRef(false)
  const mouseRef = useRef({ x: -100, y: -100 })
  const cursorRef = useRef({ x: -100, y: -100 })
  const rafRef = useRef<number>(0)

  useEffect(() => {
    const onMouseMove = (e: MouseEvent) => {
      mouseRef.current = { x: e.clientX, y: e.clientY }
    }

    const onOver = (e: MouseEvent) => {
      const t = e.target as HTMLElement
      if (
        t.tagName === 'BUTTON' || t.tagName === 'A' || t.tagName === 'INPUT' ||
        t.closest('button') || t.closest('a') || t.closest('[role="button"]') ||
        t.style.cursor === 'pointer'
      ) {
        hoveringRef.current = true
      }
    }

    const onOut = () => {
      hoveringRef.current = false
    }

    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('mouseover', onOver)
    window.addEventListener('mouseout', onOut)

    const animate = () => {
      const target = mouseRef.current
      const cursor = cursorRef.current
      const hovering = hoveringRef.current

      cursor.x += (target.x - cursor.x) * 0.15
      cursor.y += (target.y - cursor.y) * 0.15

      const size = hovering ? 50 : 24
      const half = size / 2

      if (circleRef.current) {
        circleRef.current.style.left = `${cursor.x - half}px`
        circleRef.current.style.top = `${cursor.y - half}px`
        circleRef.current.style.width = `${size}px`
        circleRef.current.style.height = `${size}px`
        circleRef.current.style.borderColor = hovering ? '#00f3ff' : '#ff003c'
        circleRef.current.style.background = hovering ? 'rgba(0, 243, 255, 0.1)' : 'transparent'
      }

      if (dotRef.current) {
        dotRef.current.style.left = `${target.x - 3}px`
        dotRef.current.style.top = `${target.y - 3}px`
      }

      rafRef.current = requestAnimationFrame(animate)
    }

    rafRef.current = requestAnimationFrame(animate)

    return () => {
      cancelAnimationFrame(rafRef.current)
      window.removeEventListener('mousemove', onMouseMove)
      window.removeEventListener('mouseover', onOver)
      window.removeEventListener('mouseout', onOut)
    }
  }, [])

  return (
    <>
      <div
        ref={circleRef}
        style={{
          position: 'fixed',
          left: '-100px',
          top: '-100px',
          width: 24,
          height: 24,
          border: '2px solid #ff003c',
          borderRadius: '50%',
          pointerEvents: 'none',
          zIndex: 99999,
          transition: 'width 0.15s ease, height 0.15s ease, border-color 0.15s ease, background 0.15s ease',
        }}
      />
      <div
        ref={dotRef}
        style={{
          position: 'fixed',
          left: '-100px',
          top: '-100px',
          width: 6,
          height: 6,
          background: '#00f3ff',
          borderRadius: '50%',
          pointerEvents: 'none',
          zIndex: 99999,
        }}
      />
    </>
  )
}
