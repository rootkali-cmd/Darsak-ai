'use client'

import { Sidebar, Header, ProtectedRoute, SubscriptionGuard } from '@/components/layout'
import { PageTransition, ErrorBoundary } from '@/components/ui'
import { usePathname } from 'next/navigation'

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()
  const noGuard = pathname === '/dashboard/subscription'

  return (
    <ProtectedRoute>
      <div
        className="min-h-screen relative overflow-x-hidden"
        style={{ background: 'linear-gradient(180deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)' }}
      >
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div
            className="absolute -top-40 -right-40 w-96 h-96 rounded-full"
            style={{ background: 'radial-gradient(circle, rgba(99,102,241,0.15) 0%, transparent 70%)', filter: 'blur(64px)' }}
          />
          <div
            className="absolute top-1/2 -left-40 w-80 h-80 rounded-full"
            style={{ background: 'radial-gradient(circle, rgba(99,102,241,0.08) 0%, transparent 70%)', filter: 'blur(64px)' }}
          />
          <div
            className="absolute -bottom-40 right-1/3 w-96 h-96 rounded-full"
            style={{ background: 'radial-gradient(circle, rgba(129,140,248,0.06) 0%, transparent 70%)', filter: 'blur(64px)' }}
          />
        </div>
        <Sidebar />
          <div className="lg:mr-64 relative z-10">
          <Header />
          <main className="p-3 md:p-6 overflow-x-hidden max-w-full">
            <PageTransition>
              <ErrorBoundary>{noGuard ? children : <SubscriptionGuard>{children}</SubscriptionGuard>}</ErrorBoundary>
            </PageTransition>
          </main>
        </div>
      </div>
    </ProtectedRoute>
  )
}
