'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, useMemo } from 'react'
import { Plus, Trash2, Loader2, X, BookOpen, Users } from 'lucide-react'
import toast from 'react-hot-toast'
import { Section } from '@/components/ui'
import { groupsApi, studentsApi } from '@/lib/api'

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

  const { data: students } = useQuery({
    queryKey: ['students'],
    queryFn: () => studentsApi.list().then((r) => r.data),
    select: (data: any[]) => {
      const seen = new Set<string>()
      return data.filter((s: any) => { const k = s.code || s.id; if (seen.has(k)) return false; seen.add(k); return true })
    },
  })

  const studentCountByGroup = useMemo(() => {
    const map: Record<string, number> = {}
    if (students) {
      for (const s of students) {
        if (s.group_id) {
          map[s.group_id] = (map[s.group_id] || 0) + 1
        }
      }
    }
    return map
  }, [students])

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
            <h1 className="text-2xl md:text-3xl font-bold text-white">المجموعات <span className="text-slate-400">{groups?.length || 0}</span></h1>
            <p className="text-slate-400 mt-1">إدارة مجموعات الدراسة</p>
          </div>
          <button
            onClick={() => setShowAddModal(true)}
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-5 py-3 bg-gradient-to-r from-indigo-500 to-indigo-400 text-white font-semibold rounded-xl hover:brightness-110 transition-all duration-200 active:scale-95"
          >
            <Plus className="w-5 h-5" />
            إضافة مجموعة
          </button>
        </div>
      </Section>

      {isLoading ? (
        <div className="flex justify-center py-24"><Loader2 className="w-12 h-12 animate-spin text-indigo-400" /></div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {groups?.map((group: any, index: number) => (
            <Section key={group.id} delay={index * 0.1}>
              <motion.div
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.4, delay: index * 0.1, ease: [0.16, 1, 0.3, 1] }}
                className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5 group"
              >
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <motion.div whileHover={{ scale: 1.1, rotate: 10 }} className="w-12 h-12 rounded-xl bg-gradient-to-br from-indigo-500 to-indigo-400 flex items-center justify-center">
                      <BookOpen className="w-6 h-6 text-white" />
                    </motion.div>
                    <div>
                      <h3 className="font-bold text-white">{group.name}</h3>
                      <p className="text-sm text-indigo-400">{group.subject}</p>
                    </div>
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-2 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20" onClick={() => { if (confirm('هل أنت متأكد؟')) deleteMutation.mutate(group.id) }}>
                      <Trash2 className="w-4 h-4" />
                    </motion.button>
                  </div>
                </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between"><span className="text-slate-400">المستوى:</span><span className="text-slate-400">{levelLabels[group.level]}</span></div>
                  <div className="flex justify-between"><span className="text-slate-400">اليوم:</span><span className="text-slate-400">{dayLabels[group.day_of_week]}</span></div>
                  <div className="flex justify-between"><span className="text-slate-400">الوقت:</span><span className="text-slate-400 font-mono" dir="ltr">{group.time_slot}</span></div>
                  <div className="flex justify-between items-center pt-1 border-t border-white/[0.06] mt-2">
                    <span className="text-slate-400">عدد الطلاب:</span>
                    <span className="font-bold text-indigo-400 flex items-center gap-1"><Users className="w-3.5 h-3.5" />{studentCountByGroup[group.id] || 0}</span>
                  </div>
                </div>
              </motion.div>
            </Section>
          ))}
        </div>
      )}

      {(!groups || groups.length === 0) && !isLoading && (
        <Section>
          <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl text-center py-16">
            <BookOpen className="w-16 h-16 text-slate-500 mx-auto mb-4" />
            <p className="text-slate-400 text-lg">لا توجد مجموعات</p>
          </div>
        </Section>
      )}

      <AnimatePresence>
        {showAddModal && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setShowAddModal(false)}>
            <motion.div initial={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} animate={{ scale: 1, opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} transition={{ type: 'spring', damping: 25 }} className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold text-white">إضافة مجموعة جديدة</h2>
                <motion.button whileHover={{ scale: 1.1, rotate: 90 }} whileTap={{ scale: 0.9 }} onClick={() => setShowAddModal(false)} className="p-2 rounded-lg hover:bg-white/[0.05] transition-colors text-slate-400"><X className="w-5 h-5" /></motion.button>
              </div>
              <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate(formData) }} className="space-y-4">
                <input placeholder="اسم المجموعة" value={formData.name} onChange={(e) => setFormData({ ...formData, name: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" required />
                <input placeholder="المادة" value={formData.subject} onChange={(e) => setFormData({ ...formData, subject: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" required />
                <select value={formData.level} onChange={(e) => setFormData({ ...formData, level: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white outline-none focus:border-indigo-500/50 transition-colors">
                  <option value="preparatory" className="bg-[#1E293B]">إعدادي</option>
                  <option value="secondary" className="bg-[#1E293B]">ثانوي</option>
                </select>
                <select value={formData.day_of_week} onChange={(e) => setFormData({ ...formData, day_of_week: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white outline-none focus:border-indigo-500/50 transition-colors" required>
                  <option value="">اختر اليوم</option>
                  <option value="Saturday" className="bg-[#1E293B]">السبت</option><option value="Sunday" className="bg-[#1E293B]">الأحد</option><option value="Monday" className="bg-[#1E293B]">الاثنين</option><option value="Tuesday" className="bg-[#1E293B]">الثلاثاء</option><option value="Wednesday" className="bg-[#1E293B]">الأربعاء</option><option value="Thursday" className="bg-[#1E293B]">الخميس</option>
                </select>
                <input placeholder="الوقت (مثال: 18:00-20:00)" value={formData.time_slot} onChange={(e) => setFormData({ ...formData, time_slot: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" required />
                <div className="flex gap-3 pt-2">
                  <button type="submit" className="flex-1 inline-flex items-center justify-center gap-2 px-5 py-3 bg-gradient-to-r from-indigo-500 to-indigo-400 text-white font-semibold rounded-xl hover:brightness-110 transition-all duration-200 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed" disabled={createMutation.isPending}>{createMutation.isPending ? 'جاري...' : 'إضافة'}</button>
                  <button type="button" className="flex-1 inline-flex items-center justify-center gap-2 px-5 py-3 bg-transparent border border-white/[0.08] rounded-xl text-slate-300 font-semibold hover:border-indigo-500/50 hover:text-indigo-400 transition-all duration-200 active:scale-95" onClick={() => setShowAddModal(false)}>إلغاء</button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
