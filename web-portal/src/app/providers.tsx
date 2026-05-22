'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'
import { Toaster } from 'react-hot-toast'

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
      {children}
      <Toaster
        position="top-center"
        toastOptions={{
          style: {
            background: '#1E293B',
            color: '#F1F5F9',
            border: '1px solid #334155',
            fontFamily: 'Tajawal, system-ui, sans-serif',
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
