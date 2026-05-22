import type { Metadata } from 'next'
import { Providers } from './providers'
import { CustomCursor } from '@/components/ui'
import './globals.css'

export const metadata: Metadata = {
  title: 'DARSAK AI // BRUTAL MODE',
  description: 'AI-powered platform for classroom management and student performance analysis',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ar" dir="rtl">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Tajawal:wght@300;400;500;700;800;900&family=JetBrains+Mono:wght@400;700&family=Syncopate:wght@400;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="antialiased">
        <div className="global-scanlines" />
        <div className="global-vignette" />
        <div className="global-noise" />
        <CustomCursor />
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  )
}
