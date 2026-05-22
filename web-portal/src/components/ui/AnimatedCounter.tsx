'use client'

import { motion, useMotionValue, useSpring } from 'framer-motion'
import { useEffect, useState } from 'react'

interface AnimatedCounterProps {
  value: number
  duration?: number
  suffix?: string
  className?: string
}

export function AnimatedCounter({ value, duration = 1.5, suffix = '', className }: AnimatedCounterProps) {
  const [displayValue, setDisplayValue] = useState(0)

  useEffect(() => {
    const start = displayValue
    const diff = value - start
    const steps = Math.ceil(duration * 60)
    let step = 0

    const timer = setInterval(() => {
      step++
      const progress = step / steps
      const eased = 1 - Math.pow(1 - progress, 3)
      setDisplayValue(Math.round(start + diff * eased))
      if (step >= steps) {
        setDisplayValue(value)
        clearInterval(timer)
      }
    }, duration * 1000 / steps)

    return () => clearInterval(timer)
  }, [value, duration])

  return (
    <motion.span className={className}>
      {displayValue}
      {suffix}
    </motion.span>
  )
}
