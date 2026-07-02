import type { Metadata } from 'next'
import { Providers } from './providers'
import './globals.css'

export const metadata: Metadata = {
  metadataBase: new URL('https://darsakai.com'),
  title: 'DARSAK AI — منصة تعليمية ذكية',
  description: 'منصة متكاملة لإدارة السناتر التعليمية — متابعة الطلاب، الحضور، الدرجات، والتحليلات بالذكاء الاصطناعي',
  icons: {
    icon: '/icon.png',
    apple: '/apple-touch-icon.png',
  },
  openGraph: {
    title: 'DarsakAI — منصة تعليمية ذكية بالذكاء الاصطناعي',
    description: 'منصة متكاملة لإدارة السناتر التعليمية — إدارة الطلاب، الامتحانات والتصحيح بالذكاء الاصطناعي، الحضور والغياب، الكورسات، الفواتير، وتحليلات الأداء.',
    url: 'https://darsakai.com',
    siteName: 'DarsakAI',
    locale: 'ar_EG',
    type: 'website',
    images: [{ url: '/icon.png', width: 192, height: 192 }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'DarsakAI — منصة تعليمية ذكية',
    description: 'منصة متكاملة لإدارة السناتر التعليمية بالذكاء الاصطناعي',
    images: ['/icon.png'],
  },
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
          href="https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="antialiased">
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  )
}
