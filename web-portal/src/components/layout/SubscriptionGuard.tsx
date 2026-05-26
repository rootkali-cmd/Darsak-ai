'use client'

import { useQuery } from '@tanstack/react-query'
import { useRouter } from 'next/navigation'
import { Loader2, CreditCard, Lock } from 'lucide-react'
import { subscriptionsApi } from '@/lib/api'

export default function SubscriptionGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter()

  const { data: sub, isLoading } = useQuery({
    queryKey: ['subscription'],
    queryFn: () => subscriptionsApi.my().then((r) => r.data),
  })

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-24">
        <Loader2 className="w-8 h-8 animate-spin text-[var(--accent)]" />
      </div>
    )
  }

  const isActive = sub?.is_active && !sub?.is_expired

  if (!isActive) {
    return (
      <div className="flex items-center justify-center py-16 px-4">
        <div className="w-full max-w-md text-center p-8 border border-[var(--border)]" style={{ background: 'var(--card-bg)' }}>
          <div className="w-16 h-16 mx-auto mb-4 flex items-center justify-center rounded-full border-2 border-[var(--accent-2)]">
            <Lock className="w-8 h-8 text-[var(--accent-2)]" />
          </div>
          <h2 className="text-xl font-bold mb-2">الميزة مقفولة</h2>
          <p className="text-sm text-text-secondary mb-6">
            لازم تشترك في باقة عشان تقدر تستخدم الميزة دي
          </p>
          <button
            onClick={() => router.push('/dashboard/subscription')}
            className="inline-flex items-center gap-2 px-6 py-3 text-xs font-bold text-black transition-opacity hover:opacity-80"
            style={{ background: 'var(--accent-2)' }}
          >
            <CreditCard className="w-4 h-4" />
            عرض الباقات
          </button>
        </div>
      </div>
    )
  }

  return <>{children}</>
}
