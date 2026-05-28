'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Search, Plus, Eye, Trash2, Edit2, Loader2, X, User } from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section, CountUp } from '@/components/ui'
import { studentsApi } from '@/lib/api'
import { formatDate } from '@/lib/utils'

export default function StudentsPage() {
  const [search, setSearch] = useState('')
  const [showAddModal, setShowAddModal] = useState(false)
  const [formData, setFormData] = useState({
    full_name: '',
    phone: '',
    parent_phone: '',
    grade_level: '',
    pin: '',
  })
  const queryClient = useQueryClient()

  const { data: students, isLoading } = useQuery({
    queryKey: ['students', search],
    queryFn: () => studentsApi.list({ search: search || undefined }).then((r) => r.data),
    select: (data: any[]) => {
      const seen = new Set<string>()
      return data.filter((s: any) => {
        const key = s.code || s.id
        if (seen.has(key)) return false
        seen.add(key)
        return true
      })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => studentsApi.delete(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['students', search] })
      const previous = queryClient.getQueryData(['students', search])
      queryClient.setQueryData(['students', search], (old: any[] | undefined) =>
        old ? old.filter((s: any) => s.id !== id) : [],
      )
      return { previous }
    },
    onSuccess: () => {
      toast.success('تم حذف الطالب بنجاح')
    },
    onError: (_err, _id, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['students', search], context.previous)
      }
      toast.error('فشل حذف الطالب')
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['students'] })
    },
  })

  const createMutation = useMutation({
    mutationFn: (data: any) => studentsApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['students'] })
      setShowAddModal(false)
      setFormData({ full_name: '', phone: '', parent_phone: '', grade_level: '', pin: '' })
      toast.success('تم إضافة الطالب بنجاح 🎉')
    },
    onError: () => toast.error('فشل إضافة الطالب'),
  })

  return (
    <div className="space-y-6">
      {/* Header */}
      <Section>
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl md:text-3xl font-bold">
              الطلاب <span className="">{students?.length || 0}</span>
            </h1>
            <p className="text-[var(--text-muted)] mt-1">إدارة قائمة الطلاب</p>
          </div>
          <NeonButton onClick={() => setShowAddModal(true)} className="w-full sm:w-auto">
            <Plus className="w-5 h-5" />
            إضافة طالب
          </NeonButton>
        </div>
      </Section>

      {/* Search */}
      <Section delay={0.1}>
        <GlassCard className="p-4">
          <div className="relative">
            <Search className="absolute right-4 top-1/2 -translate-y-1/2 w-5 h-5 text-[var(--text-muted)]" />
            <input
              type="text"
              placeholder="بحث بالاسم أو الكود..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="input w-full pr-12 pl-4 py-4 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]"
            />
          </div>
        </GlassCard>
      </Section>

      {/* Students Grid */}
      {isLoading ? (
        <div className="flex justify-center py-24">
          <Loader2 className="w-12 h-12 animate-spin text-[var(--accent)]" />
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {students?.map((student: any, index: number) => (
            <Section key={student.id} delay={index * 0.05}>
              <GlassCard delay={index * 0.05} className="group">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <motion.div
                      whileHover={{ scale: 1.1, rotate: 10 }}
                      className="w-12 h-12 rounded-xl bg-[var(--accent)] flex items-center justify-center "
                    >
                      <span className="text-[var(--text)] font-bold text-lg">{student.full_name.charAt(0)}</span>
                    </motion.div>
                    <div>
                      <h3 className="font-bold">{student.full_name}</h3>
                      <p className="text-sm text-[var(--text-muted)] font-mono">{student.code}</p>
                    </div>
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <motion.button
                      whileHover={{ scale: 1.1 }}
                      whileTap={{ scale: 0.9 }}
                      className="p-2 rounded-lg bg-[rgba(255,0,60,0.1)] text-[var(--accent)] hover:bg-[rgba(255,0,60,0.2)]"
                      onClick={() => window.location.href = `/dashboard/students/${student.id}`}
                    >
                      <Eye className="w-4 h-4" />
                    </motion.button>
                    <motion.button
                      whileHover={{ scale: 1.1 }}
                      whileTap={{ scale: 0.9 }}
                      className="p-2 rounded-lg bg-red-500/10 text-red-500 hover:bg-red-500/20"
                      onClick={() => {
                        if (confirm('هل أنت متأكد من حذف هذا الطالب؟')) {
                          deleteMutation.mutate(student.id)
                        }
                      }}
                    >
                      <Trash2 className="w-4 h-4" />
                    </motion.button>
                  </div>
                </div>
                <div className="space-y-2 text-sm">
                  {student.phone && (
                    <div className="flex justify-between">
                      <span className="text-[var(--text-muted)]">الهاتف:</span>
                      <span className="font-mono" dir="ltr">{student.phone}</span>
                    </div>
                  )}
                  {student.grade_level && (
                    <div className="flex justify-between">
                      <span className="text-[var(--text-muted)]">الصف:</span>
                      <span>{student.grade_level}</span>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <span className="text-[var(--text-muted)]">تاريخ الإضافة:</span>
                    <span>{formatDate(student.created_at)}</span>
                  </div>
                </div>
              </GlassCard>
            </Section>
          ))}
        </div>
      )}

      {(!students || students.length === 0) && !isLoading && (
        <Section>
          <GlassCard className="text-center py-16">
            <User className="w-16 h-16 text-[var(--text-muted)] mx-auto mb-4" />
            <p className="text-[var(--text-muted)] text-lg">لا يوجد طلاب</p>
            <p className="text-[var(--text-muted)] text-sm mt-2">أضف طالبك الأول للبدء</p>
          </GlassCard>
        </Section>
      )}

      {/* Add Modal */}
      <AnimatePresence>
        {showAddModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
            onClick={() => setShowAddModal(false)}
          >
            <motion.div
              initial={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }}
              animate={{ scale: 1, opacity: 1, y: 0, filter: 'blur(0px)' }}
              exit={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }}
              transition={{ type: 'spring', damping: 25 }}
              className="card rounded-2xl p-6 w-full max-w-md border border-black/10"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold">إضافة طالب جديد</h2>
                <motion.button
                  whileHover={{ scale: 1.1, rotate: 90 }}
                  whileTap={{ scale: 0.9 }}
                  onClick={() => setShowAddModal(false)}
                  className="p-2 rounded-lg hover:bg-[rgba(0,0,0,0.02)] transition-colors"
                >
                  <X className="w-5 h-5" />
                </motion.button>
              </div>

              <form
                onSubmit={(e) => {
                  e.preventDefault()
                  createMutation.mutate(formData)
                }}
                className="space-y-4"
              >
                <input
                  placeholder="الاسم الكامل"
                  value={formData.full_name}
                  onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
                  className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]"
                  required
                />
                <input
                  placeholder="رقم الهاتف"
                  value={formData.phone}
                  onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                  className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]"
                  dir="ltr"
                />
                <input
                  placeholder="رقم ولي الأمر"
                  value={formData.parent_phone}
                  onChange={(e) => setFormData({ ...formData, parent_phone: e.target.value })}
                  className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]"
                  dir="ltr"
                />
                <input
                  placeholder="الصف الدراسي"
                  value={formData.grade_level}
                  onChange={(e) => setFormData({ ...formData, grade_level: e.target.value })}
                  className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]"
                />
                <input
                  placeholder="PIN (6-8 أحرف وأرقام)"
                  value={formData.pin}
                  onChange={(e) => setFormData({ ...formData, pin: e.target.value.toUpperCase() })}
                  className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]"
                  maxLength={8}
                  dir="ltr"
                />
                <div className="flex gap-3 pt-2">
                  <NeonButton type="submit" className="flex-1" disabled={createMutation.isPending}>
                    {createMutation.isPending ? 'جاري الإضافة...' : 'إضافة'}
                  </NeonButton>
                  <NeonButton variant="outline" type="button" className="flex-1" onClick={() => setShowAddModal(false)}>
                    إلغاء
                  </NeonButton>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
