'use client'

import { motion } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Save, Loader2, Eye, EyeOff, Shield, User, Key } from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section } from '@/components/ui'
import { authApi } from '@/lib/api'
import { auth } from '@/lib/auth'

export default function SettingsPage() {
  const [fullName, setFullName] = useState('')
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [showCurrent, setShowCurrent] = useState(false)
  const [showNew, setShowNew] = useState(false)
  const queryClient = useQueryClient()

  const { data: user, isLoading } = useQuery({ queryKey: ['user'], queryFn: () => authApi.getMe().then((r) => r.data) })

  const updateMutation = useMutation({
    mutationFn: (data: { full_name?: string; password?: string }) => authApi.updateMe(data),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['user'] }); toast.success('تم تحديث البيانات بنجاح ') },
    onError: () => toast.error('فشل تحديث البيانات'),
  })

  const handleUpdateProfile = (e: React.FormEvent) => { e.preventDefault(); if (!fullName.trim()) return; updateMutation.mutate({ full_name: fullName }) }
  const handleChangePassword = (e: React.FormEvent) => { e.preventDefault(); if (!currentPassword || !newPassword) { toast.error('يرجى ملء جميع الحقول'); return }; updateMutation.mutate({ password: newPassword }); setCurrentPassword(''); setNewPassword('') }

  if (isLoading) return <div className="flex justify-center py-24"><Loader2 className="w-12 h-12 animate-spin text-[var(--accent)]" /></div>

  return (
    <div className="space-y-6 max-w-2xl">
      <Section>
        <h1 className="text-3xl font-bold">الإعدادات</h1>
        <p className="text-[var(--text-muted)] mt-1">إدارة حسابك وإعدادات النظام</p>
      </Section>

      <Section delay={0.1}>
        <GlassCard>
          <div className="flex items-center gap-3 mb-6">
            <div className="p-3 rounded-xl bg-[rgba(255,0,60,0.1)]"><User className="w-6 h-6 text-[var(--accent)]" /></div>
            <h2 className="text-lg font-bold">المعلومات الشخصية</h2>
          </div>
          <form onSubmit={handleUpdateProfile} className="space-y-4">
            <div>
              <label className="block text-sm text-[var(--text-muted)] mb-2">البريد الإلكتروني</label>
              <input type="email" value={user?.email || ''} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] bg-[rgba(0,0,0,0.03)]" disabled />
            </div>
            <div>
              <label className="block text-sm text-[var(--text-muted)] mb-2">الاسم الكامل</label>
              <input type="text" value={fullName || user?.full_name || ''} onChange={(e) => setFullName(e.target.value)} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" placeholder={user?.full_name} />
            </div>
            <div>
              <label className="block text-sm text-[var(--text-muted)] mb-2">كود المدرس</label>
              <input type="text" value={user?.teacher_code || ''} className="input w-full px-4 py-3 rounded-xl text-[var(--text)] bg-[rgba(0,0,0,0.03)]" disabled />
            </div>
            <NeonButton type="submit" disabled={updateMutation.isPending}>
              <Save className="w-5 h-5" />
              {updateMutation.isPending ? 'جاري الحفظ...' : 'حفظ التغييرات'}
            </NeonButton>
          </form>
        </GlassCard>
      </Section>

      <Section delay={0.2}>
        <GlassCard>
          <div className="flex items-center gap-3 mb-6">
            <div className="p-3 rounded-xl bg-green-500/10"><Key className="w-6 h-6 text-green-500" /></div>
            <h2 className="text-lg font-bold">تغيير كلمة المرور</h2>
          </div>
          <form onSubmit={handleChangePassword} className="space-y-4">
            <div>
              <label className="block text-sm text-[var(--text-muted)] mb-2">كلمة المرور الحالية</label>
              <div className="relative">
                <input type={showCurrent ? 'text' : 'password'} value={currentPassword} onChange={(e) => setCurrentPassword(e.target.value)} className="input w-full px-4 py-3 pr-4 pl-12 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" placeholder="••••••••" />
                <button type="button" onClick={() => setShowCurrent(!showCurrent)} className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)] hover:text-[var(--text)]"><>{showCurrent ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}</></button>
              </div>
            </div>
            <div>
              <label className="block text-sm text-[var(--text-muted)] mb-2">كلمة المرور الجديدة</label>
              <div className="relative">
                <input type={showNew ? 'text' : 'password'} value={newPassword} onChange={(e) => setNewPassword(e.target.value)} className="input w-full px-4 py-3 pr-4 pl-12 rounded-xl text-[var(--text)] placeholder:text-[var(--text-muted)]" placeholder="••••••••" />
                <button type="button" onClick={() => setShowNew(!showNew)} className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)] hover:text-[var(--text)]"><>{showNew ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}</></button>
              </div>
            </div>
            <NeonButton type="submit" disabled={updateMutation.isPending}>
              <Save className="w-5 h-5" />
              {updateMutation.isPending ? 'جاري التغيير...' : 'تغيير كلمة المرور'}
            </NeonButton>
          </form>
        </GlassCard>
      </Section>

      <Section delay={0.3}>
        <GlassCard className="border-red-500/20">
          <div className="flex items-center gap-3 mb-4">
            <div className="p-3 rounded-xl bg-red-500/10"><Shield className="w-6 h-6 text-red-500" /></div>
            <h2 className="text-lg font-bold text-red-500">منطقة الخطر</h2>
          </div>
          <p className="text-[var(--text-muted)] text-sm mb-4">حذف حسابك نهائي. هذا الإجراء لا يمكن التراجع عنه.</p>
          <motion.button whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }} className="px-4 py-2 rounded-xl bg-red-500/10 text-red-500 border border-red-500/20 hover:bg-red-500/20 transition-colors text-sm" onClick={() => { if (confirm('هل أنت متأكد من حذف حسابك؟')) { toast.error('هذه الميزة غير متاحة حالياً') } }}>
            حذف الحساب
          </motion.button>
        </GlassCard>
      </Section>
    </div>
  )
}
