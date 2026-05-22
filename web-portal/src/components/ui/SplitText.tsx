'use client'

import { motion } from 'framer-motion'

interface SplitTextProps {
  text: string
  className?: string
  delay?: number
}

export default function SplitText({ text, className = '', delay = 0 }: SplitTextProps) {
  const chars = text.split('')

  return (
    <span className={className}>
      {chars.map((char, i) => (
        <motion.span
          key={i}
          className="inline-block"
          initial={{ opacity: 0, y: 80, rotateX: -90 }}
          animate={{ opacity: 1, y: 0, rotateX: 0 }}
          transition={{
            delay: delay + i * 0.04,
            duration: 0.6,
            type: 'spring',
            stiffness: 150,
            damping: 12,
          }}
        >
          {char === ' ' ? '\u00A0' : char}
        </motion.span>
      ))}
    </span>
  )
}
