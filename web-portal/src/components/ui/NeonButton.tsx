'use client'

import { motion } from 'framer-motion'
import { cn } from '@/lib/utils'

interface NeonButtonProps {
  children: React.ReactNode
  className?: string
  onClick?: () => void
  variant?: 'neon' | 'glass' | 'outline'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  type?: 'button' | 'submit'
}

export default function NeonButton({
  children,
  className,
  onClick,
  variant = 'neon',
  size = 'md',
  disabled = false,
  type = 'button',
}: NeonButtonProps) {
  const sizeClasses = {
    sm: 'px-4 py-2 text-xs',
    md: 'px-6 py-3 text-sm',
    lg: 'px-8 py-4 text-base',
  }

  const variantClasses = {
    neon: 'brutal-btn',
    glass: 'brutal-btn-secondary',
    outline: 'border border-[var(--accent)] text-[var(--accent)] hover:bg-[rgba(255,0,60,0.1)]',
  }

  return (
    <motion.button
      type={type}
      className={cn(
        'relative overflow-hidden transition-all duration-300 flex items-center justify-center gap-2',
        sizeClasses[size],
        variantClasses[variant],
        disabled && 'opacity-50 cursor-not-allowed',
        className
      )}
      whileHover={!disabled ? { scale: 1.03 } : {}}
      whileTap={!disabled ? { scale: 0.97 } : {}}
      onClick={onClick}
      disabled={disabled}
    >
      {children}
    </motion.button>
  )
}
