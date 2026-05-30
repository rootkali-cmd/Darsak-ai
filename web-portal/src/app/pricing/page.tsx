'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Check, X, Users, CreditCard } from 'lucide-react'

const plans = [
  {
    id: 'basic',
    nameAr: 'الباقة الأساسية',
    nameEn: 'Basic',
    price: '200',
    currency: 'ج.م',
    period: '/شهر',
    color: '#00f3ff',
    students: '50 طالب',
    features: [
      { ar: 'حتى 50 طالب', en: 'Up to 50 students', ok: true },
      { ar: '100 طلب ذكاء اصطناعي/شهر', en: '100 AI requests/month', ok: true },
      { ar: 'إدارة الدرجات', en: 'Grade management', ok: true },
      { ar: 'إدارة الحضور', en: 'Attendance tracking', ok: true },
      { ar: 'الفواتير الأساسية', en: 'Basic invoices', ok: true },
      { ar: 'QR Code المعلم', en: 'Teacher QR code', ok: true },
      { ar: 'تحليل الطلاب بالذكاء الاصطناعي', en: 'AI student analysis', ok: true },
      { ar: 'تصدير التقارير', en: 'Export reports', ok: false },
      { ar: 'دعم فني متميز', en: 'Priority support', ok: false },
    ],
  },
  {
    id: 'pro',
    nameAr: 'الباقة المتقدمة',
    nameEn: 'Pro',
    price: '600',
    currency: 'ج.م',
    period: '/شهر',
    color: '#ccff00',
    students: '500 طالب',
    popular: true,
    features: [
      { ar: 'حتى 500 طالب', en: 'Up to 500 students', ok: true },
      { ar: '500 طلب ذكاء اصطناعي/شهر', en: '500 AI requests/month', ok: true },
      { ar: 'إدارة الدرجات', en: 'Grade management', ok: true },
      { ar: 'إدارة الحضور', en: 'Attendance tracking', ok: true },
      { ar: 'الفواتير المتقدمة', en: 'Advanced invoices', ok: true },
      { ar: 'QR Code المعلم', en: 'Teacher QR code', ok: true },
      { ar: 'تحليل الطلاب بالذكاء الاصطناعي', en: 'AI student analysis', ok: true },
      { ar: 'تصدير التقارير', en: 'Export reports', ok: true },
      { ar: 'دعم فني متميز', en: 'Priority support', ok: true },
    ],
  },
  {
    id: 'unlimited',
    nameAr: 'الباقة المتكاملة',
    nameEn: 'Enterprise',
    price: '1100',
    currency: 'ج.م',
    period: '/شهر',
    color: '#ff003c',
    students: 'غير محدود',
    features: [
      { ar: 'طلاب غير محدود', en: 'Unlimited students', ok: true },
      { ar: '2000 طلب ذكاء اصطناعي/شهر', en: '2000 AI requests/month', ok: true },
      { ar: 'إدارة الدرجات', en: 'Grade management', ok: true },
      { ar: 'إدارة الحضور', en: 'Attendance tracking', ok: true },
      { ar: 'الفواتير المتقدمة', en: 'Advanced invoices', ok: true },
      { ar: 'QR Code المعلم', en: 'Teacher QR code', ok: true },
      { ar: 'تحليل الطلاب بالذكاء الاصطناعي', en: 'AI student analysis', ok: true },
      { ar: 'تصدير التقارير', en: 'Export reports', ok: true },
      { ar: 'دعم فني متميز', en: 'Priority support', ok: true },
      { ar: 'أولوية في التحديثات', en: 'Priority updates', ok: true },
    ],
  },
]

export default function PricingPage() {
  const router = useRouter()
  const [isAr, setIsAr] = useState(true)

  useEffect(() => {
    setIsAr(document.dir === 'rtl')
  }, [])

  return (
    <div className="min-h-screen py-16 px-4">
      <button
        onClick={() => router.push('/')}
        className="fixed top-4 left-4 z-50 text-sm text-[var(--text-muted)] hover:text-[var(--accent)] transition-colors"
      >
        ← {isAr ? 'العودة' : 'BACK'}
      </button>

      <div className="w-full max-w-6xl mx-auto mt-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <h1 className="text-3xl font-bold mb-3">{isAr ? 'اختر باقتك' : 'Choose Your Plan'}</h1>
          <p className="text-sm text-[var(--text-muted)]">
            {isAr ? 'اشتراكات شهرية مرنة • يمكنك الترقية في أي وقت' : 'Flexible monthly subscriptions • Upgrade anytime'}
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {plans.map((plan, i) => (
            <motion.div
              key={plan.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 * i }}
              className="relative"
            >
              {plan.popular && (
                <div
                  className="absolute -top-3 left-1/2 -translate-x-1/2 z-10 px-4 py-1 text-[10px] font-bold"
                  style={{ background: plan.color, color: '#000' }}
                >
                  {isAr ? 'الأكثر طلباً' : 'POPULAR'}
                </div>
              )}

              <div
                className="card p-6 md:p-8 h-full flex flex-col"
                style={{
                  borderColor: plan.popular ? plan.color : undefined,
                }}
              >
                <div className="text-center mb-6">
                  <h3 className="text-lg font-bold mb-2" style={{ color: plan.color }}>
                    {isAr ? plan.nameAr : plan.nameEn}
                  </h3>
                  <div className="flex items-baseline justify-center gap-1">
                    <span className="text-3xl font-bold">{plan.price}</span>
                    <span className="text-xs text-[var(--text-muted)]">{plan.currency}{plan.period}</span>
                  </div>
                  <div className="mt-2 flex items-center justify-center gap-1 text-xs" style={{ color: plan.color }}>
                    <Users size={12} />
                    <span>{plan.students}</span>
                  </div>
                </div>

                <div className="divider" />

                <div className="flex-1 space-y-3 mb-8">
                  {plan.features.map((f, fi) => (
                    <div key={fi} className="flex items-center gap-3">
                      {f.ok ? (
                        <Check size={14} className="flex-shrink-0" style={{ color: plan.color }} />
                      ) : (
                        <X size={14} className="flex-shrink-0" style={{ color: 'var(--text-muted)', opacity: 0.3 }} />
                      )}
                      <span
                        className="text-xs"
                        style={{
                          color: f.ok ? 'var(--text-secondary)' : 'var(--text-muted)',
                          opacity: f.ok ? 1 : 0.4,
                        }}
                      >
                        {isAr ? f.ar : f.en}
                      </span>
                    </div>
                  ))}
                </div>

                <button
                  onClick={() => router.push('/dashboard/subscription')}
                  className="btn w-full justify-center py-3 text-xs font-bold"
                  style={{
                    background: plan.color,
                    color: '#000',
                    borderColor: plan.color,
                  }}
                  onMouseEnter={(e) => { e.currentTarget.style.opacity = '0.85' }}
                  onMouseLeave={(e) => { e.currentTarget.style.opacity = '1' }}
                >
                  <CreditCard size={14} />
                  {isAr ? 'اشتراك الآن' : 'SUBSCRIBE'}
                </button>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  )
}
