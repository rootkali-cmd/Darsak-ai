'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Check, X, Users, CreditCard, Sparkles, Play, HardDrive, Brain } from 'lucide-react'

const plans = [
  {
    id: 'basic',
    nameAr: 'الباقة الأساسية',
    nameEn: 'Basic',
    price: '250',
    currency: 'ج.م',
    period: '/شهر',
    color: '#6366F1',
    students: '100 طالب',
    aiRequests: '5 طلبات AI/شهر',
    storage: '2GB فيديو',
    trial: true,
    features: [
      { ar: 'حتى 100 طالب', en: 'Up to 100 students', ok: true },
      { ar: '5 طلبات ذكاء اصطناعي/شهر', en: '5 AI requests/month', ok: true },
      { ar: 'تخزين فيديو 2GB', en: '2GB video storage', ok: true },
      { ar: 'إدارة الدرجات', en: 'Grade management', ok: true },
      { ar: 'إدارة الحضور', en: 'Attendance tracking', ok: true },
      { ar: 'الفواتير الأساسية', en: 'Basic invoices', ok: true },
      { ar: 'QR Code المعلم', en: 'Teacher QR code', ok: true },
      { ar: 'تحليل AI للطلاب', en: 'AI student analysis', ok: true },
      { ar: 'تقارير متقدمة', en: 'Advanced reports', ok: false },
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
    color: '#8B5CF6',
    students: '400 طالب',
    aiRequests: '30 طلب AI/شهر',
    storage: '6GB فيديو',
    popular: true,
    features: [
      { ar: 'حتى 400 طالب', en: 'Up to 400 students', ok: true },
      { ar: '30 طلب ذكاء اصطناعي/شهر', en: '30 AI requests/month', ok: true },
      { ar: 'تخزين فيديو 6GB', en: '6GB video storage', ok: true },
      { ar: 'إدارة الدرجات', en: 'Grade management', ok: true },
      { ar: 'إدارة الحضور', en: 'Attendance tracking', ok: true },
      { ar: 'الفواتير المتقدمة', en: 'Advanced invoices', ok: true },
      { ar: 'QR Code المعلم', en: 'Teacher QR code', ok: true },
      { ar: 'تحليل AI للطلاب', en: 'AI student analysis', ok: true },
      { ar: 'تقارير متقدمة', en: 'Advanced reports', ok: true },
      { ar: 'دعم فني متميز', en: 'Priority support', ok: true },
    ],
  },
  {
    id: 'unlimited',
    nameAr: 'الباقة المتكاملة',
    nameEn: 'Premium',
    price: '1100',
    currency: 'ج.م',
    period: '/شهر',
    color: '#10B981',
    students: 'غير محدود',
    aiRequests: 'AI غير محدود',
    storage: 'فيديو غير محدود',
    features: [
      { ar: 'طلاب غير محدود', en: 'Unlimited students', ok: true },
      { ar: 'ذكاء اصطناعي غير محدود', en: 'Unlimited AI', ok: true },
      { ar: 'تخزين فيديو غير محدود', en: 'Unlimited video storage', ok: true },
      { ar: 'إدارة الدرجات', en: 'Grade management', ok: true },
      { ar: 'إدارة الحضور', en: 'Attendance tracking', ok: true },
      { ar: 'الفواتير المتقدمة', en: 'Advanced invoices', ok: true },
      { ar: 'QR Code المعلم', en: 'Teacher QR code', ok: true },
      { ar: 'تحليل AI للطلاب', en: 'AI student analysis', ok: true },
      { ar: 'تقارير متقدمة', en: 'Advanced reports', ok: true },
      { ar: 'دعم فني 24/7', en: '24/7 priority support', ok: true },
      { ar: 'تخصيص كامل', en: 'Full customization', ok: true },
    ],
  },
]

export default function PricingPage() {
  const router = useRouter()
  const [isAr, setIsAr] = useState(true)

  useEffect(() => { setIsAr(document.dir === 'rtl') }, [])

  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(180deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)' }}>
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-emerald-500/5 rounded-full blur-3xl" />
      </div>

      <div className="relative max-w-5xl mx-auto px-4 py-20">
        <motion.button onClick={() => router.push('/')} initial={{ opacity: 0 }} animate={{ opacity: 1 }}
          className="text-sm text-slate-400 hover:text-white transition-colors mb-16 inline-flex items-center gap-1">
          ← {isAr ? 'العودة للرئيسية' : 'BACK HOME'}
        </motion.button>

        <motion.div initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }} className="text-center mb-16">
          <span className="inline-block px-3 py-1 text-xs font-bold tracking-widest mb-4 border border-indigo-500/40 text-indigo-400 rounded-full">
            {isAr ? 'الباقات' : 'PLANS'}
          </span>
          <h1 className="text-3xl md:text-4xl font-extrabold text-white mb-3">
            {isAr ? 'اختر باقتك' : 'Choose Your Plan'}
          </h1>
          <p className="text-slate-400">
            {isAr ? 'اشتراكات شهرية مرنة • يمكنك الترقية في أي وقت' : 'Flexible monthly subscriptions • Upgrade anytime'}
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {plans.map((plan, i) => (
            <motion.div key={plan.id} initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 * i, duration: 0.5, ease: [0.16, 1, 0.3, 1] }} className="relative">
              
              {plan.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 z-10 px-4 py-1 text-xs font-bold text-white rounded-full"
                  style={{ background: 'linear-gradient(135deg, #6366F1, #818CF8)' }}>
                  {isAr ? 'الأكثر طلباً' : 'POPULAR'}
                </div>
              )}

              {plan.trial && (
                <div className="absolute -top-3 right-4 z-10 px-3 py-1 text-xs font-bold text-emerald-400 bg-emerald-500/15 border border-emerald-500/30 rounded-full">
                  30 {isAr ? 'يوم مجاناً' : 'Days Free'}
                </div>
              )}

              <div className={`p-6 md:p-8 h-full flex flex-col rounded-2xl bg-white/[0.03] border transition-all duration-300 ${
                plan.popular ? 'border-indigo-500/40 scale-[1.02]' : 'border-white/[0.08] hover:border-white/[0.12]'
              }`}>
                <div className="text-center mb-6">
                  <h3 className="text-lg font-bold text-white mb-2">{isAr ? plan.nameAr : plan.nameEn}</h3>
                  <div className="flex items-baseline justify-center gap-1">
                    <span className="text-4xl font-extrabold text-white">{plan.price}</span>
                    <span className="text-sm text-slate-400">{plan.currency}{plan.period}</span>
                  </div>
                  <div className="mt-3 flex flex-col items-center gap-1 text-xs text-slate-400">
                    <div className="flex items-center gap-1"><Users size={11} /> {plan.students}</div>
                    <div className="flex items-center gap-1"><Brain size={11} /> {plan.aiRequests}</div>
                    <div className="flex items-center gap-1"><HardDrive size={11} /> {plan.storage}</div>
                  </div>
                </div>

                <div className="h-px bg-white/[0.08] mb-6" />
                <div className="flex-1 space-y-2.5 mb-8">
                  {plan.features.map((f, fi) => (
                    <div key={fi} className="flex items-center gap-3">
                      {f.ok ? <Check size={14} className="flex-shrink-0 text-indigo-400" /> : <X size={14} className="flex-shrink-0 text-slate-600" />}
                      <span className={`text-xs ${f.ok ? 'text-slate-300' : 'text-slate-600'}`}>{isAr ? f.ar : f.en}</span>
                    </div>
                  ))}
                </div>

                <motion.button onClick={() => router.push('/dashboard/subscription')}
                  className="w-full py-3 text-sm font-bold text-white rounded-xl transition-all duration-300 flex items-center justify-center gap-2"
                  style={{ background: plan.trial ? 'linear-gradient(135deg, #10B981, #059669)' : `linear-gradient(135deg, ${plan.color}, ${plan.color}dd)` }}
                  whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
                  {plan.trial ? <Sparkles size={14} /> : <CreditCard size={14} />}
                  {plan.trial ? (isAr ? 'جرب مجاناً' : 'TRY FREE') : (isAr ? 'اشتراك' : 'SUBSCRIBE')}
                </motion.button>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  )
}
