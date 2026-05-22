'use client'

import { Sidebar, Header, ProtectedRoute } from '@/components/layout'
import { PageTransition } from '@/components/ui'

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <ProtectedRoute>
      <div className="min-h-screen relative overflow-x-hidden">
        <Sidebar />
        <div className="lg:mr-72">
          <Header />
          <main className="p-6 relative z-10 overflow-x-hidden">
            <PageTransition>{children}</PageTransition>
          </main>
        </div>
      </div>
    </ProtectedRoute>
  )
}
