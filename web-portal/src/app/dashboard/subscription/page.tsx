'use client'

import { motion } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import {
  CreditCard,
  Loader2,
  Check,
  X,
  Users,
  Brain,
  Shield,
  Sparkles,
  Key,
  CheckCircle,
  AlertCircle,
  Clock,
} from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section } from '@/components/ui'
import { subscriptionsApi } from '@/lib/api'

const plans = [
  {
    id: 'basic',
    name: 'الباقة الأساسية',
    price: '199 ج.م/شهر',
    students: 50,
    ai: 100,
    color: '#00f3ff',
    features: [
      'حتى 50 طالب',
      '100 طلب ذكاء اصطناعي/شهر',
      'إدارة الدرجات والحضور',
      'الفواتير الأساسية',
      'QR Code المعلم',
    ],
  },
  {
    id: 'pro',
    name: 'الباقة المتقدمة',
    price: '499 ج.م/شهر',
    students: 500,
    ai: 500,
    color: '#ccff00',
    popular: true,
    features: [
      'حتى 500 طالب',
      '500 طلب ذكاء اصطناعي/شهر',
      'إدارة الدرجات والحضور',
      'الفواتير المتقدمة',
      'QR Code المعلم',
      'تصدير التقارير',
      'دعم فني متميز',
    ],
  },
  {
    id: 'unlimited',
    name: 'الباقة الغير محدودة',
    price: '999 ج.م/شهر',
    students: 0,
    ai: 2000,
    color: '#ff003c',
    features: [
      'طلاب غير محدود',
      '2000 طلب ذكاء اصطناعي/شهر',
      'جميع المميزات',
      'دعم فني متميز',
      'أولوية في التحديثات',
    ],
  },
]

export default function SubscriptionPage() {
  const queryClient = useQueryClient()
  const [code, setCode] = useState('')

  const { data: subscription, isLoading } = useQuery({
    queryKey: ['subscription'],
    queryFn: () => subscriptionsApi.my().then((r) => r.data),
  })

  const activateMutation = useMutation({
    mutationFn: () => subscriptionsApi.activate(code.trim().toUpperCase()),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ['subscription'] })
      toast.success('تم تفعيل الاشتراك بنجاح!')
      setCode('')
    },
    onError: (err: any) => {
      toast.error(err.response?.data?.detail || 'فشل تفعيل الكود')
    },
  })

  const isActive = subscription?.active && !subscription?.expired

  const formatDate = (d: string) => {
    if (!d) return '-'
    return new Date(d).toLocaleDateString('ar-EG', {
      year: 'numeric', month: 'long', day: 'numeric',
    })
  }

  if (isLoading) {
    return <div className="flex justify-center py-24"><Loader2 className="w-12 h-12 animate-spin text-[var(--accent)]" /></div>
  }

  return (
    <div className="space-y-6">
      <Section>
        <h1 className="text-3xl font-bold">الاشتراكات</h1>
        <p className="text-text-secondary mt-1">إدارة اشتراكك وعرض الباقات المتاحة</p>
      </Section>

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
            <p className="text-text-muted text-sm py-4">لا يوجد اشتراك نشط حالياً. فعّل كود اشتراك أدناه أو اختر باقة.</p>
          )}
        </GlassCard>
      </Section>

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
            <NeonButton
              onClick={() => activateMutation.mutate()}
              disabled={code.trim().length < 16 || activateMutation.isPending}
            >
              {activateMutation.isPending ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                'تفعيل'
              )}
            </NeonButton>
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
                <div
                  className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 text-[10px] font-bold text-black"
                  style={{ background: plan.color }}
                >
                  الأكثر طلباً
                </div>
              )}
              <h3 className="text-lg font-bold mb-2" style={{ color: plan.color }}>{plan.name}</h3>
              <p className="text-2xl font-bold mb-4">{plan.price}</p>
              <div className="space-y-2 mb-6">
                {plan.features.map((f, fi) => (
                  <div key={fi} className="flex items-center gap-2 text-sm text-text-secondary">
                    <Check className="w-3.5 h-3.5" style={{ color: plan.color }} />
                    <span>{f}</span>
                  </div>
                ))}
              </div>
              <a
                href={`https://wa.me/201234567890?text=${encodeURIComponent(`أريد الاشتراك في ${plan.name}`)}`}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-center justify-center gap-2 py-3 text-xs font-bold text-black transition-opacity hover:opacity-80"
                style={{ background: plan.color }}
              >
                <CreditCard className="w-3.5 h-3.5" />
                اشتراك الآن
              </a>
            </motion.div>
          ))}
        </div>
      </Section>
    </div>
  )
}
