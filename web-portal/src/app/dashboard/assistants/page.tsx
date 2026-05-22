'use client'

import { motion } from 'framer-motion'
import { useQuery } from '@tanstack/react-query'
import { Users, Loader2, UserPlus, UserMinus, Sparkles } from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section } from '@/components/ui'

export default function AssistantsPage() {
  return (
    <div className="space-y-6">
      <Section>
        <h1 className="text-3xl font-bold">المساعدون</h1>
        <p className="text-text-secondary mt-1">إدارة مساعدي المدرس</p>
      </Section>

      <Section delay={0.1}>
        <GlassCard>
          <div className="flex items-center gap-4 mb-6">
            <div className="p-4 rounded-2xl bg-primary/10">
              <Users className="w-8 h-8 text-primary" />
            </div>
            <div>
              <h2 className="text-lg font-bold">إدارة المساعدين</h2>
              <p className="text-text-muted">أضف مساعدين لمساعدتك في إدارة الفصول</p>
            </div>
          </div>

          <div className="space-y-3">
            {[
              { name: 'مساعد 1', email: 'assistant1@darsak.ai', status: 'نشط' },
              { name: 'مساعد 2', email: 'assistant2@darsak.ai', status: 'غير نشط' },
            ].map((assistant, index) => (
              <motion.div key={index} initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.2 + index * 0.1 }} className="flex items-center justify-between p-4 rounded-xl bg-bg-secondary/50 border border-white/5 hover:border-white/10 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-neon-gradient flex items-center justify-center">
                    <span className="text-white font-bold">{assistant.name.charAt(0)}</span>
                  </div>
                  <div>
                    <p className="font-medium">{assistant.name}</p>
                    <p className="text-sm text-text-muted" dir="ltr">{assistant.email}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className={`px-3 py-1 rounded-full text-xs ${assistant.status === 'نشط' ? 'bg-accent-green/20 text-accent-green' : 'bg-danger/20 text-danger'}`}>
                    {assistant.status}
                  </span>
                  <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-2 rounded-lg bg-danger/10 text-danger hover:bg-danger/20">
                    <UserMinus className="w-4 h-4" />
                  </motion.button>
                </div>
              </motion.div>
            ))}
          </div>

          <NeonButton variant="glass" className="w-full mt-4" onClick={() => toast('هذه الميزة قيد التطوير', { icon: '' })}>
            <UserPlus className="w-5 h-5" />
            إضافة مساعد جديد
          </NeonButton>
        </GlassCard>
      </Section>
    </div>
  )
}
