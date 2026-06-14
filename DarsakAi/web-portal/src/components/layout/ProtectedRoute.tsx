'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { auth } from '@/lib/auth'

export default function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const [mounted, setMounted] = useState(false)
  const [authorized, setAuthorized] = useState(false)

  useEffect(() => {
    setMounted(true)
    const authed = auth.isAuthenticated()
    if (authed) {
      setAuthorized(true)
    } else {
      router.push('/login')
    }
  }, [router])

  if (!mounted || !authorized) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary"></div>
      </div>
    )
  }

  return <>{children}</>
}
