'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { Toaster } from 'react-hot-toast'
import { auth } from '@/lib/auth'

function AuthSync() {
  useEffect(() => { auth.syncCookies() }, [])
  return null
}

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000,
            refetchOnWindowFocus: false,
          },
        },
      })
  )

  return (
    <QueryClientProvider client={queryClient}>
      <AuthSync />
      {children}
      <Toaster
        position="top-center"
        toastOptions={{
          style: {
            background: '#fff',
            color: '#1a1d23',
            border: '1px solid #e8ecf0',
            fontFamily: 'Cairo, system-ui, sans-serif',
          },
          success: {
            iconTheme: {
              primary: '#8B5CF6',
              secondary: '#F1F5F9',
            },
          },
        }}
      />
    </QueryClientProvider>
  )
}
