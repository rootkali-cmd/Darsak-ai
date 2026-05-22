'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Plus, Trash2, Loader2, X, Upload, GraduationCap, Brain } from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section, CountUp, ProgressRing } from '@/components/ui'
import { gradesApi, studentsApi, groupsApi } from '@/lib/api'

export default function GradesPage() {
  const [showAddModal, setShowAddModal] = useState(false)
  const [formData, setFormData] = useState({ student_id: '', exam_name: '', subject: '', score: '', max_score: '100', notes: '' })
  const [searchMode, setSearchMode] = useState<'code' | 'name'>('code')
  const [searchValue, setSearchValue] = useState('')
  const [selectedGroup, setSelectedGroup] = useState('')
  const queryClient = useQueryClient()

  const { data: grades, isLoading } = useQuery({ queryKey: ['grades'], queryFn: () => gradesApi.list().then((r) => r.data) })
  const { data: students } = useQuery({ queryKey: ['students'], queryFn: () => studentsApi.list().then((r) => r.data) })
  const { data: groups } = useQuery({ queryKey: ['groups'], queryFn: () => groupsApi.list().then((r) => r.data) })
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
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['grades', 'grade-stats'] }); toast.success('تم حذف الدرجة') },
    onError: () => toast.error('فشل حذف الدرجة'),
  })

  return (
    <div className="space-y-6">
      <Section>
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold">الدرجات</h1>
            <p className="text-text-secondary mt-1">إدارة درجات الامتحانات</p>
          </div>
          <div className="flex gap-3">
            <NeonButton variant="glass"><Upload className="w-5 h-5" /> رفع CSV</NeonButton>
            <NeonButton onClick={() => setShowAddModal(true)}><Plus className="w-5 h-5" /> إضافة درجة</NeonButton>
          </div>
        </div>
      </Section>

      {gradeStats && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <Section delay={0.1}><GlassCard className="text-center"><div className="text-4xl font-black neon-text"><CountUp end={Math.round(gradeStats.average || 0)} suffix="%" /></div><p className="text-text-muted text-sm mt-1">المتوسط</p></GlassCard></Section>
          <Section delay={0.2}><GlassCard className="text-center border-accent-green/20"><div className="text-4xl font-black text-accent-green"><CountUp end={Math.round(gradeStats.highest || 0)} suffix="%" /></div><p className="text-text-muted text-sm mt-1">أعلى درجة</p></GlassCard></Section>
          <Section delay={0.3}><GlassCard className="text-center border-danger/20"><div className="text-4xl font-black text-danger"><CountUp end={Math.round(gradeStats.lowest || 0)} suffix="%" /></div><p className="text-text-muted text-sm mt-1">أقل درجة</p></GlassCard></Section>
          <Section delay={0.4}><GlassCard className="text-center"><div className="text-4xl font-black"><CountUp end={gradeStats.total || 0} /></div><p className="text-text-muted text-sm mt-1">إجمالي الدرجات</p></GlassCard></Section>
        </div>
      )}

      <Section delay={0.3}>
        <GlassCard>
          {isLoading ? (
            <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-primary" /></div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-white/5">
                    <th className="text-right py-3 px-4 text-text-muted font-medium">الطالب</th>
                    <th className="text-right py-3 px-4 text-text-muted font-medium">الامتحان</th>
                    <th className="text-right py-3 px-4 text-text-muted font-medium">المادة</th>
                    <th className="text-center py-3 px-4 text-text-muted font-medium">الدرجة</th>
                    <th className="text-center py-3 px-4 text-text-muted font-medium">النسبة</th>
                    <th className="text-center py-3 px-4 text-text-muted font-medium">إجراءات</th>
                  </tr>
                </thead>
                <tbody>
                  {grades?.map((grade: any, index: number) => {
                    const student = students?.find((s: any) => s.id === grade.student_id)
                    const percentage = (grade.score / grade.max_score) * 100
                    const color = percentage >= 85 ? 'text-accent-green' : percentage >= 50 ? 'text-warning' : 'text-danger'
                    return (
                      <motion.tr key={grade.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: index * 0.05 }} className="border-b border-white/5 hover:bg-white/5 transition-colors">
                        <td className="py-3 px-4"><p className="font-medium">{student?.full_name || '-'}</p><p className="text-xs text-text-muted font-mono">{student?.code || ''}</p></td>
                        <td className="py-3 px-4">{grade.exam_name}</td>
                        <td className="py-3 px-4 text-text-secondary">{grade.subject}</td>
                        <td className="py-3 px-4 text-center font-mono">{grade.score}/{grade.max_score}</td>
                        <td className={`py-3 px-4 text-center font-bold ${color}`}>{percentage.toFixed(1)}%</td>
                        <td className="py-3 px-4 text-center">
                          <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-2 rounded-lg bg-danger/10 text-danger hover:bg-danger/20" onClick={() => { if (confirm('هل أنت متأكد؟')) deleteMutation.mutate(grade.id) }}>
                            <Trash2 className="w-4 h-4" />
                          </motion.button>
                        </td>
                      </motion.tr>
                    )
                  })}
                </tbody>
              </table>
              {(!grades || grades.length === 0) && <div className="text-center py-12 text-text-muted">لا توجد درجات</div>}
            </div>
          )}
        </GlassCard>
      </Section>

      <AnimatePresence>
        {showAddModal && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setShowAddModal(false)}>
            <motion.div initial={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} animate={{ scale: 1, opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} transition={{ type: 'spring', damping: 25 }} className="glass-strong rounded-2xl p-6 w-full max-w-md border border-white/10 max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold">إضافة درجة جديدة</h2>
                <motion.button whileHover={{ scale: 1.1, rotate: 90 }} whileTap={{ scale: 0.9 }} onClick={() => setShowAddModal(false)} className="p-2 rounded-lg hover:bg-white/5"><X className="w-5 h-5" /></motion.button>
              </div>
              <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate({ ...formData, score: parseFloat(formData.score), max_score: parseFloat(formData.max_score) }) }} className="space-y-4">
                <div>
                  <label className="block text-sm text-text-muted mb-2">المجموعة</label>
                  <select value={selectedGroup} onChange={(e) => { setSelectedGroup(e.target.value); setSearchValue('') }} className="input-glass w-full px-4 py-3 rounded-xl text-white">
                    <option value="">جميع المجموعات</option>
                    {groups?.map((g: any) => <option key={g.id} value={g.id}>{g.name}</option>)}
                  </select>
                </div>
                <div className="flex gap-2">
                  <button type="button" onClick={() => { setSearchMode('code'); setSearchValue('') }} className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${searchMode === 'code' ? 'bg-primary/20 text-primary border border-primary/30' : 'bg-bg-secondary/50 text-text-muted border border-white/5'}`}>
                    بالكود
                  </button>
                  <button type="button" onClick={() => { setSearchMode('name'); setSearchValue('') }} className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${searchMode === 'name' ? 'bg-primary/20 text-primary border border-primary/30' : 'bg-bg-secondary/50 text-text-muted border border-white/5'}`}>
                    بالاسم
                  </button>
                </div>
                <input placeholder={searchMode === 'code' ? 'كود الطالب (مثال: STU-A1B)' : 'اسم الطالب'} value={searchValue} onChange={(e) => { setSearchValue(e.target.value); setFormData({ ...formData, student_id: '' }) }} className="input-glass w-full px-4 py-3 rounded-xl text-white placeholder:text-text-muted" dir="ltr" />
                {searchValue && filteredStudents && filteredStudents.length > 0 && (
                  <div className="space-y-1 max-h-32 overflow-y-auto">
                    {filteredStudents.map((s: any) => (
                      <button key={s.id} type="button" onClick={() => { setFormData({ ...formData, student_id: s.id }); setSearchValue('') }} className={`w-full text-start px-4 py-2 rounded-lg text-sm transition-colors ${formData.student_id === s.id ? 'bg-primary/20 text-primary' : 'hover:bg-white/5'}`}>
                        {s.full_name} <span className="text-text-muted font-mono">({s.code})</span>
                      </button>
                    ))}
                  </div>
                )}
                {searchValue && filteredStudents && filteredStudents.length === 0 && (
                  <p className="text-sm text-text-muted">لم يتم العثور على طالب</p>
                )}
                <input placeholder="اسم الامتحان" value={formData.exam_name} onChange={(e) => setFormData({ ...formData, exam_name: e.target.value })} className="input-glass w-full px-4 py-3 rounded-xl text-white placeholder:text-text-muted" required />
                <input placeholder="المادة" value={formData.subject} onChange={(e) => setFormData({ ...formData, subject: e.target.value })} className="input-glass w-full px-4 py-3 rounded-xl text-white placeholder:text-text-muted" required />
                <div className="grid grid-cols-2 gap-3">
                  <input type="number" placeholder="الدرجة" value={formData.score} onChange={(e) => setFormData({ ...formData, score: e.target.value })} className="input-glass w-full px-4 py-3 rounded-xl text-white placeholder:text-text-muted" required min="0" />
                  <input type="number" placeholder="من" value={formData.max_score} onChange={(e) => setFormData({ ...formData, max_score: e.target.value })} className="input-glass w-full px-4 py-3 rounded-xl text-white placeholder:text-text-muted" required min="1" />
                </div>
                <textarea placeholder="ملاحظات" value={formData.notes} onChange={(e) => setFormData({ ...formData, notes: e.target.value })} className="input-glass w-full px-4 py-3 rounded-xl text-white placeholder:text-text-muted" rows={3} />
                <div className="flex gap-3 pt-2">
                  <NeonButton type="submit" className="flex-1" disabled={createMutation.isPending || !formData.student_id}>{createMutation.isPending ? 'جاري...' : 'إضافة'}</NeonButton>
                  <NeonButton variant="glass" type="button" className="flex-1" onClick={() => setShowAddModal(false)}>إلغاء</NeonButton>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
