'use client'

import { motion, useInView } from 'framer-motion'
import { useRef } from 'react'

interface SectionProps {
  children: React.ReactNode
  className?: string
  delay?: number
  direction?: 'up' | 'down' | 'left' | 'right' | 'none'
}

export default function Section({
  children,
  className = '',
  delay = 0,
  direction = 'up',
}: SectionProps) {
  const ref = useRef<HTMLDivElement>(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })

  const directionVariants = {
    up: { y: 60 },
    down: { y: -60 },
    left: { x: 60 },
    right: { x: -60 },
    none: { y: 0 },
  }

  return (
    <motion.div
      ref={ref}
      className={className}
      initial={{
        opacity: 0,
        ...directionVariants[direction],
        filter: 'blur(10px)',
      }}
      animate={
        isInView
          ? {
              opacity: 1,
              y: 0,
              x: 0,
              filter: 'blur(0px)',
            }
          : {}
      }
      transition={{
        duration: 0.8,
        delay,
        ease: [0.22, 1, 0.36, 1],
      }}
    >
      {children}
    </motion.div>
  )
}
