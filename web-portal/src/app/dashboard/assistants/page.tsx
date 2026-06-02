'use client'

import { motion } from 'framer-motion'
import { Users, UserPlus, UserMinus, Sparkles } from 'lucide-react'
import toast from 'react-hot-toast'

export default function AssistantsPage() {
  const glassCard = 'bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl'
  const btnGradient = { background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      className="space-y-6"
    >
      <div>
        <h1 className="text-3xl font-bold text-white">المساعدون</h1>
        <p className="text-slate-400 mt-1">إدارة مساعدي المدرس</p>
      </div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-6`}>
          <div className="flex items-center gap-4 mb-6">
            <div className="p-4 rounded-2xl bg-indigo-500/10">
              <Users className="w-8 h-8 text-indigo-400" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">إدارة المساعدين</h2>
              <p className="text-slate-400 text-sm">أضف مساعدين لمساعدتك في إدارة الفصول</p>
            </div>
          </div>

          <div className="space-y-3">
            {[
              { name: 'مساعد 1', email: 'assistant1@darsak.ai', status: 'نشط' },
              { name: 'مساعد 2', email: 'assistant2@darsak.ai', status: 'غير نشط' },
            ].map((assistant, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.2 + index * 0.1 }}
                className="flex items-center justify-between p-4 rounded-xl bg-white/[0.02] border border-white/[0.06] hover:border-white/[0.12] transition-colors"
              >
                <div className="flex items-center gap-3">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center"
                    style={btnGradient}
                  >
                    <span className="text-white font-bold">{assistant.name.charAt(0)}</span>
                  </div>
                  <div>
                    <p className="font-medium text-white">{assistant.name}</p>
                    <p className="text-sm text-slate-400" dir="ltr">{assistant.email}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span
                    className={`px-3 py-1 rounded-full text-xs font-medium backdrop-blur-sm ${
                      assistant.status === 'نشط'
                        ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/25'
                        : 'bg-red-500/15 text-red-400 border border-red-500/25'
                    }`}
                  >
                    {assistant.status}
                  </span>
                  <motion.button
                    whileHover={{ scale: 1.1 }}
                    whileTap={{ scale: 0.9 }}
                    className="p-2 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors"
                  >
                    <UserMinus className="w-4 h-4" />
                  </motion.button>
                </div>
              </motion.div>
            ))}
          </div>

          <button
            className="w-full mt-4 inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl text-slate-300 font-semibold text-sm border border-white/10 transition-all hover:border-white/20 hover:text-white active:scale-[0.97]"
            onClick={() => toast('هذه الميزة قيد التطوير', { icon: '' })}
          >
            <UserPlus className="w-5 h-5" />
            إضافة مساعد جديد
          </button>
        </div>
      </motion.div>
    </motion.div>
  )
}
