'use client'

import { Sidebar, Header, ProtectedRoute, SubscriptionGuard } from '@/components/layout'
import { PageTransition } from '@/components/ui'
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
      <div className="min-h-screen relative overflow-x-hidden">
        <Sidebar />
          <div className="lg:mr-64">
          <Header />
          <main className="p-3 md:p-6 relative z-10 overflow-x-hidden max-w-full">
            <PageTransition>
              {noGuard ? children : <SubscriptionGuard>{children}</SubscriptionGuard>}
            </PageTransition>
          </main>
        </div>
      </div>
    </ProtectedRoute>
  )
}
