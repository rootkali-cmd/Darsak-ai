'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Plus, Trash2, Loader2, X, DollarSign, Receipt } from 'lucide-react'
import toast from 'react-hot-toast'
import { CountUp } from '@/components/ui'
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
    const data: any = { paid: !invoice.paid }
    if (!invoice.paid) data.payment_date = new Date().toISOString().split('T')[0]
    queryClient.setQueryData(['invoices'], (old: any[] | undefined) =>
      old ? old.map((i: any) => i.id === invoice.id ? { ...i, ...data } : i) : [],
    )
    updateMutation.mutate({ id: invoice.id, data })
  }

  const glassCard = 'bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl'
  const inputClass = 'w-full px-4 py-3 rounded-xl bg-white/[0.05] border border-white/[0.08] text-white placeholder:text-slate-500 focus:outline-none focus:border-indigo-500/50 transition-colors'

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      className="space-y-6"
    >
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-white">الفواتير</h1>
          <p className="text-slate-400 mt-1">إدارة المدفوعات والفواتير</p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl text-white font-semibold text-sm transition-all hover:opacity-90 active:scale-[0.97] w-full sm:w-auto"
          style={{ background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }}
        >
          <Plus className="w-5 h-5" /> إضافة فاتورة
        </button>
      </div>

      {invoiceStats && (
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
          className="grid grid-cols-1 md:grid-cols-4 gap-4"
        >
          <div className={`${glassCard} p-5 text-center`}>
            <div className="text-2xl font-black text-white">
              <CountUp end={Math.round(invoiceStats.total_amount || 0)} suffix=" ج.م" />
            </div>
            <p className="text-slate-400 text-sm mt-1">إجمالي المبالغ</p>
          </div>
          <div className={`${glassCard} p-5 text-center border-emerald-500/20`}>
            <div className="text-2xl font-black text-emerald-400">
              <CountUp end={Math.round(invoiceStats.paid_amount || 0)} suffix=" ج.م" />
            </div>
            <p className="text-slate-400 text-sm mt-1">المدفوع</p>
          </div>
          <div className={`${glassCard} p-5 text-center border-red-500/20`}>
            <div className="text-2xl font-black text-red-400">
              <CountUp end={Math.round(invoiceStats.unpaid_amount || 0)} suffix=" ج.م" />
            </div>
            <p className="text-slate-400 text-sm mt-1">غير المدفوع</p>
          </div>
          <div className={`${glassCard} p-5 text-center`}>
            <div className="text-2xl font-black text-white">
              <CountUp end={invoiceStats.total_count || 0} />
            </div>
            <p className="text-slate-400 text-sm mt-1">عدد الفواتير</p>
          </div>
        </motion.div>
      )}

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-5`}>
          {isLoading ? (
            <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-indigo-400" /></div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-white/[0.06]">
                    <th className="text-right py-3 px-4 text-slate-400 font-medium text-sm">الطالب</th>
                    <th className="text-right py-3 px-4 text-slate-400 font-medium text-sm">المبلغ</th>
                    <th className="text-right py-3 px-4 text-slate-400 font-medium text-sm">الوصف</th>
                    <th className="text-center py-3 px-4 text-slate-400 font-medium text-sm">الحالة</th>
                    <th className="text-center py-3 px-4 text-slate-400 font-medium text-sm">تاريخ الدفع</th>
                    <th className="text-center py-3 px-4 text-slate-400 font-medium text-sm">إجراءات</th>
                  </tr>
                </thead>
                <tbody>
                  {invoices?.map((invoice: any, index: number) => {
                    const student = students?.find((s: any) => s.id === invoice.student_id)
                    return (
                      <motion.tr
                        key={invoice.id}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        transition={{ delay: index * 0.05 }}
                        className="border-b border-white/[0.04] hover:bg-white/[0.02] transition-colors"
                      >
                        <td className="py-3 px-4">
                          <p className="font-medium text-white">{student?.full_name || '-'}</p>
                          <p className="text-xs text-slate-500 font-mono">{student?.code || ''}</p>
                        </td>
                        <td className="py-3 px-4 font-mono font-bold text-white">{invoice.amount?.toFixed(0)} ج.م</td>
                        <td className="py-3 px-4 text-slate-400 text-sm">{invoice.description || '-'}</td>
                        <td className="py-3 px-4 text-center">
                          <motion.button
                            whileHover={{ scale: 1.05 }}
                            whileTap={{ scale: 0.95 }}
                            onClick={() => togglePaid(invoice)}
                            className={`px-3 py-1 rounded-full text-xs font-medium backdrop-blur-sm ${
                              invoice.paid
                                ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/25'
                                : 'bg-red-500/15 text-red-400 border border-red-500/25'
                            }`}
                          >
                            {invoice.paid ? 'مدفوع' : 'غير مدفوع'}
                          </motion.button>
                        </td>
                        <td className="py-3 px-4 text-center text-slate-400 text-sm">
                          {invoice.payment_date ? formatDate(invoice.payment_date) : '-'}
                        </td>
                        <td className="py-3 px-4 text-center">
                          <motion.button
                            whileHover={{ scale: 1.1 }}
                            whileTap={{ scale: 0.9 }}
                            className="p-1.5 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors"
                            onClick={() => { if (confirm('هل أنت متأكد؟')) deleteMutation.mutate(invoice.id) }}
                          >
                            <Trash2 className="w-4 h-4" />
                          </motion.button>
                        </td>
                      </motion.tr>
                    )
                  })}
                </tbody>
              </table>
              {(!invoices || invoices.length === 0) && (
                <div className="text-center py-12 text-slate-500">لا توجد فواتير</div>
              )}
            </div>
          )}
        </div>
      </motion.div>

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
              className={`${glassCard} p-6 w-full max-w-md max-h-[90vh] overflow-y-auto`}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold text-white">إضافة فاتورة جديدة</h2>
                <motion.button
                  whileHover={{ scale: 1.1, rotate: 90 }}
                  whileTap={{ scale: 0.9 }}
                  onClick={() => setShowAddModal(false)}
                  className="p-2 rounded-lg hover:bg-white/[0.04] text-slate-400"
                >
                  <X className="w-5 h-5" />
                </motion.button>
              </div>
              <form
                onSubmit={(e) => { e.preventDefault(); createMutation.mutate({ ...formData, amount: parseFloat(formData.amount) }) }}
                className="space-y-4"
              >
                <div>
                  <label className="block text-sm text-slate-400 mb-2">المجموعة</label>
                  <select
                    value={selectedGroup}
                    onChange={(e) => { setSelectedGroup(e.target.value); setSearchValue('') }}
                    className={inputClass}
                  >
                    <option value="">جميع المجموعات</option>
                    {groups?.map((g: any) => <option key={g.id} value={g.id}>{g.name}</option>)}
                  </select>
                </div>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => { setSearchMode('code'); setSearchValue('') }}
                    className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
                      searchMode === 'code'
                        ? 'bg-indigo-500/15 text-indigo-300 border border-indigo-500/25'
                        : 'bg-white/[0.03] text-slate-400 border border-white/[0.06]'
                    }`}
                  >
                    بالكود
                  </button>
                  <button
                    type="button"
                    onClick={() => { setSearchMode('name'); setSearchValue('') }}
                    className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
                      searchMode === 'name'
                        ? 'bg-indigo-500/15 text-indigo-300 border border-indigo-500/25'
                        : 'bg-white/[0.03] text-slate-400 border border-white/[0.06]'
                    }`}
                  >
                    بالاسم
                  </button>
                </div>
                <input
                  placeholder={searchMode === 'code' ? 'كود الطالب' : 'اسم الطالب'}
                  value={searchValue}
                  onChange={(e) => { setSearchValue(e.target.value); setFormData({ ...formData, student_id: '' }) }}
                  className={inputClass}
                  dir="ltr"
                />
                {searchValue && filteredStudents && filteredStudents.length > 0 && (
                  <div className="space-y-1 max-h-32 overflow-y-auto">
                    {filteredStudents.map((s: any) => (
                      <button
                        key={s.id}
                        type="button"
                        onClick={() => { setFormData({ ...formData, student_id: s.id }); setSearchValue('') }}
                        className={`w-full text-start px-4 py-2 rounded-lg text-sm transition-colors ${
                          formData.student_id === s.id
                            ? 'bg-indigo-500/15 text-indigo-300'
                            : 'hover:bg-white/[0.03] text-white'
                        }`}
                      >
                        {s.full_name} <span className="text-slate-500 font-mono">({s.code})</span>
                      </button>
                    ))}
                  </div>
                )}
                <input
                  type="number"
                  placeholder="المبلغ"
                  value={formData.amount}
                  onChange={(e) => setFormData({ ...formData, amount: e.target.value })}
                  className={inputClass}
                  required
                  min="0"
                />
                <input
                  placeholder="الوصف"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className={inputClass}
                />
                <input
                  type="date"
                  value={formData.payment_date}
                  onChange={(e) => setFormData({ ...formData, payment_date: e.target.value })}
                  className={inputClass}
                />
                <input
                  placeholder="التوقيع"
                  value={formData.signature}
                  onChange={(e) => setFormData({ ...formData, signature: e.target.value })}
                  className={inputClass}
                />
                <div className="flex gap-3 pt-2">
                  <button
                    type="submit"
                    disabled={createMutation.isPending || !formData.student_id}
                    className="flex-1 inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl text-white font-semibold text-sm transition-all hover:opacity-90 active:scale-[0.97] disabled:opacity-50 disabled:cursor-not-allowed"
                    style={{ background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }}
                  >
                    {createMutation.isPending ? 'جاري...' : 'إضافة'}
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowAddModal(false)}
                    className="flex-1 inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl text-slate-300 font-semibold text-sm border border-white/10 transition-all hover:border-white/20 hover:text-white active:scale-[0.97]"
                  >
                    إلغاء
                  </button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  )
}
