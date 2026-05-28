'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Plus, Trash2, Loader2, X, DollarSign, Receipt } from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section, CountUp } from '@/components/ui'
import { invoicesApi, studentsApi, groupsApi } from '@/lib/api'
import { formatDate } from '@/lib/utils'

export default function InvoicesPage() {
  const [showAddModal, setShowAddModal] = useState(false)
  const [formData, setFormData] = useState({ student_id: '', amount: '', description: '', paid: false, payment_date: '', signature: '' })
  const [searchMode, setSearchMode] = useState<'code' | 'name'>('code')
  const [searchValue, setSearchValue] = useState('')
  const [selectedGroup, setSelectedGroup] = useState('')
  const queryClient = useQueryClient()

  const { data: invoices, isLoading } = useQuery({ queryKey: ['invoices'], queryFn: () => invoicesApi.list().then((r) => r.data) })
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
  const { data: invoiceStats } = useQuery({ queryKey: ['invoice-stats'], queryFn: () => invoicesApi.stats().then((r) => r.data) })

  const filteredStudents = students?.filter((s: any) => {
    if (!searchValue) return false
    if (selectedGroup && s.group_id !== selectedGroup) return false
    if (searchMode === 'code') return s.code?.toLowerCase().includes(searchValue.toLowerCase())
    return s.full_name?.toLowerCase().includes(searchValue.toLowerCase())
  })

  const createMutation = useMutation({
    mutationFn: (data: any) => invoicesApi.create(data),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['invoices', 'invoice-stats'] }); setShowAddModal(false); setFormData({ student_id: '', amount: '', description: '', paid: false, payment_date: '', signature: '' }); setSearchValue(''); setSelectedGroup(''); toast.success('تم إضافة الفاتورة بنجاح ') },
    onError: () => toast.error('فشل إضافة الفاتورة'),
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => invoicesApi.update(id, data),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['invoices', 'invoice-stats'] }); toast.success('تم تحديث الفاتورة') },
    onError: () => toast.error('فشل تحديث الفاتورة'),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => invoicesApi.delete(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['invoices'] })
      const previous = queryClient.getQueryData(['invoices'])
      queryClient.setQueryData(['invoices'], (old: any[] | undefined) =>
        old ? old.filter((i: any) => i.id !== id) : [],
      )
      return { previous }
    },
    onSuccess: () => { toast.success('تم حذف الفاتورة') },
    onError: (_err, _id, context) => {
      if (context?.previous) queryClient.setQueryData(['invoices'], context.previous)
      toast.error('فشل حذف الفاتورة')
    },
    onSettled: () => { queryClient.invalidateQueries({ queryKey: ['invoices', 'invoice-stats'] }) },
  })

  const togglePaid = (invoice: any) => {
    updateMutation.mutate({ id: invoice.id, data: { paid: !invoice.paid, payment_date: !invoice.paid ? new Date().toISOString().split('T')[0] : null } })
  }

  return (
    <div className="space-y-6">
      <Section>
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl md:text-3xl font-bold">الفواتير</h1>
            <p className="text-[var(--text-muted)] mt-1">إدارة المدفوعات والفواتير</p>
          </div>
          <NeonButton onClick={() => setShowAddModal(true)} className="w-full sm:w-auto"><Plus className="w-5 h-5" /> إضافة فاتورة</NeonButton>
        </div>
      </Section>

      {invoiceStats && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <Section delay={0.1}><GlassCard className="text-center"><div className="text-3xl font-black "><CountUp end={Math.round(invoiceStats.total_amount || 0)} suffix=" ج.م" /></div><p className="text-[var(--text-muted)] text-sm mt-1">إجمالي المبالغ</p></GlassCard></Section>
          <Section delay={0.2}><GlassCard className="text-center border-green-500/20"><div className="text-3xl font-black text-green-500"><CountUp end={Math.round(invoiceStats.paid_amount || 0)} suffix=" ج.م" /></div><p className="text-[var(--text-muted)] text-sm mt-1">المدفوع</p></GlassCard></Section>
          <Section delay={0.3}><GlassCard className="text-center border-red-500/20"><div className="text-3xl font-black text-red-500"><CountUp end={Math.round(invoiceStats.unpaid_amount || 0)} suffix=" ج.م" /></div><p className="text-[var(--text-muted)] text-sm mt-1">غير المدفوع</p></GlassCard></Section>
          <Section delay={0.4}><GlassCard className="text-center"><div className="text-3xl font-black"><CountUp end={invoiceStats.total_count || 0} /></div><p className="text-[var(--text-muted)] text-sm mt-1">عدد الفواتير</p></GlassCard></Section>
        </div>
      )}

      <Section delay={0.3}>
        <GlassCard>
          {isLoading ? (
            <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-[var(--accent)]" /></div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-black/5">
                    <th className="text-right py-3 px-4 text-[var(--text-muted)] font-medium">الطالب</th>
                    <th className="text-right py-3 px-4 text-[var(--text-muted)] font-medium">المبلغ</th>
                    <th className="text-right py-3 px-4 text-[var(--text-muted)] font-medium">الوصف</th>
                    <th className="text-center py-3 px-4 text-[var(--text-muted)] font-medium">الحالة</th>
                    <th className="text-center py-3 px-4 text-[var(--text-muted)] font-medium">تاريخ الدفع</th>
                    <th className="text-center py-3 px-4 text-[var(--text-muted)] font-medium">إجراءات</th>
                  </tr>
                </thead>
                <tbody>
                  {invoices?.map((invoice: any, index: number) => {
                    const student = students?.find((s: any) => s.id === invoice.student_id)
                    return (
                      <motion.tr key={invoice.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: index * 0.05 }} className="border-b border-black/5 hover:bg-[rgba(0,0,0,0.02)] transition-colors">
                        <td className="py-3 px-4"><p className="font-medium">{student?.full_name || '-'}</p><p className="text-xs text-[var(--text-muted)] font-mono">{student?.code || ''}</p></td>
                        <td className="py-3 px-4 font-mono font-bold">{invoice.amount?.toFixed(0)} ج.م</td>
                        <td className="py-3 px-4 text-[var(--text-muted)] text-sm">{invoice.description || '-'}</td>
                        <td className="py-3 px-4 text-center">
                          <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }} onClick={() => togglePaid(invoice)} className={`px-3 py-1 rounded-full text-xs font-medium ${invoice.paid ? 'bg-green-500/20 text-green-500' : 'bg-red-500/20 text-red-500'}`}>
                            {invoice.paid ? 'مدفوع' : 'غير مدفوع'}
                          </motion.button>
                        </td>
                        <td className="py-3 px-4 text-center text-[var(--text-muted)] text-sm">{invoice.payment_date ? formatDate(invoice.payment_date) : '-'}</td>
                        <td className="py-3 px-4 text-center">
                          <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-1.5 rounded-lg bg-red-500/10 text-red-500 hover:bg-red-500/20" onClick={() => { if (confirm('هل أنت متأكد؟')) deleteMutation.mutate(invoice.id) }}>
                            <Trash2 className="w-4 h-4" />
                          </motion.button>
                        </td>
                      </motion.tr>
                    )
                  })}
                </tbody>
              </table>
              {(!invoices || invoices.length === 0) && <div className="text-center py-12 text-[var(--text-muted)]">لا توجد فواتير</div>}
            </div>
          )}
        </GlassCard>
      </Section>

      <AnimatePresence>
        {showAddModal && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setShowAddModal(false)}>
            <motion.div initial={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} animate={{ scale: 1, opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ scale: 0.8, opacity: 0, y: 50, filter: 'blur(10px)' }} transition={{ type: 'spring', damping: 25 }} className="card rounded-2xl p-6 w-full max-w-md border border-black/10 max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold">إضافة فاتورة جديدة</h2>
                <motion.button whileHover={{ scale: 1.1, rotate: 90 }} whileTap={{ scale: 0.9 }} onClick={() => setShowAddModal(false)} className="p-2 rounded-lg hover:bg-[rgba(0,0,0,0.02)]"><X className="w-5 h-5" /></motion.button>
              </div>
              <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate({ ...formData, amount: parseFloat(formData.amount) }) }} className="space-y-4">
                <div>
                  <label className="block text-sm text-[var(--text-muted)] mb-2">المجموعة</label>
                  <select value={selectedGroup} onChange={(e) => { setSelectedGroup(e.target.value); setSearchValue('') }} className="input w-full px-4 py-3 rounded-xl text-[var(--text)]">
                    <option value="">جميع المجموعات</option>
                    {groups?.map((g: any) => <option key={g.id} value={g.id}>{g.name}</option>)}
                  </select>
                </div>
                <div className="flex gap-2">
                  <button type="button" onClick={() => { setSearchMode('code'); setSearchValue('') }} className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${searchMode === 'code' ? 'bg-[rgba(255,0,60,0.2)] text-[var(--accent)] border border-[rgba(255,0,60,0.3)]' : 'bg-[rgba(0,0,0,0.03)] text-[var(--text-muted)] border border-black/5'}`}>
                    بالكود
                  </button>
                  <button type="button" onClick={() => { setSearchMode('name'); setSearchValue('') }} className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${searchMode === 'name' ? 'bg-[rgba(255,0,60,0.2)] text-[var(--accent)] border border-[rgba(255,0,60,0.3)]' : 'bg-[rgba(0,0,0,0.03)] text-[var(--text-muted)] border border-black/5'}`}>
                    بالاسم
                  </button>
                </div>
                <input placeholder={searchMode === 'code' ? 'كود الطالب' : 'اسم الطالب'} value={searchValue} onChange={(e) => { setSearchValue(e.target.value); setFormData({ ...formData, student_id: '' }) }} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" dir="ltr" />
                {searchValue && filteredStudents && filteredStudents.length > 0 && (
                  <div className="space-y-1 max-h-32 overflow-y-auto">
                    {filteredStudents.map((s: any) => (
                      <button key={s.id} type="button" onClick={() => { setFormData({ ...formData, student_id: s.id }); setSearchValue('') }} className={`w-full text-start px-4 py-2 rounded-lg text-sm transition-colors ${formData.student_id === s.id ? 'bg-[rgba(255,0,60,0.2)] text-[var(--accent)]' : 'hover:bg-[rgba(0,0,0,0.02)]'}`}>
                        {s.full_name} <span className="text-[var(--text-muted)] font-mono">({s.code})</span>
                      </button>
                    ))}
                  </div>
                )}
                <input type="number" placeholder="المبلغ" value={formData.amount} onChange={(e) => setFormData({ ...formData, amount: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" required min="0" />
                <input placeholder="الوصف" value={formData.description} onChange={(e) => setFormData({ ...formData, description: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" />
                <input type="date" value={formData.payment_date} onChange={(e) => setFormData({ ...formData, payment_date: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)]" />
                <input placeholder="التوقيع" value={formData.signature} onChange={(e) => setFormData({ ...formData, signature: e.target.value })} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" />
                <div className="flex gap-3 pt-2">
                  <NeonButton type="submit" className="flex-1" disabled={createMutation.isPending || !formData.student_id}>{createMutation.isPending ? 'جاري...' : 'إضافة'}</NeonButton>
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
