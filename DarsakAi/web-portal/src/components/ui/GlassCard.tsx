'use client'

import { motion } from 'framer-motion'
import { cn } from '@/lib/utils'

interface CardProps {
  children: React.ReactNode
  className?: string
  delay?: number
  onClick?: () => void
}

export default function Card({
  children,
  className,
  delay = 0,
  onClick,
}: CardProps) {
  return (
    <motion.div
      className={cn('card p-5', className)}
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay, ease: [0.16, 1, 0.3, 1] }}
      onClick={onClick}
    >
      {children}
    </motion.div>
  )
}
