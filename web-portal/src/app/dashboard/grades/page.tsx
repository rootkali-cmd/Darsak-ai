'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Plus, Trash2, Loader2, X, Upload, Brain } from 'lucide-react'
import toast from 'react-hot-toast'
import { Section, CountUp } from '@/components/ui'
import { gradesApi, studentsApi, groupsApi } from '@/lib/api'

export default function GradesPage() {
  const [showAddModal, setShowAddModal] = useState(false)
  const [formData, setFormData] = useState({ student_id: '', exam_name: '', subject: '', score: '', max_score: '100', notes: '' })
  const [searchMode, setSearchMode] = useState<'code' | 'name'>('code')
  const [searchValue, setSearchValue] = useState('')
  const [selectedGroup, setSelectedGroup] = useState('')
  const queryClient = useQueryClient()

  const { data: grades, isLoading } = useQuery({ queryKey: ['grades'], queryFn: () => gradesApi.list().then((r) => r.data) })
  const { data: students } = useQuery({
    queryKey: ['students'],
    queryFn: () => studentsApi.list().then((r) => r.data),
    select: (data: any[]) => {
      const seen = new Set<string>()
      return data.filter((s: any) => { const k = s.code || s.id; if (seen.has(k)) return false; seen.add(k); return true })
    },
  })
  const { data: groups } = useQuery({
    queryKey: ['groups'],
    queryFn: () => groupsApi.list().then((r) => r.data),
    select: (data: any[]) => {
      const seen = new Set<string>()
      return data.filter((g: any) => { const k = g.id || g.name; if (seen.has(k)) return false; seen.add(k); return true })
    },
  })
  const { data: gradeStats } = useQuery({ queryKey: ['grade-stats'], queryFn: () => gradesApi.stats().then((r) => r.data) })

  const filteredStudents = students?.filter((s: any) => {
    if (!searchValue) return false
    if (selectedGroup && s.group_id !== selectedGroup) return false
    if (searchMode === 'code') return s.code?.toLowerCase().includes(searchValue.toLowerCase())
    return s.full_name?.toLowerCase().includes(searchValue.toLowerCase())
  })

  const createMutation = useMutation({
    mutationFn: (data: any) => gradesApi.create(data),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['grades', 'grade-stats'] }); setShowAddModal(false); setFormData({ student_id: '', exam_name: '', subject: '', score: '', max_score: '100', notes: '' }); setSearchValue(''); setSelectedGroup(''); toast.success('تم إضافة الدرجة بنجاح ') },
    onError: () => toast.error('فشل إضافة الدرجة'),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => gradesApi.delete(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['grades'] })
      const previous = queryClient.getQueryData(['grades'])
      queryClient.setQueryData(['grades'], (old: any[] | undefined) =>
        old ? old.filter((g: any) => g.id !== id) : [],
      )
      return { previous }
    },
    onSuccess: () => { toast.success('تم حذف الدرجة') },
    onError: (_err, _id, context) => {
      if (context?.previous) queryClient.setQueryData(['grades'], context.previous)
      toast.error('فشل حذف الدرجة')
    },
    onSettled: () => { queryClient.invalidateQueries({ queryKey: ['grades', 'grade-stats'] }) },
  })

  return (
    <div className="space-y-6">

      <Section>
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl md:text-3xl font-bold text-white">الدرجات</h1>
            <p className="text-slate-400 mt-1">إدارة درجات الامتحانات</p>
          </div>
          <div className="flex gap-3 w-full sm:w-auto">
            <button className="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 px-5 py-3 bg-transparent border border-white/[0.08] rounded-xl text-slate-300 font-semibold hover:border-indigo-500/50 hover:text-indigo-400 transition-all duration-200 active:scale-95">
              <Upload className="w-5 h-5" /> رفع CSV
            </button>
            <button
              onClick={() => setShowAddModal(true)}
              className="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 px-5 py-3 bg-gradient-to-r from-indigo-500 to-indigo-400 text-white font-semibold rounded-xl hover:brightness-110 transition-all duration-200 active:scale-95"
            >
              <Plus className="w-5 h-5" /> إضافة درجة
            </button>
          </div>
        </div>
      </Section>

      {gradeStats && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <Section delay={0.1}>
            <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5 text-center">
              <div className="text-4xl font-black text-white">
                <CountUp end={Math.round(gradeStats.average || 0)} suffix="%" />
              </div>
              <p className="text-slate-400 text-sm mt-1">المتوسط</p>
            </div>
          </Section>
          <Section delay={0.2}>
            <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5 text-center">
              <div className="text-4xl font-black text-emerald-400">
                <CountUp end={Math.round(gradeStats.highest || 0)} suffix="%" />
              </div>
              <p className="text-slate-400 text-sm mt-1">أعلى درجة</p>
            </div>
          </Section>
          <Section delay={0.3}>
            <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5 text-center">
              <div className="text-4xl font-black text-red-400">
                <CountUp end={Math.round(gradeStats.lowest || 0)} suffix="%" />
              </div>
              <p className="text-slate-400 text-sm mt-1">أقل درجة</p>
            </div>
          </Section>
          <Section delay={0.4}>
            <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5 text-center">
              <div className="text-4xl font-black text-white">
                <CountUp end={gradeStats.total || 0} />
              </div>
              <p className="text-slate-400 text-sm mt-1">إجمالي الدرجات</p>
            </div>
          </Section>
        </div>
      )}

      <Section delay={0.3}>
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5">
          {isLoading ? (
            <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-indigo-400" /></div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-white/[0.06]">
                    <th className="text-right py-3 px-4 text-slate-500 font-medium">الطالب</th>
                    <th className="text-right py-3 px-4 text-slate-500 font-medium">الامتحان</th>
                    <th className="text-right py-3 px-4 text-slate-500 font-medium">المادة</th>
                    <th className="text-center py-3 px-4 text-slate-500 font-medium">الدرجة</th>
                    <th className="text-center py-3 px-4 text-slate-500 font-medium">النسبة</th>
                    <th className="text-center py-3 px-4 text-slate-500 font-medium">إجراءات</th>
                  </tr>
                </thead>
                <tbody>
                  {grades?.map((grade: any, index: number) => {
                    const student = students?.find((s: any) => s.id === grade.student_id)
                    const percentage = grade.max_score > 0 ? (grade.score / grade.max_score) * 100 : 0
                    const color = percentage >= 85 ? 'text-emerald-400' : percentage >= 50 ? 'text-amber-400' : 'text-red-400'
                    return (
                      <motion.tr key={grade.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: index * 0.05 }} className="border-b border-white/[0.06] hover:bg-white/[0.04] transition-colors">
                        <td className="py-3 px-4">
                          <p className="font-medium text-white">{student?.full_name || '-'}</p>
                          <p className="text-xs text-slate-400 font-mono">{student?.code || ''}</p>
                        </td>
                        <td className="py-3 px-4 text-slate-400">{grade.exam_name}</td>
                        <td className="py-3 px-4 text-slate-400">{grade.subject}</td>
                        <td className="py-3 px-4 text-center font-mono text-white">{grade.score}/{grade.max_score}</td>
                        <td className={`py-3 px-4 text-center font-bold ${color}`}>{percentage.toFixed(1)}%</td>
                        <td className="py-3 px-4 text-center">
                          <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-2 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20" onClick={() => { if (confirm('هل أنت متأكد؟')) deleteMutation.mutate(grade.id) }}>
                            <Trash2 className="w-4 h-4" />
                          </motion.button>
                        </td>
                      </motion.tr>
                    )
                  })}
                </tbody>
              </table>
              {(!grades || grades.length === 0) && <div className="text-center py-12 text-slate-500">لا توجد درجات</div>}
            </div>
          )}
        </div>
      </Section>

      <AnimatePresence>
        {showAddModal && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setShowAddModal(false)}>
            <motion.div initial={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} animate={{ scale: 1, opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} transition={{ type: 'spring', damping: 25 }} className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold text-white">إضافة درجة جديدة</h2>
                <motion.button whileHover={{ scale: 1.1, rotate: 90 }} whileTap={{ scale: 0.9 }} onClick={() => setShowAddModal(false)} className="p-2 rounded-lg hover:bg-white/[0.05] transition-colors text-slate-400"><X className="w-5 h-5" /></motion.button>
              </div>
              <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate({ ...formData, score: parseFloat(formData.score), max_score: parseFloat(formData.max_score) }) }} className="space-y-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">المجموعة</label>
                  <select value={selectedGroup} onChange={(e) => { setSelectedGroup(e.target.value); setSearchValue('') }} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white outline-none focus:border-indigo-500/50 transition-colors">
                    <option value="" className="bg-[#1E293B]">جميع المجموعات</option>
                    {groups?.map((g: any) => <option key={g.id} value={g.id} className="bg-[#1E293B]">{g.name}</option>)}
                  </select>
                </div>
                <div className="flex gap-2">
                  <button type="button" onClick={() => { setSearchMode('code'); setSearchValue('') }} className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${searchMode === 'code' ? 'bg-indigo-500/20 text-indigo-400 border border-indigo-500/30' : 'bg-white/[0.03] text-slate-500 border border-white/[0.06]'}`}>
                    بالكود
                  </button>
                  <button type="button" onClick={() => { setSearchMode('name'); setSearchValue('') }} className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${searchMode === 'name' ? 'bg-indigo-500/20 text-indigo-400 border border-indigo-500/30' : 'bg-white/[0.03] text-slate-500 border border-white/[0.06]'}`}>
                    بالاسم
                  </button>
                </div>
                <input placeholder={searchMode === 'code' ? 'كود الطالب (مثال: STU-A1B)' : 'اسم الطالب'} value={searchValue} onChange={(e) => { setSearchValue(e.target.value); setFormData({ ...formData, student_id: '' }) }} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" dir="ltr" />
                {searchValue && filteredStudents && filteredStudents.length > 0 && (
                  <div className="space-y-1 max-h-32 overflow-y-auto">
                    {filteredStudents.map((s: any) => (
                      <button key={s.id} type="button" onClick={() => { setFormData({ ...formData, student_id: s.id }); setSearchValue('') }} className={`w-full text-start px-4 py-2 rounded-lg text-sm transition-colors ${formData.student_id === s.id ? 'bg-indigo-500/20 text-indigo-400' : 'text-slate-300 hover:bg-white/[0.05]'}`}>
                        {s.full_name} <span className="text-slate-500 font-mono">({s.code})</span>
                      </button>
                    ))}
                  </div>
                )}
                {searchValue && filteredStudents && filteredStudents.length === 0 && (
                  <p className="text-sm text-slate-500">لم يتم العثور على طالب</p>
                )}
                <input placeholder="اسم الامتحان" value={formData.exam_name} onChange={(e) => setFormData({ ...formData, exam_name: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" required />
                <input placeholder="المادة" value={formData.subject} onChange={(e) => setFormData({ ...formData, subject: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" required />
                <div className="grid grid-cols-2 gap-3">
                  <input type="number" placeholder="الدرجة" value={formData.score} onChange={(e) => setFormData({ ...formData, score: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" required min="0" />
                  <input type="number" placeholder="من" value={formData.max_score} onChange={(e) => setFormData({ ...formData, max_score: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" required min="1" />
                </div>
                <textarea placeholder="ملاحظات" value={formData.notes} onChange={(e) => setFormData({ ...formData, notes: e.target.value })} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 outline-none focus:border-indigo-500/50 transition-colors" rows={3} />
                <div className="flex gap-3 pt-2">
                  <button type="submit" className="flex-1 inline-flex items-center justify-center gap-2 px-5 py-3 bg-gradient-to-r from-indigo-500 to-indigo-400 text-white font-semibold rounded-xl hover:brightness-110 transition-all duration-200 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed" disabled={createMutation.isPending || !formData.student_id}>{createMutation.isPending ? 'جاري...' : 'إضافة'}</button>
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
