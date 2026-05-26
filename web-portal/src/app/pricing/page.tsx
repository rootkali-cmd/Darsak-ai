'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { ArrowLeft, Check, X, Sparkles, Users, Brain, Shield, CreditCard } from 'lucide-react'

const plans = [
  {
    id: 'basic',
    nameAr: 'الباقة الأساسية',
    nameEn: 'Basic',
    price: '199',
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
    price: '499',
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
    nameAr: 'الباقة الغير محدودة',
    nameEn: 'Unlimited',
    price: '999',
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
    <div className="min-h-screen flex items-center justify-center relative px-4 py-12">
      {/* Corner decoration */}
      <div className="fixed top-4 left-4 z-50 hud-text flex items-center gap-2">
        <span className="text-[var(--accent)]">●</span>
        <span>DARSAK AI</span>
        <span className="text-[rgba(255,255,255,0.2)]">/</span>
        <span>{isAr ? 'الباقات' : 'PRICING'}</span>
      </div>

      {/* Back button */}
      <button
        onClick={() => router.push('/')}
        className="fixed top-4 ltr:left-4 rtl:right-4 z-50 px-4 py-2 border border-[var(--border)] hover:border-[var(--accent-2)] text-xs hud-text transition-colors"
        style={{ background: 'var(--card-bg)' }}
      >
        <ArrowLeft className="w-3 h-3 inline-block ltr:rotate-180 ml-1" />
        {isAr ? 'العودة' : 'BACK'}
      </button>

      <div className="w-full max-w-6xl mx-auto mt-16">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <h1 className="text-3xl md:text-4xl font-bold hud-text mb-4" style={{ fontFamily: 'var(--font-display)' }}>
            {isAr ? 'اختر باقتك' : 'CHOOSE YOUR PLAN'}
          </h1>
          <p className="text-sm hud-text" style={{ color: 'var(--text-muted)' }}>
            {isAr
              ? 'اشتراكات شهرية مرنة • يمكنك الترقية في أي وقت'
              : 'Flexible monthly subscriptions • Upgrade anytime'}
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {plans.map((plan, i) => (
            <motion.div
              key={plan.id}
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.15 * i }}
              className="relative"
            >
              {plan.popular && (
                <div
                  className="absolute -top-3 left-1/2 -translate-x-1/2 z-10 px-4 py-1 text-[10px] font-bold hud-text uppercase tracking-widest"
                  style={{
                    background: plan.color,
                    color: '#000',
                  }}
                >
                  {isAr ? 'الأكثر طلباً' : 'POPULAR'}
                </div>
              )}

              <div
                className="p-6 md:p-8 h-full flex flex-col"
                style={{
                  background: 'var(--card-bg)',
                  border: `1px solid ${plan.popular ? plan.color : 'var(--border)'}`,
                }}
              >
                {/* Header */}
                <div className="text-center mb-6">
                  <h3
                    className="text-lg font-bold hud-text mb-2"
                    style={{ color: plan.color, fontFamily: 'var(--font-display)' }}
                  >
                    {isAr ? plan.nameAr : plan.nameEn}
                  </h3>
                  <div className="flex items-baseline justify-center gap-1">
                    <span className="text-3xl font-bold" style={{ color: 'var(--text-primary)' }}>
                      {plan.price}
                    </span>
                    <span className="text-xs" style={{ color: 'var(--text-muted)' }}>
                      {plan.currency}{plan.period}
                    </span>
                  </div>
                  <div className="mt-2 flex items-center justify-center gap-1 text-xs" style={{ color: plan.color }}>
                    <Users className="w-3 h-3" />
                    <span>{plan.students}</span>
                  </div>
                </div>

                {/* Divider */}
                <div style={{ height: 1, background: 'var(--border)', marginBottom: 24 }} />

                {/* Features */}
                <div className="flex-1 space-y-3 mb-8">
                  {plan.features.map((f, fi) => (
                    <div key={fi} className="flex items-center gap-3">
                      {f.ok ? (
                        <Check className="w-3.5 h-3.5 flex-shrink-0" style={{ color: plan.color }} />
                      ) : (
                        <X className="w-3.5 h-3.5 flex-shrink-0" style={{ color: 'var(--text-muted)', opacity: 0.3 }} />
                      )}
                      <span
                        className="text-xs hud-text"
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

                {/* CTA */}
                <button
                  onClick={() => router.push('/dashboard/subscription')}
                  className="w-full flex items-center justify-center gap-2 py-3 text-xs font-bold hud-text uppercase tracking-wider transition-all text-center"
                  style={{
                    background: plan.color,
                    color: '#000',
                    border: `1px solid ${plan.color}`,
                  }}
                  onMouseEnter={(e) => { e.currentTarget.style.opacity = '0.8' }}
                  onMouseLeave={(e) => { e.currentTarget.style.opacity = '1' }}
                >
                  <CreditCard className="w-3.5 h-3.5" />
                  {isAr ? 'اشتراك الآن' : 'SUBSCRIBE'}
                </button>
              </div>
            </motion.div>
          ))}
        </div>

        {/* Info */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          className="mt-12 text-center"
        >
          <div
            className="inline-flex items-center gap-2 px-4 py-2 text-xs hud-text"
            style={{
              background: 'var(--card-bg)',
              border: '1px solid var(--border)',
              color: 'var(--text-muted)',
            }}
          >
            <Shield className="w-3 h-3" />
            {isAr
              ? 'جميع الباقات مدعومة بتشفير متقدم • أكواد تفعيل آمنة'
              : 'All plans backed by advanced encryption • Secure activation codes'}
          </div>
        </motion.div>
      </div>
    </div>
  )
}
