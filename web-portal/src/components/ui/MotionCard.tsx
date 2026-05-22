'use client'

import { motion } from 'framer-motion'
import { cn } from '@/lib/utils'

interface MotionCardProps {
  children: React.ReactNode
  className?: string
  delay?: number
  onClick?: () => void
}

export function MotionCard({ children, className, delay = 0, onClick }: MotionCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay, ease: 'easeOut' }}
      whileHover={{ y: -4, transition: { duration: 0.2 } }}
      className={cn(
        'bg-card rounded-xl border border-border p-6 card-hover',
        className
      )}
      onClick={onClick}
    >
      {children}
    </motion.div>
  )
}
