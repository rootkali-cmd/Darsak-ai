'use client'

import { motion } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, useRef } from 'react'
import {
  CreditCard,
  Loader2,
  Check,
  Users,
  Brain,
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
import { GlassCard, Section } from '@/components/ui'
import { subscriptionsApi, authApi } from '@/lib/api'
import axios from 'axios'

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api'

const SUPPORT_PHONE = '01031524947'
const SUPPORT_PHONE_INTL = '201031524947'

const plans = [
  {
    id: '3628fdf5-3a79-43c3-8c04-211f31704e07',
    name: 'الباقة الأساسية',
    price: 199,
    label: '199 ج.م/شهر',
    students: 50,
    ai: 100,
    color: '#00f3ff',
    features: ['حتى 50 طالب', '100 طلب ذكاء اصطناعي/شهر', 'إدارة الدرجات والحضور', 'الفواتير الأساسية', 'QR Code المعلم'],
  },
  {
    id: '56b99f07-ea35-46ae-9af6-16b17078c9a7',
    name: 'الباقة المتقدمة',
    price: 499,
    label: '499 ج.م/شهر',
    students: 500,
    ai: 500,
    color: '#ccff00',
    popular: true,
    features: ['حتى 500 طالب', '500 طلب ذكاء اصطناعي/شهر', 'إدارة الدرجات والحضور', 'الفواتير المتقدمة', 'QR Code المعلم', 'تصدير التقارير', 'دعم فني متميز'],
  },
  {
    id: '7bc43f3e-d511-4981-ad71-b3c00b637af4',
    name: 'الباقة الغير محدودة',
    price: 999,
    label: '999 ج.م/شهر',
    students: 0,
    ai: 2000,
    color: '#ff003c',
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

  const isActive = subscription?.active && !subscription?.expired

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
    return <div className="flex justify-center py-24"><Loader2 className="w-12 h-12 animate-spin text-[var(--accent)]" /></div>
  }

  return (
    <div className="space-y-6">
      <Section>
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold">الاشتراكات</h1>
            <p className="text-text-secondary mt-1">إدارة اشتراكك وعرض الباقات المتاحة</p>
          </div>
          {unreadCount > 0 && (
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              className="flex items-center gap-2 px-4 py-2 border border-[var(--accent-2)] text-xs"
            >
              <MessageSquare className="w-3.5 h-3.5 text-[var(--accent-2)]" />
              {unreadCount} إشعار{unreadCount > 1 ? 'ات' : ''}
            </motion.div>
          )}
        </div>
      </Section>

      {/* Notifications */}
      {notifications && notifications.length > 0 && (
        <Section delay={0.05}>
          <div className="space-y-2">
            {notifications.map((n: any) => (
              <motion.div
                key={n.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                className="p-4 border border-[var(--border)]"
                style={{
                  background: n.type === 'success'
                    ? 'rgba(0,243,255,0.05)'
                    : n.type === 'error'
                    ? 'rgba(255,0,60,0.05)'
                    : 'var(--card-bg)',
                  borderColor: n.type === 'success'
                    ? 'rgba(0,243,255,0.3)'
                    : n.type === 'error'
                    ? 'rgba(255,0,60,0.3)'
                    : 'var(--border)',
                }}
              >
                <div className="flex items-start gap-3">
                  {n.type === 'success'
                    ? <CheckCircle className="w-5 h-5 text-[var(--success)] mt-0.5" />
                    : n.type === 'error'
                    ? <AlertCircle className="w-5 h-5 text-[var(--danger)] mt-0.5" />
                    : <MessageSquare className="w-5 h-5 text-[var(--accent-2)] mt-0.5" />
                  }
                  <div className="flex-1">
                    <p className="font-bold text-sm text-white">{n.title}</p>
                    <p className="text-sm text-text-secondary mt-1 whitespace-pre-wrap">{n.body}</p>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </Section>
      )}

      {/* Current Subscription */}
      <Section delay={0.1}>
        <GlassCard>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <Shield className="w-6 h-6 text-[var(--accent)]" />
              <h2 className="text-xl font-bold">الاشتراك الحالي</h2>
            </div>
            {isActive ? (
              <span className="flex items-center gap-2 text-xs px-3 py-1.5 border border-[var(--success)] text-[var(--success)]">
                <CheckCircle className="w-3.5 h-3.5" />
                نشط
              </span>
            ) : (
              <span className="flex items-center gap-2 text-xs px-3 py-1.5 border border-[var(--danger)] text-[var(--danger)]">
                <AlertCircle className="w-3.5 h-3.5" />
                غير نشط
              </span>
            )}
          </div>

          {subscription ? (
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="p-4 border border-[var(--border)]">
                <p className="text-xs text-text-muted mb-1">الباقة</p>
                <p className="text-lg font-bold">{subscription.plan_name || '-'}</p>
              </div>
              <div className="p-4 border border-[var(--border)]">
                <p className="text-xs text-text-muted mb-1">تاريخ البدء</p>
                <p className="text-sm font-bold">{formatDate(subscription.start_date)}</p>
              </div>
              <div className="p-4 border border-[var(--border)]">
                <p className="text-xs text-text-muted mb-1">تاريخ الانتهاء</p>
                <p className="text-sm font-bold">{formatDate(subscription.end_date)}</p>
              </div>
              <div className="p-4 border border-[var(--border)]">
                <p className="text-xs text-text-muted mb-1">الطلاب</p>
                <p className="text-sm font-bold">
                  {subscription.max_students === -1 ? 'غير محدود' : `${subscription.student_count || 0}/${subscription.max_students}`}
                </p>
              </div>
            </div>
          ) : (
            <p className="text-text-muted text-sm py-4">لا يوجد اشتراك نشط حالياً. اختر باقة للاشتراك.</p>
          )}
        </GlassCard>
      </Section>

      {/* Unique ID */}
      {userData && (
        <Section delay={0.15}>
          <GlassCard>
            <div className="flex items-center gap-3 mb-4">
              <Fingerprint className="w-5 h-5 text-[var(--accent-2)]" />
              <h2 className="text-xl font-bold">معرف الحساب</h2>
            </div>
            <p className="text-xs text-text-muted mb-2">استخدم هذا المعرف عند التواصل مع الدعم الفني</p>
            <div className="flex items-center gap-2">
              <code className="flex-1 px-4 py-3 border border-[var(--border)] text-sm font-mono" dir="ltr" style={{ background: 'rgba(255,255,255,0.02)', letterSpacing: '1px' }}>
                {userData.id}
              </code>
              <button
                onClick={() => { navigator.clipboard.writeText(userData.id); toast.success('تم نسخ المعرف') }}
                className="p-3 border border-[var(--border)] hover:border-[var(--accent-2)] transition-colors"
                title="نسخ المعرف"
              >
                <Copy className="w-4 h-4" />
              </button>
            </div>
          </GlassCard>
        </Section>
      )}

      {/* Activate Code */}
      <Section delay={0.2}>
        <GlassCard>
          <div className="flex items-center gap-3 mb-4">
            <Key className="w-5 h-5 text-[var(--accent-2)]" />
            <h2 className="text-xl font-bold">تفعيل كود اشتراك</h2>
          </div>
          <div className="flex gap-3">
            <input
              type="text"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="XXXX-XXXX-XXXX-XXXX"
              className="flex-1 px-4 py-3 bg-transparent border border-[var(--border)] text-sm text-white placeholder:text-text-muted focus:outline-none focus:border-[var(--accent-2)] uppercase"
              style={{ fontFamily: 'var(--font-mono, monospace)', letterSpacing: '2px' }}
            />
            <button
              onClick={() => activateMutation.mutate()}
              disabled={code.trim().length < 16 || activateMutation.isPending}
              className="px-6 py-3 text-xs font-bold text-black transition-opacity disabled:opacity-30"
              style={{ background: 'var(--accent-2)' }}
            >
              {activateMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : 'تفعيل'}
            </button>
          </div>
        </GlassCard>
      </Section>

      {/* Plans */}
      <Section delay={0.3}>
        <h2 className="text-xl font-bold mb-4">الباقات المتاحة</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {plans.map((plan, i) => (
            <motion.div
              key={plan.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 * i }}
              className="relative p-6 border border-[var(--border)]"
              style={{ background: 'var(--card-bg)' }}
            >
              {plan.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 text-[10px] font-bold text-black" style={{ background: plan.color }}>
                  الأكثر طلباً
                </div>
              )}
              <h3 className="text-lg font-bold mb-2" style={{ color: plan.color }}>{plan.name}</h3>
              <p className="text-2xl font-bold mb-4">{plan.label}</p>
              <div className="space-y-2 mb-6">
                {plan.features.map((f, fi) => (
                  <div key={fi} className="flex items-center gap-2 text-sm text-text-secondary">
                    <Check className="w-3.5 h-3.5" style={{ color: plan.color }} />
                    <span>{f}</span>
                  </div>
                ))}
              </div>
              <button
                onClick={() => openPayment(plan)}
                className="w-full flex items-center justify-center gap-2 py-3 text-xs font-bold text-black transition-opacity hover:opacity-80"
                style={{ background: plan.color }}
              >
                <CreditCard className="w-3.5 h-3.5" />
                اشتراك الآن
              </button>
            </motion.div>
          ))}
        </div>
      </Section>

      {/* Payment Method Dialog */}
      {showMethodDialog && selectedPlan && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80" onClick={() => setShowMethodDialog(false)}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="w-full max-w-md p-6 border border-[var(--border)]"
            style={{ background: 'var(--card-bg)' }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-bold">اختر طريقة الدفع</h3>
              <button onClick={() => setShowMethodDialog(false)} className="text-text-muted hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-sm text-text-secondary mb-4">
              {selectedPlan.name} - {selectedPlan.label}
            </p>
            <div className="space-y-3">
              <button
                onClick={chooseWhatsApp}
                className="w-full flex items-center gap-4 p-4 border border-[var(--border)] hover:border-[var(--accent-2)] transition-colors text-right"
              >
                <MessageSquare className="w-6 h-6 text-[var(--accent-2)]" />
                <div>
                  <p className="font-bold text-sm">دعم عبر واتساب</p>
                  <p className="text-xs text-text-muted">{SUPPORT_PHONE}</p>
                </div>
              </button>
              <button
                onClick={chooseDirect}
                className="w-full flex items-center gap-4 p-4 border border-[var(--border)] hover:border-[var(--accent)] transition-colors text-right"
              >
                <Smartphone className="w-6 h-6 text-[var(--accent)]" />
                <div>
                  <p className="font-bold text-sm">دفع مباشر</p>
                  <p className="text-xs text-text-muted">حول عبر فودافون كاش وأرسل الإيصال</p>
                </div>
              </button>
            </div>
          </motion.div>
        </div>
      )}

      {/* Direct Payment Dialog */}
      {showPaymentDialog && selectedPlan && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80" onClick={() => { setShowPaymentDialog(false); setScreenshot(null); setPhoneNumber('') }}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="w-full max-w-md p-6 border border-[var(--border)]"
            style={{ background: 'var(--card-bg)' }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-bold">دفع عبر فودافون كاش</h3>
              <button onClick={() => { setShowPaymentDialog(false); setScreenshot(null); setPhoneNumber('') }} className="text-text-muted hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Vodafone Cash Number */}
              <div className="p-4 border border-[var(--accent-2)]" style={{ background: 'rgba(0,243,255,0.05)' }}>
                <p className="text-xs text-text-muted mb-1">حول إلى رقم فودافون كاش</p>
                <p className="text-xl font-bold text-[var(--accent-2)]" dir="ltr" style={{ fontFamily: 'var(--font-mono, monospace)', letterSpacing: '3px' }}>
                  {SUPPORT_PHONE}
                </p>
              </div>

              {/* Phone Number */}
              <div>
                <label className="text-xs text-text-muted mb-1 block">رقم هاتفك المحول منه</label>
                <div className="flex">
                  <span className="flex items-center px-3 border border-l-0 border-[var(--border)] text-text-muted text-sm">+20</span>
                  <input
                    type="tel"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value.replace(/[^0-9]/g, ''))}
                    placeholder="10XXXXXXXX"
                    className="flex-1 px-4 py-3 bg-transparent border border-[var(--border)] text-sm text-white placeholder:text-text-muted focus:outline-none focus:border-[var(--accent-2)]"
                    dir="ltr"
                  />
                </div>
              </div>

              {/* Amount */}
              <div>
                <label className="text-xs text-text-muted mb-1 block">المبلغ</label>
                <div className="flex items-center gap-2 px-4 py-3 border border-[var(--border)] cursor-not-allowed opacity-80" style={{ background: 'rgba(255,255,255,0.02)' }}>
                  <span className="text-lg font-bold">{selectedPlan.price}</span>
                  <span className="text-text-muted text-sm">ج.م</span>
                </div>
              </div>

              {/* Screenshot */}
              <div>
                <label className="text-xs text-text-muted mb-1 block">صورة الإيصال (اختياري)</label>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleFileChange}
                  className="hidden"
                />
                <button
                  onClick={() => fileInputRef.current?.click()}
                  className="w-full flex items-center justify-center gap-2 p-4 border border-dashed border-[var(--border)] hover:border-[var(--accent-2)] transition-colors text-sm text-text-muted"
                >
                  {screenshot ? (
                    <>
                      <CheckCircle className="w-5 h-5 text-[var(--success)]" />
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
                    <img src={screenshot} alt="Screenshot" className="w-full h-40 object-cover rounded border border-[var(--border)]" />
                    <button
                      onClick={() => setScreenshot(null)}
                      className="absolute top-2 right-2 p-1 bg-black/60 rounded"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                )}
              </div>

              {/* Submit */}
              <button
                onClick={() => paymentMutation.mutate()}
                disabled={phoneNumber.length < 10 || paymentMutation.isPending}
                className="w-full flex items-center justify-center gap-2 py-3 text-xs font-bold text-black transition-opacity disabled:opacity-30"
                style={{ background: 'var(--accent)' }}
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

      {/* Success Dialog */}
      {showSuccessDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80" onClick={() => setShowSuccessDialog(false)}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="w-full max-w-md p-6 border border-[var(--border)] text-center"
            style={{ background: 'var(--card-bg)' }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-16 h-16 mx-auto mb-4 flex items-center justify-center rounded-full border-2 border-[var(--success)]">
              <CheckCircle className="w-8 h-8 text-[var(--success)]" />
            </div>
            <h3 className="text-xl font-bold mb-2">تم الإرسال بنجاح!</h3>
            <div className="space-y-2 text-sm text-text-secondary mb-6">
              <p>سيتم التحقق من الدفع خلال 10 دقائق</p>
              <p>وبحد أقصى ساعتين</p>
              <div className="pt-3 border-t border-[var(--border)] mt-3">
                <p>لو فيه مشكلة أو تأخير</p>
                <p>تواصل معانا عبر الواتساب:</p>
              </div>
            </div>
            <a
              href={`https://wa.me/${SUPPORT_PHONE_INTL}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-6 py-3 text-xs font-bold text-black transition-opacity hover:opacity-80"
              style={{ background: 'var(--accent-2)' }}
              onClick={() => setShowSuccessDialog(false)}
            >
              <MessageSquare className="w-4 h-4" />
              {SUPPORT_PHONE}
            </a>
          </motion.div>
        </div>
      )}
    </div>
  )
}

function Send(props: any) { return <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}><line x1="22" y1="2" x2="11" y2="13" /><polygon points="22 2 15 22 11 13 2 9 22 2" /></svg> }
