'use client'

import { motion } from 'framer-motion'
import { cn } from '@/lib/utils'
import { useRef, useState } from 'react'

interface GlassCardProps {
  children: React.ReactNode
  className?: string
  delay?: number
  tilt?: boolean
  glow?: boolean
  onClick?: () => void
}

export default function GlassCard({
  children,
  className,
  delay = 0,
  tilt = true,
  glow = false,
  onClick,
}: GlassCardProps) {
  const cardRef = useRef<HTMLDivElement>(null)
  const [rotateX, setRotateX] = useState(0)
  const [rotateY, setRotateY] = useState(0)

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!tilt || !cardRef.current) return
    const rect = cardRef.current.getBoundingClientRect()
    const x = (e.clientX - rect.left) / rect.width - 0.5
    const y = (e.clientY - rect.top) / rect.height - 0.5
    setRotateX(y * -10)
    setRotateY(x * 10)
  }

  const handleMouseLeave = () => {
    setRotateX(0)
    setRotateY(0)
  }

  return (
    <motion.div
      ref={cardRef}
      className={cn(
        'glass-card rounded-none p-6 transition-all duration-300',
        glow && 'neon-border',
        className
      )}
      initial={{ opacity: 0, y: 30, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{
        duration: 0.5,
        delay,
        type: 'spring',
        stiffness: 100,
        damping: 20,
      }}
      whileHover={{
        y: -5,
        transition: { duration: 0.3 },
      }}
      style={{
        position: 'relative',
        ...(tilt
          ? {
              transform: `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`,
              transformStyle: 'preserve-3d',
            }
          : {}),
      }}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      onClick={onClick}
    >
      {children}
    </motion.div>
  )
}
