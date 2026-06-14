'use client'

import { motion } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, useRef } from 'react'
import {
  CreditCard,
  Loader2,
  Check,
  Shield,
  Key,
  CheckCircle,
  AlertCircle,
  Phone,
  Upload,
  MessageSquare,
  X,
  Smartphone,
  Copy,
  Fingerprint,
} from 'lucide-react'
import toast from 'react-hot-toast'
import { subscriptionsApi, authApi } from '@/lib/api'
import axios from 'axios'

const API_BASE = (() => {
  const raw = (process.env.NEXT_PUBLIC_API_URL || 'https://darsak-backend.fly.dev').replace(/\/+$/, '')
  return raw.includes('/api') ? raw : `${raw}/api`
})()

const SUPPORT_PHONE = '01031524947'
const SUPPORT_PHONE_INTL = '201031524947'

const plans = [
  {
    id: '3628fdf5-3a79-43c3-8c04-211f31704e07',
    name: 'الباقة الأساسية',
    price: 250,
    label: '250 ج.م/شهر',
    students: 100,
    ai: 100,
    color: '#00f3ff',
    gradient: 'linear-gradient(135deg, #06b6d4, #22d3ee)',
    features: ['حتى 50 طالب', '100 طلب ذكاء اصطناعي/شهر', 'إدارة الدرجات والحضور', 'الفواتير الأساسية', 'QR Code المعلم'],
  },
  {
    id: '56b99f07-ea35-46ae-9af6-16b17078c9a7',
    name: 'الباقة المتقدمة',
    price: 600,
    label: '600 ج.م/شهر',
    students: 400,
    ai: 500,
    color: '#ccff00',
    gradient: 'linear-gradient(135deg, #6366f1, #8b5cf6)',
    popular: true,
    features: ['حتى 500 طالب', '500 طلب ذكاء اصطناعي/شهر', 'إدارة الدرجات والحضور', 'الفواتير المتقدمة', 'QR Code المعلم', 'تصدير التقارير', 'دعم فني متميز'],
  },
  {
    id: '7bc43f3e-d511-4981-ad71-b3c00b637af4',
    name: 'الباقة المتكاملة',
    price: 1100,
    label: '1100 ج.م/شهر',
    students: -1,
    ai: 2000,
    color: '#ff003c',
    gradient: 'linear-gradient(135deg, #f43f5e, #fb7185)',
    features: ['طلاب غير محدود', '2000 طلب ذكاء اصطناعي/شهر', 'جميع المميزات', 'دعم فني متميز', 'أولوية في التحديثات'],
  },
]

