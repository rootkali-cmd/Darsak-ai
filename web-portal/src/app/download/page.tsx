'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Smartphone, Monitor, ArrowLeft, Download, Sparkles } from 'lucide-react'

const apps = [
  {
    id: 'mobile',
    title: 'DarsakAI Mobile',
    description: 'تطبيق الهاتف للطلاب - متابعة الدرجات والحضور والملف الشخصي',
    descriptionEn: 'Student mobile app — grades, attendance & profile',
    icon: Smartphone,
    color: '#00f3ff',
    fileName: 'DarsakAI.apk',
    size: '69 MB',
    platform: 'Android',
    note: 'v1.0.1 • Code-128 barcode scanner • Offline-first',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop',
    description: 'نظام إدارة الفصل للمعلم - students, grades, attendance',
    descriptionEn: 'Teacher desktop app — full classroom management',
    icon: Monitor,
    color: '#ccff00',
    fileName: null,
    size: '—',
    platform: 'Windows / Linux',
    note: 'يحتاج بناء على ويندوز • flutter build windows',
  },
  {
    id: 'accounts',
    title: 'DarsakAI Accounts',
    description: 'نظام الحسابات والمالية للفصل',
    descriptionEn: 'Finance & accounts management',
    icon: Monitor,
    color: '#ff003c',
    fileName: null,
    size: '—',
    platform: 'Windows / Linux',
    note: 'يحتاج بناء على ويندوز • flutter build windows',
  },
]

export default function DownloadPage() {
  const router = useRouter()
  const [isAr, setIsAr] = useState(true)

  useEffect(() => {
    setIsAr(document.dir === 'rtl')
  }, [])

  return (
    <div className="min-h-screen flex items-center justify-center relative px-4 py-12">
      {/* Corner decoration */}
      <div className="fixed top-4 left-4 z-50 hud-text flex items-center gap-2">
        <span className="text-[var(--accent)]">●</span>
        <span>DARSAK AI</span>
        <span className="text-[rgba(255,255,255,0.2)]">/</span>
        <span>DOWNLOADS</span>
      </div>

      {/* Back button */}
      <button
        onClick={() => router.push('/')}
        className="fixed top-4 ltr:left-4 rtl:right-4 z-50 px-4 py-2 border border-[var(--border)] hover:border-[var(--accent-2)] text-xs hud-text transition-colors"
        style={{ background: 'var(--card-bg)' }}
      >
        ← {isAr ? 'رجوع' : 'BACK'}
      </button>

      <div className="relative z-10 w-full max-w-5xl">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="text-center mb-12"
        >
          <h1 className="text-4xl font-bold mb-3" style={{ fontFamily: 'var(--font-display)' }}>
            DOWNLOADS
          </h1>
          <p className="text-sm hud-text text-[var(--text-muted)]">
            {isAr ? 'حمّل تطبيقات درسك أي' : 'Download DarsakAI apps'}
          </p>
        </motion.div>

        {/* Apps grid */}
        <div className="grid md:grid-cols-3 gap-6">
          {apps.map((app, i) => (
            <motion.div
              key={app.id}
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.15 * (i + 1) }}
            >
              <div
                className="brutal-card p-6 flex flex-col h-full relative"
                style={{ background: 'var(--card-bg)', position: 'relative' }}
              >
                {/* Corner brackets */}
                <div className="absolute top-0 left-0 w-4 h-4 border-t border-l" style={{ borderColor: app.color }} />
                <div className="absolute top-0 right-0 w-4 h-4 border-t border-r" style={{ borderColor: app.color }} />
                <div className="absolute bottom-0 left-0 w-4 h-4 border-b border-l" style={{ borderColor: app.color }} />
                <div className="absolute bottom-0 right-0 w-4 h-4 border-b border-r" style={{ borderColor: app.color }} />

                {/* Icon */}
                <div
                  className="w-12 h-12 flex items-center justify-center mb-4"
                  style={{ border: `1px solid ${app.color}` }}
                >
                  <app.icon className="w-6 h-6" style={{ color: app.color }} />
                </div>

                {/* Title */}
                <h2 className="text-lg font-bold mb-1" style={{ fontFamily: 'var(--font-display)' }}>
                  {app.title}
                </h2>

                {/* Description */}
                <p className="text-xs hud-text text-[var(--text-muted)] mb-4 leading-relaxed" style={{ fontFamily: 'var(--font-arabic)' }}>
                  {isAr ? app.description : app.descriptionEn}
                </p>

                {/* Meta info */}
                <div className="mt-auto space-y-3">
                  <div className="flex justify-between text-[10px] hud-text">
                    <span className="text-[var(--text-muted)]">{isAr ? 'المنصة' : 'Platform'}</span>
                    <span style={{ color: app.color }}>{app.platform}</span>
                  </div>
                  <div className="flex justify-between text-[10px] hud-text">
                    <span className="text-[var(--text-muted)]">{isAr ? 'الحجم' : 'Size'}</span>
                    <span>{app.size}</span>
                  </div>
                  {app.note && (
                    <p className="text-[10px] hud-text text-[var(--text-muted)] opacity-60 pt-2 border-t border-[var(--border)]">
                      {app.note}
                    </p>
                  )}

                  {/* Download button */}
                  {app.fileName ? (
                    <a
                      href={`/${app.fileName}`}
                      download
                      className="w-full flex items-center justify-center gap-2 py-2.5 text-xs font-bold hud-text uppercase tracking-wider transition-all"
                      style={{
                        background: app.color,
                        color: '#000',
                        border: `1px solid ${app.color}`,
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.opacity = '0.8'
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.opacity = '1'
                      }}
                    >
                      <Download className="w-3.5 h-3.5" />
                      {isAr ? 'تحميل' : 'DOWNLOAD'}
                    </a>
                  ) : (
                    <div
                      className="w-full flex items-center justify-center gap-2 py-2.5 text-xs font-bold hud-text uppercase tracking-wider cursor-not-allowed"
                      style={{
                        border: `1px solid var(--border)`,
                        color: 'var(--text-muted)',
                        opacity: 0.5,
                      }}
                    >
                      <Sparkles className="w-3.5 h-3.5" />
                      {isAr ? 'قريباً' : 'COMING SOON'}
                    </div>
                  )}
                </div>
              </div>
            </motion.div>
          ))}
        </div>

        {/* Info note */}
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1 }}
          className="text-center text-[10px] hud-text text-[var(--text-muted)] mt-8 opacity-50"
        >
          {isAr
            ? 'التطبيقات تحت التطوير • للاستخدام الداخلي'
            : 'Apps are under active development • For internal use'}
        </motion.p>
      </div>
    </div>
  )
}
