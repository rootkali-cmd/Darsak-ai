'use client'

import { motion } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Save, Loader2, Eye, EyeOff, Shield, User, Key, Moon, Sun, Bell, BellOff } from 'lucide-react'
import toast from 'react-hot-toast'
import { authApi } from '@/lib/api'
import { auth } from '@/lib/auth'

export default function SettingsPage() {
  const [fullName, setFullName] = useState('')
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [showCurrent, setShowCurrent] = useState(false)
  const [showNew, setShowNew] = useState(false)
  const [darkMode, setDarkMode] = useState(true)
  const [notificationsEnabled, setNotificationsEnabled] = useState(true)
  const queryClient = useQueryClient()

  const { data: user, isLoading } = useQuery({ queryKey: ['user'], queryFn: () => authApi.getMe().then((r) => r.data) })

  const updateMutation = useMutation({
    mutationFn: (data: { full_name?: string; password?: string; current_password?: string }) => authApi.updateMe(data),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['user'] }); toast.success('تم تحديث البيانات بنجاح ') },
    onError: () => toast.error('فشل تحديث البيانات'),
  })

  const handleUpdateProfile = (e: React.FormEvent) => { e.preventDefault(); if (!fullName.trim()) return; updateMutation.mutate({ full_name: fullName }) }
  const handleChangePassword = (e: React.FormEvent) => { e.preventDefault(); if (!currentPassword || !newPassword) { toast.error('يرجى ملء جميع الحقول'); return }; updateMutation.mutate({ password: newPassword, current_password: currentPassword }); setCurrentPassword(''); setNewPassword('') }

  if (isLoading) return (
    <div className="flex justify-center py-24">
      <Loader2 className="w-12 h-12 animate-spin text-indigo-400" />
    </div>
  )

  const glassCard = 'bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl'
  const inputClass = 'w-full px-4 py-3 rounded-xl bg-white/[0.05] border border-white/[0.08] text-white placeholder:text-slate-500 focus:outline-none focus:border-indigo-500/50 transition-colors'
  const btnGradient = { background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      className="space-y-6 max-w-2xl"
    >
      <div>
        <h1 className="text-3xl font-bold text-white">الإعدادات</h1>
        <p className="text-slate-400 mt-1">إدارة حسابك وإعدادات النظام</p>
      </div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-6`}>
          <div className="flex items-center gap-3 mb-6">
            <div className="p-3 rounded-xl bg-indigo-500/10">
              <User className="w-6 h-6 text-indigo-400" />
            </div>
            <h2 className="text-lg font-bold text-white">المعلومات الشخصية</h2>
          </div>
          <form onSubmit={handleUpdateProfile} className="space-y-4">
            <div>
              <label className="block text-sm text-slate-400 mb-2">البريد الإلكتروني</label>
              <input
                type="email"
                value={user?.email || ''}
                className={`${inputClass} opacity-60 cursor-not-allowed`}
                disabled
              />
            </div>
            <div>
              <label className="block text-sm text-slate-400 mb-2">الاسم الكامل</label>
              <input
                type="text"
                value={fullName || user?.full_name || ''}
                onChange={(e) => setFullName(e.target.value)}
                className={inputClass}
                placeholder={user?.full_name}
              />
            </div>
            <div>
              <label className="block text-sm text-slate-400 mb-2">كود المدرس</label>
              <input
                type="text"
                value={user?.teacher_code || ''}
                className={`${inputClass} opacity-60 cursor-not-allowed`}
                disabled
              />
            </div>
            <button
              type="submit"
              disabled={updateMutation.isPending}
              className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl text-white font-semibold text-sm transition-all hover:opacity-90 active:scale-[0.97] disabled:opacity-50 disabled:cursor-not-allowed"
              style={btnGradient}
            >
              <Save className="w-5 h-5" />
              {updateMutation.isPending ? 'جاري الحفظ...' : 'حفظ التغييرات'}
            </button>
          </form>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-6`}>
          <div className="flex items-center gap-3 mb-6">
            <div className="p-3 rounded-xl bg-emerald-500/10">
              <Key className="w-6 h-6 text-emerald-400" />
            </div>
            <h2 className="text-lg font-bold text-white">تغيير كلمة المرور</h2>
          </div>
          <form onSubmit={handleChangePassword} className="space-y-4">
            <div>
              <label className="block text-sm text-slate-400 mb-2">كلمة المرور الحالية</label>
              <div className="relative">
                <input
                  type={showCurrent ? 'text' : 'password'}
                  value={currentPassword}
                  onChange={(e) => setCurrentPassword(e.target.value)}
                  className={`${inputClass} pr-12`}
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowCurrent(!showCurrent)}
                  className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white transition-colors"
                >
                  {showCurrent ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>
            <div>
              <label className="block text-sm text-slate-400 mb-2">كلمة المرور الجديدة</label>
              <div className="relative">
                <input
                  type={showNew ? 'text' : 'password'}
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className={`${inputClass} pr-12`}
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowNew(!showNew)}
                  className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white transition-colors"
                >
                  {showNew ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>
            <button
              type="submit"
              disabled={updateMutation.isPending}
              className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl text-white font-semibold text-sm transition-all hover:opacity-90 active:scale-[0.97] disabled:opacity-50 disabled:cursor-not-allowed"
              style={btnGradient}
            >
              <Save className="w-5 h-5" />
              {updateMutation.isPending ? 'جاري التغيير...' : 'تغيير كلمة المرور'}
            </button>
          </form>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-6`}>
          <div className="flex items-center gap-3 mb-6">
            <div className="p-3 rounded-xl bg-amber-500/10">
              <Bell className="w-6 h-6 text-amber-400" />
            </div>
            <h2 className="text-lg font-bold text-white">الإشعارات</h2>
          </div>
          <div className="flex items-center justify-between p-4 rounded-xl bg-white/[0.02] border border-white/[0.06]">
            <div>
              <p className="text-sm font-medium text-white">تفعيل الإشعارات</p>
              <p className="text-xs text-slate-400 mt-0.5">استلام إشعارات حول الفواتير والاشتراكات</p>
            </div>
            <button
              onClick={() => setNotificationsEnabled(!notificationsEnabled)}
              className={`relative w-12 h-7 rounded-full transition-colors ${
                notificationsEnabled ? 'bg-indigo-500' : 'bg-white/[0.08]'
              }`}
            >
              <motion.div
                animate={{ x: notificationsEnabled ? 20 : 2 }}
                transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                className="absolute top-1 w-5 h-5 rounded-full bg-white shadow-sm"
              />
            </button>
          </div>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.25, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-6`}>
          <div className="flex items-center gap-3 mb-6">
            <div className="p-3 rounded-xl bg-violet-500/10">
              {darkMode ? <Moon className="w-6 h-6 text-violet-400" /> : <Sun className="w-6 h-6 text-amber-400" />}
            </div>
            <h2 className="text-lg font-bold text-white">المظهر</h2>
          </div>
          <div className="flex items-center justify-between p-4 rounded-xl bg-white/[0.02] border border-white/[0.06]">
            <div>
              <p className="text-sm font-medium text-white">الوضع الليلي</p>
              <p className="text-xs text-slate-400 mt-0.5">تفعيل المظهر الداكن للتطبيق</p>
            </div>
            <button
              onClick={() => setDarkMode(!darkMode)}
              className={`relative w-12 h-7 rounded-full transition-colors ${
                darkMode ? 'bg-indigo-500' : 'bg-white/[0.08]'
              }`}
            >
              <motion.div
                animate={{ x: darkMode ? 20 : 2 }}
                transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                className="absolute top-1 w-5 h-5 rounded-full bg-white shadow-sm"
              />
            </button>
          </div>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-6 border-red-500/20`}>
          <div className="flex items-center gap-3 mb-4">
            <div className="p-3 rounded-xl bg-red-500/10">
              <Shield className="w-6 h-6 text-red-400" />
            </div>
            <h2 className="text-lg font-bold text-red-400">منطقة الخطر</h2>
          </div>
          <p className="text-slate-400 text-sm mb-4">حذف حسابك نهائي. هذا الإجراء لا يمكن التراجع عنه.</p>
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="px-4 py-2 rounded-xl bg-red-500/10 text-red-400 border border-red-500/20 hover:bg-red-500/20 transition-colors text-sm"
            onClick={() => { if (confirm('هل أنت متأكد من حذف حسابك؟')) { toast.error('هذه الميزة غير متاحة حالياً') } }}
          >
            حذف الحساب
          </motion.button>
        </div>
      </motion.div>
    </motion.div>
  )
}
