'use client'

import { motion } from 'framer-motion'

interface ProgressRingProps {
  progress: number
  size?: number
  strokeWidth?: number
  color?: string
  bgColor?: string
  className?: string
  label?: string
}

export default function ProgressRing({
  progress,
  size = 120,
  strokeWidth = 8,
  color = '#8B5CF6',
  bgColor = 'rgba(255, 255, 255, 0.1)',
  className = '',
  label,
}: ProgressRingProps) {
  const radius = (size - strokeWidth) / 2
  const circumference = radius * 2 * Math.PI
  const offset = circumference - (progress / 100) * circumference

  return (
    <div className={`relative inline-flex items-center justify-center ${className}`}>
      <motion.svg
        width={size}
        height={size}
        className="transform -rotate-90"
        initial={{ rotate: -90 }}
        animate={{ rotate: 0 }}
        transition={{ duration: 0.5 }}
      >
        {/* Background Circle */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={bgColor}
          strokeWidth={strokeWidth}
        />
        {/* Progress Circle */}
        <motion.circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          initial={{ strokeDashoffset: circumference }}
          animate={{ strokeDashoffset: offset }}
          transition={{ duration: 1.5, ease: 'easeInOut' }}
          style={{
            filter: `drop-shadow(0 0 6px ${color}80)`,
          }}
        />
      </motion.svg>
      {/* Center Content */}
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-2xl font-bold">{progress}%</span>
        {label && <span className="text-xs text-text-secondary">{label}</span>}
      </div>
    </div>
  )
}
