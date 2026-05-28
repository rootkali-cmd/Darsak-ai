'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Plus, Trash2, Edit2, Loader2, X, BookOpen } from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section } from '@/components/ui'
import { groupsApi } from '@/lib/api'

export default function GroupsPage() {
  const [showAddModal, setShowAddModal] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    subject: '',
    level: 'preparatory',
    day_of_week: '',
    time_slot: '',
  })
  const queryClient = useQueryClient()

  const { data: groups, isLoading } = useQuery({
    queryKey: ['groups'],
    queryFn: () => groupsApi.list().then((r) => r.data),
  })

  const createMutation = useMutation({
    mutationFn: (data: any) => groupsApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['groups'] })
      setShowAddModal(false)
      setFormData({ name: '', subject: '', level: 'preparatory', day_of_week: '', time_slot: '' })
      toast.success('تم إضافة المجموعة بنجاح ')
    },
    onError: () => toast.error('فشل إضافة المجموعة'),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => groupsApi.delete(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['groups'] })
      const previous = queryClient.getQueryData(['groups'])
      queryClient.setQueryData(['groups'], (old: any[] | undefined) =>
        old ? old.filter((g: any) => g.id !== id) : [],
      )
      return { previous }
    },
    onSuccess: () => {
      toast.success('تم حذف المجموعة بنجاح')
    },
    onError: (_err, _id, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['groups'], context.previous)
      }
      toast.error('فشل حذف المجموعة')
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['groups'] })
    },
  })

  const levelLabels: Record<string, string> = { preparatory: 'إعدادي', secondary: 'ثانوي' }
  const dayLabels: Record<string, string> = {
    Saturday: 'السبت', Sunday: 'الأحد', Monday: 'الاثنين',
    Tuesday: 'الثلاثاء', Wednesday: 'الأربعاء', Thursday: 'الخميس', Friday: 'الجمعة',
  }

  return (
    <div className="space-y-6">
      <Section>
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl md:text-3xl font-bold">المجموعات <span className="">{groups?.length || 0}</span></h1>
            <p className="text-[var(--text-muted)] mt-1">إدارة مجموعات الدراسة</p>
          </div>
          <NeonButton onClick={() => setShowAddModal(true)} className="w-full sm:w-auto">
            <Plus className="w-5 h-5" />
            إضافة مجموعة
          </NeonButton>
        </div>
      </Section>

      {isLoading ? (
        <div className="flex justify-center py-24"><Loader2 className="w-12 h-12 animate-spin text-[var(--accent)]" /></div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {groups?.map((group: any, index: number) => (
            <Section key={group.id} delay={index * 0.1}>
              <GlassCard delay={index * 0.1} className="group">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <motion.div whileHover={{ scale: 1.1, rotate: 10 }} className="w-12 h-12 rounded-xl bg-[var(--accent)] flex items-center justify-center ">
                      <BookOpen className="w-6 h-6 text-[var(--text)]" />
                    </motion.div>
                    <div>
                      <h3 className="font-bold">{group.name}</h3>
                      <p className="text-sm text-[var(--accent)]">{group.subject}</p>
                    </div>
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-2 rounded-lg bg-red-500/10 text-red-500 hover:bg-red-500/20" onClick={() => { if (confirm('هل أنت متأكد؟')) deleteMutation.mutate(group.id) }}>
                      <Trash2 className="w-4 h-4" />
                    </motion.button>
                  </div>
                </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between"><span className="text-[var(--text-muted)]">المستوى:</span><span>{levelLabels[group.level]}</span></div>
                  <div className="flex justify-between"><span className="text-[var(--text-muted)]">اليوم:</span><span>{dayLabels[group.day_of_week]}</span></div>
                  <div className="flex justify-between"><span className="text-[var(--text-muted)]">الوقت:</span><span className="font-mono" dir="ltr">{group.time_slot}</span></div>
                </div>
              </GlassCard>
            </Section>
          ))}
        </div>
      )}

      {(!groups || groups.length === 0) && !isLoading && (
        <Section><GlassCard className="text-center py-16"><BookOpen className="w-16 h-16 text-[var(--text-muted)] mx-auto mb-4" /><p className="text-[var(--text-muted)] text-lg">لا توجد مجموعات</p></GlassCard></Section>
      )}

      <AnimatePresence>
        {showAddModal && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setShowAddModal(false)}>
            <motion.div initial={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} animate={{ scale: 1, opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} transition={{ type: 'spring', damping: 25 }} className="card rounded-2xl p-6 w-full max-w-md border border-black/10" onClick={(e) => e.stopPropagation()}>
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold">إضافة مجموعة جديدة</h2>
                <motion.button whileHover={{ scale: 1.1, rotate: 90 }} whileTap={{ scale: 0.9 }} onClick={() => setShowAddModal(false)} className="p-2 rounded-lg hover:bg-[rgba(0,0,0,0.02)]"><X className="w-5 h-5" /></motion.button>
              </div>
              <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate(formData) }} className="space-y-4">
                <input placeholder="اسم المجموعة" value={formData.name} onChange={(e) => setFormData({ ...formData, name: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" required />
                <input placeholder="المادة" value={formData.subject} onChange={(e) => setFormData({ ...formData, subject: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" required />
                <select value={formData.level} onChange={(e) => setFormData({ ...formData, level: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)]">
                  <option value="preparatory">إعدادي</option>
                  <option value="secondary">ثانوي</option>
                </select>
                <select value={formData.day_of_week} onChange={(e) => setFormData({ ...formData, day_of_week: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)]" required>
                  <option value="">اختر اليوم</option>
                  <option value="Saturday">السبت</option><option value="Sunday">الأحد</option><option value="Monday">الاثنين</option><option value="Tuesday">الثلاثاء</option><option value="Wednesday">الأربعاء</option><option value="Thursday">الخميس</option>
                </select>
                <input placeholder="الوقت (مثال: 18:00-20:00)" value={formData.time_slot} onChange={(e) => setFormData({ ...formData, time_slot: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" required />
                <div className="flex gap-3 pt-2">
                  <NeonButton type="submit" className="flex-1" disabled={createMutation.isPending}>{createMutation.isPending ? 'جاري...' : 'إضافة'}</NeonButton>
                  <NeonButton variant="outline" type="button" className="flex-1" onClick={() => setShowAddModal(false)}>إلغاء</NeonButton>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