export default function SubscriptionPage() {
  const queryClient = useQueryClient()
  const [code, setCode] = useState('')
  const [showPaymentDialog, setShowPaymentDialog] = useState(false)
  const [showMethodDialog, setShowMethodDialog] = useState(false)
  const [selectedPlan, setSelectedPlan] = useState<any>(null)
  const [phoneNumber, setPhoneNumber] = useState('')
  const [screenshot, setScreenshot] = useState<string | null>(null)
  const [pendingPayments, setPendingPayments] = useState<any[]>([])
  const [showSuccessDialog, setShowSuccessDialog] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const { data: subscription, isLoading } = useQuery({
    queryKey: ['subscription'],
    queryFn: () => subscriptionsApi.my().then((r) => r.data),
  })

  const { data: userData } = useQuery({
    queryKey: ['me'],
    queryFn: () => authApi.getMe().then((r) => r.data),
  })

  const { data: notifications } = useQuery({
    queryKey: ['notifications'],
    queryFn: () => subscriptionsApi.notifications().then((r) => r.data),
    refetchInterval: 30000,
  })

  const { data: myPayments } = useQuery({
    queryKey: ['payment-requests'],
    queryFn: () => subscriptionsApi.paymentRequests().then((r) => r.data),
  })

  const activateMutation = useMutation({
    mutationFn: () => subscriptionsApi.activate(code.trim().toUpperCase()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscription'] })
      toast.success('تم تفعيل الاشتراك بنجاح!')
      setCode('')
    },
    onError: (err: any) => toast.error(err.response?.data?.detail || 'فشل تفعيل الكود'),
  })

  const paymentMutation = useMutation({
    mutationFn: async () => {
      const token = localStorage.getItem('access_token')
      const formData = new FormData()
      formData.append('plan_id', selectedPlan.id)
      formData.append('phone_number', phoneNumber)
      formData.append('amount', selectedPlan.price.toString())
      if (screenshot) {
        const blob = await fetch(screenshot).then((r) => r.blob())
        formData.append('screenshot', blob, 'screenshot.jpg')
      }
      return axios.post(`${API_BASE}/subscriptions/payment-request`, formData, {
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'multipart/form-data' },
      })
    },
    onSuccess: () => {
      setShowPaymentDialog(false)
      setShowSuccessDialog(true)
      setScreenshot(null)
      setPhoneNumber('')
      setSelectedPlan(null)
      queryClient.invalidateQueries({ queryKey: ['payment-requests'] })
    },
    onError: (err: any) => toast.error('فشل إرسال الطلب'),
  })

  const isActive = subscription?.is_active === true && subscription?.is_expired !== true
  const daysLeft = subscription?.days_remaining ?? 0
  const isTrial = subscription?.is_trial === true

  const formatDate = (d: string) => {
    if (!d) return '-'
    return new Date(d).toLocaleDateString('ar-EG', { year: 'numeric', month: 'long', day: 'numeric' })
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = (ev) => setScreenshot(ev.target?.result as string)
      reader.readAsDataURL(file)
    }
  }

  const openPayment = (plan: any) => {
    setSelectedPlan(plan)
    setShowMethodDialog(true)
  }

  const chooseWhatsApp = () => {
    const msg = encodeURIComponent(`أريد الاشتراك في ${selectedPlan.name}`)
    window.open(`https://wa.me/${SUPPORT_PHONE_INTL}?text=${msg}`, '_blank')
    setShowMethodDialog(false)
  }

  const chooseDirect = () => {
    setShowMethodDialog(false)
    setShowPaymentDialog(true)
  }

  const unreadCount = notifications?.length || 0

  if (isLoading) {
    return (
      <div className="flex justify-center py-24">
        <Loader2 className="w-12 h-12 animate-spin text-indigo-400" />
      </div>
    )
  }

  const glassCard = 'bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl'
  const inputClass = 'w-full px-4 py-3 rounded-xl bg-white/[0.05] border border-white/[0.08] text-white placeholder:text-slate-500 focus:outline-none focus:border-indigo-500/50 transition-colors'
  const btnGradient = { background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      className="space-y-6"
    >
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-white">الاشتراكات</h1>
          <p className="text-slate-400 mt-1">إدارة اشتراكك وعرض الباقات المتاحة</p>
        </div>
        {unreadCount > 0 && (
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-indigo-500/10 border border-indigo-500/20 text-xs text-indigo-300"
          >
            <MessageSquare className="w-3.5 h-3.5" />
            {unreadCount} إشعار{unreadCount > 1 ? 'ات' : ''}
          </motion.div>
        )}
      </div>

      {notifications && notifications.length > 0 && (
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.05, ease: [0.16, 1, 0.3, 1] }}
          className="space-y-2"
        >
          {notifications.map((n: any) => {
            const isSuccess = n.type === 'success'
            const isError = n.type === 'error'
            const bg = isSuccess ? 'bg-emerald-500/5' : isError ? 'bg-red-500/5' : 'bg-white/[0.03]'
            const border = isSuccess ? 'border-emerald-500/20' : isError ? 'border-red-500/20' : 'border-white/[0.08]'
            return (
              <motion.div
                key={n.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                className={`${bg} ${border} backdrop-blur-sm rounded-2xl p-4 border`}
              >
                <div className="flex items-start gap-3">
                  {isSuccess
                    ? <CheckCircle className="w-5 h-5 text-emerald-400 mt-0.5" />
                    : isError
                    ? <AlertCircle className="w-5 h-5 text-red-400 mt-0.5" />
                    : <MessageSquare className="w-5 h-5 text-indigo-400 mt-0.5" />
                  }
                  <div className="flex-1">
                    <p className="font-bold text-sm text-white">{n.title}</p>
                    <p className="text-sm text-slate-400 mt-1 whitespace-pre-wrap">{n.body}</p>
                  </div>
                </div>
              </motion.div>
            )
          })}
        </motion.div>
      )}

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-6`}>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <Shield className="w-6 h-6 text-indigo-400" />
              <h2 className="text-xl font-bold text-white">الاشتراك الحالي</h2>
            </div>
            {isActive ? (
              <span className="flex items-center gap-2 text-xs px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/25 text-emerald-400">
                <CheckCircle className="w-3.5 h-3.5" />
                نشط
              </span>
            ) : (
              <span className="flex items-center gap-2 text-xs px-3 py-1.5 rounded-full bg-red-500/10 border border-red-500/25 text-red-400">
                <AlertCircle className="w-3.5 h-3.5" />
                منتهي — اشترك في باقة
              </span>
            )}
          </div>

          {subscription ? (
            <>
              <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div className={`${glassCard} p-4`}>
                  <p className="text-xs text-slate-400 mb-1">الباقة</p>
                  <p className="text-lg font-bold text-white">{subscription.plan_name || '-'}</p>
                  {isTrial && (
                    <span className="inline-block mt-1 px-2 py-0.5 text-[10px] font-bold rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-400">
                      نسخة تجريبية
                    </span>
                  )}
                </div>
                <div className={`${glassCard} p-4`}>
                  <p className="text-xs text-slate-400 mb-1">تاريخ البدء</p>
                  <p className="text-sm font-bold text-white">{formatDate(subscription.activated_at)}</p>
                </div>
                <div className={`${glassCard} p-4`}>
                  <p className="text-xs text-slate-400 mb-1">تاريخ الانتهاء</p>
                  <p className="text-sm font-bold text-white">{formatDate(subscription.expires_at)}</p>
                  {daysLeft > 0 && (
                    <p className={`text-xs mt-1 ${daysLeft < 3 ? 'text-red-400' : 'text-emerald-400'}`}>
                      {daysLeft} يوم متبقي
                    </p>
                  )}
                </div>
                <div className={`${glassCard} p-4`}>
                  <p className="text-xs text-slate-400 mb-1">الطلاب</p>
                  <p className="text-sm font-bold text-white">
                    {subscription.plan?.max_students === -1 ? 'غير محدود' : `${subscription.plan?.max_students || 0}`}
                  </p>
                </div>
              </div>
              {daysLeft > 0 && (
                <div className="mt-4">
                  <div className="flex items-center justify-between text-xs mb-2">
                    <span className="text-slate-400">الأيام المتبقية</span>
                    <span className="text-white font-bold">{daysLeft} يوم</span>
                  </div>
                  <div className="w-full h-2 rounded-full bg-white/[0.05] overflow-hidden">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${Math.min(100, Math.max(0, (daysLeft / 30) * 100))}%` }}
                      transition={{ duration: 1, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
                      className="h-full rounded-full"
                      style={{ background: daysLeft < 7 ? 'linear-gradient(90deg, #f43f5e, #fb7185)' : 'linear-gradient(90deg, #6366f1, #8b5cf6)' }}
                    />
                  </div>
                </div>
              )}
            </>
          ) : (
            <p className="text-slate-400 text-sm py-4">لا يوجد اشتراك نشط حالياً. اختر باقة للاشتراك أو استخدم كود تفعيل.</p>
          )}
        </div>
      </motion.div>

      {userData && (
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
        >
          <div className={`${glassCard} p-6`}>
            <div className="flex items-center gap-3 mb-4">
              <Fingerprint className="w-5 h-5 text-indigo-400" />
              <h2 className="text-xl font-bold text-white">معرف الحساب</h2>
            </div>
            <p className="text-xs text-slate-400 mb-2">استخدم هذا المعرف عند التواصل مع الدعم الفني</p>
            <div className="flex items-center gap-2">
              <code className="flex-1 px-4 py-3 rounded-xl bg-white/[0.03] border border-white/[0.08] text-sm font-mono text-white" dir="ltr" style={{ letterSpacing: '1px' }}>
                {userData.id}
              </code>
              <button
                onClick={() => { navigator.clipboard.writeText(userData.id); toast.success('تم نسخ المعرف') }}
                className="p-3 rounded-xl bg-white/[0.03] border border-white/[0.08] hover:border-indigo-500/30 transition-colors text-slate-400 hover:text-white"
                title="نسخ المعرف"
              >
                <Copy className="w-4 h-4" />
              </button>
            </div>
          </div>
        </motion.div>
      )}

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className={`${glassCard} p-6`}>
          <div className="flex items-center gap-3 mb-4">
            <Key className="w-5 h-5 text-indigo-400" />
            <h2 className="text-xl font-bold text-white">تفعيل كود اشتراك</h2>
          </div>
          <div className="flex gap-3">
            <input
              type="text"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="XXXX-XXXX-XXXX-XXXX"
              className={`flex-1 ${inputClass} uppercase`}
              style={{ fontFamily: 'var(--font-mono, monospace)', letterSpacing: '2px' }}
            />
            <button
              onClick={() => activateMutation.mutate()}
              disabled={code.trim().length < 16 || activateMutation.isPending}
              className="px-6 py-3 rounded-xl text-sm font-bold text-white transition-all hover:opacity-90 active:scale-[0.97] disabled:opacity-30"
              style={btnGradient}
            >
              {activateMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : 'تفعيل'}
            </button>
          </div>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
      >
        <h2 className="text-xl font-bold text-white mb-4">الباقات المتاحة</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {plans.map((plan, i) => (
            <motion.div
              key={plan.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 * i }}
              className={`relative p-6 ${glassCard} ${
                plan.popular ? 'border-indigo-500/30 shadow-[0_0_30px_rgba(99,102,241,0.1)]' : ''
              }`}
            >
              {plan.popular && (
                <div
                  className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 text-[10px] font-bold text-white rounded-full"
                  style={{ background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }}
                >
                  الأكثر طلباً
                </div>
              )}
              <h3 className="text-lg font-bold mb-2 text-white">{plan.name}</h3>
              <p className="text-2xl font-bold mb-4 text-white">{plan.label}</p>
              <div className="space-y-2 mb-6">
                {plan.features.map((f, fi) => (
                  <div key={fi} className="flex items-center gap-2 text-sm text-slate-400">
                    <Check className="w-3.5 h-3.5 text-indigo-400 flex-shrink-0" />
                    <span>{f}</span>
                  </div>
                ))}
              </div>
              <button
                onClick={() => openPayment(plan)}
                className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold text-white transition-all hover:opacity-90 active:scale-[0.97]"
                style={{ background: plan.gradient }}
              >
                <CreditCard className="w-3.5 h-3.5" />
                اشتراك الآن
              </button>
            </motion.div>
          ))}
        </div>
      </motion.div>

      {showMethodDialog && selectedPlan && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm" onClick={() => setShowMethodDialog(false)}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className={`w-full max-w-md p-6 ${glassCard}`}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-bold text-white">اختر طريقة الدفع</h3>
              <button onClick={() => setShowMethodDialog(false)} className="text-slate-400 hover:text-white transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-sm text-slate-400 mb-4">
              {selectedPlan.name} - {selectedPlan.label}
            </p>
            <div className="space-y-3">
              <button
                onClick={chooseWhatsApp}
                className="w-full flex items-center gap-4 p-4 rounded-xl bg-white/[0.03] border border-white/[0.08] hover:border-indigo-500/30 transition-colors text-right"
              >
                <MessageSquare className="w-6 h-6 text-indigo-400" />
                <div>
                  <p className="font-bold text-sm text-white">دعم عبر واتساب</p>
                  <p className="text-xs text-slate-400">{SUPPORT_PHONE}</p>
                </div>
              </button>
              <button
                onClick={chooseDirect}
                className="w-full flex items-center gap-4 p-4 rounded-xl bg-white/[0.03] border border-white/[0.08] hover:border-indigo-500/30 transition-colors text-right"
              >
                <Smartphone className="w-6 h-6 text-indigo-400" />
                <div>
                  <p className="font-bold text-sm text-white">دفع مباشر</p>
                  <p className="text-xs text-slate-400">حول عبر فودافون كاش وأرسل الإيصال</p>
                </div>
              </button>
            </div>
          </motion.div>
        </div>
      )}

      {showPaymentDialog && selectedPlan && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm" onClick={() => { setShowPaymentDialog(false); setScreenshot(null); setPhoneNumber('') }}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className={`w-full max-w-md p-6 ${glassCard}`}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-bold text-white">دفع عبر فودافون كاش</h3>
              <button onClick={() => { setShowPaymentDialog(false); setScreenshot(null); setPhoneNumber('') }} className="text-slate-400 hover:text-white transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-indigo-500/5 border border-indigo-500/20">
                <p className="text-xs text-slate-400 mb-1">حول إلى رقم فودافون كاش</p>
                <p className="text-xl font-bold text-indigo-300" dir="ltr" style={{ fontFamily: 'var(--font-mono, monospace)', letterSpacing: '3px' }}>
                  {SUPPORT_PHONE}
                </p>
              </div>

              <div>
                <label className="text-xs text-slate-400 mb-1 block">رقم هاتفك المحول منه</label>
                <div className="flex">
                  <span className="flex items-center px-3 rounded-r-xl bg-white/[0.03] border border-l-0 border-white/[0.08] text-slate-400 text-sm">+20</span>
                  <input
                    type="tel"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value.replace(/[^0-9]/g, ''))}
                    placeholder="10XXXXXXXX"
                    className={`flex-1 ${inputClass} rounded-l-xl`}
                    dir="ltr"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs text-slate-400 mb-1 block">المبلغ</label>
                <div className="flex items-center gap-2 px-4 py-3 rounded-xl bg-white/[0.02] border border-white/[0.08]">
                  <span className="text-lg font-bold text-white">{selectedPlan.price}</span>
                  <span className="text-slate-400 text-sm">ج.م</span>
                </div>
              </div>

              <div>
                <label className="text-xs text-slate-400 mb-1 block">صورة الإيصال (اختياري)</label>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleFileChange}
                  className="hidden"
                />
                <button
                  onClick={() => fileInputRef.current?.click()}
                  className="w-full flex items-center justify-center gap-2 p-4 rounded-xl bg-white/[0.02] border border-dashed border-white/[0.08] hover:border-indigo-500/30 transition-colors text-sm text-slate-400"
                >
                  {screenshot ? (
                    <>
                      <CheckCircle className="w-5 h-5 text-emerald-400" />
                      تم اختيار الصورة
                    </>
                  ) : (
                    <>
                      <Upload className="w-5 h-5" />
                      اضغط لرفع صورة الإيصال
                    </>
                  )}
                </button>
                {screenshot && (
                  <div className="mt-2 relative">
                    <img src={screenshot} alt="Screenshot" className="w-full h-40 object-cover rounded-xl border border-white/[0.08]" />
                    <button
                      onClick={() => setScreenshot(null)}
                      className="absolute top-2 right-2 p-1 bg-black/60 rounded-lg"
                    >
                      <X className="w-4 h-4 text-white" />
                    </button>
                  </div>
                )}
              </div>

              <button
                onClick={() => paymentMutation.mutate()}
                disabled={phoneNumber.length < 10 || paymentMutation.isPending}
                className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold text-white transition-all hover:opacity-90 active:scale-[0.97] disabled:opacity-30"
                style={btnGradient}
              >
                {paymentMutation.isPending ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <>
                    <Send className="w-4 h-4" />
                    تأكيد
                  </>
                )}
              </button>
            </div>
          </motion.div>
        </div>
      )}

      {showSuccessDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm" onClick={() => setShowSuccessDialog(false)}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className={`w-full max-w-md p-6 ${glassCard} text-center`}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-16 h-16 mx-auto mb-4 flex items-center justify-center rounded-full border-2 border-emerald-500/30 bg-emerald-500/5">
              <CheckCircle className="w-8 h-8 text-emerald-400" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">تم الإرسال بنجاح!</h3>
            <div className="space-y-2 text-sm text-slate-400 mb-6">
              <p>سيتم التحقق من الدفع خلال 10 دقائق</p>
              <p>وبحد أقصى ساعتين</p>
              <div className="pt-3 border-t border-white/[0.08] mt-3">
                <p>لو فيه مشكلة أو تأخير</p>
                <p>تواصل معانا عبر الواتساب:</p>
              </div>
            </div>
            <a
              href={`https://wa.me/${SUPPORT_PHONE_INTL}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-6 py-3 rounded-xl text-sm font-bold text-white transition-all hover:opacity-90"
              style={btnGradient}
              onClick={() => setShowSuccessDialog(false)}
            >
              <MessageSquare className="w-4 h-4" />
              {SUPPORT_PHONE}
            </a>
          </motion.div>
        </div>
      )}
    </motion.div>
  )
}

function Send(props: any) { return <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}><line x1="22" y1="2" x2="11" y2="13" /><polygon points="22 2 15 22 11 13 2 9 22 2" /></svg> }
