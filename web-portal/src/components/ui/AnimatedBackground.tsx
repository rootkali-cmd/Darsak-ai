'use client'

import { motion } from 'framer-motion'

export default function AnimatedBackground() {
  const orbs = [
    { id: 1, color: '#8B5CF6', size: 500, x: 10, y: 20 },
    { id: 2, color: '#EC4899', size: 400, x: 60, y: 10 },
    { id: 3, color: '#06B6D4', size: 350, x: 30, y: 60 },
    { id: 4, color: '#F59E0B', size: 300, x: 80, y: 50 },
    { id: 5, color: '#10B981', size: 450, x: 50, y: 80 },
  ]

  return (
    <div className="fixed inset-0 overflow-hidden pointer-events-none z-0">
      {orbs.map((orb) => (
        <motion.div
          key={orb.id}
          className="absolute rounded-full"
          style={{
            background: `radial-gradient(circle, ${orb.color} 0%, transparent 70%)`,
            width: orb.size,
            height: orb.size,
            left: `${orb.x}%`,
            top: `${orb.y}%`,
            filter: 'blur(80px)',
            opacity: 0.12,
          }}
          animate={{
            scale: [1, 1.1, 1],
          }}
          transition={{
            duration: 8 + orb.id,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />
      ))}

      {Array.from({ length: 20 }).map((_, i) => (
        <motion.div
          key={i}
          className="absolute rounded-full"
          style={{
            width: Math.random() * 3 + 1,
            height: Math.random() * 3 + 1,
            left: `${Math.random() * 100}%`,
            top: `${Math.random() * 100}%`,
            background: ['#8B5CF6', '#EC4899', '#06B6D4', '#FFFFFF'][Math.floor(Math.random() * 4)],
            opacity: Math.random() * 0.2 + 0.05,
          }}
          animate={{
            y: [0, -40 - Math.random() * 20, 0],
            opacity: [0.05, 0.25, 0.05],
          }}
          transition={{
            duration: 8 + Math.random() * 4,
            repeat: Infinity,
            delay: Math.random() * 3,
            ease: 'easeInOut',
          }}
        />
      ))}

      <div
        className="absolute inset-0 opacity-[0.02]"
        style={{
          backgroundImage: `
            linear-gradient(rgba(139, 92, 246, 0.3) 1px, transparent 1px),
            linear-gradient(90deg, rgba(139, 92, 246, 0.3) 1px, transparent 1px)
          `,
          backgroundSize: '60px 60px',
        }}
      />
    </div>
  )
}
