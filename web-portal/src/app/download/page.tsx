'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Smartphone, Monitor, ArrowLeft, Download, Sparkles } from 'lucide-react'

const apps: {
  id: string;
  title: string;
  description: string;
  descriptionEn: string;
  icon: any;
  color: string;
  files?: { name: string; label: string; size: string }[];
  size?: string;
  platform: string;
  note: string;
}[] = [
  {
    id: 'mobile',
    title: 'DarsakAI Student v1.0.0',
    description: 'تطبيق الهاتف للطلاب - متابعة الدرجات والحضور والاختبارات والملف الشخصي',
    descriptionEn: 'Student mobile app — grades, attendance, exams & profile',
    icon: Smartphone,
    color: '#00f3ff',
    files: [
      { name: 'DarsakAI-Student.apk', label: 'Android APK', size: '72 MB' },
    ],
    platform: 'Android ✓ / iOS قريباً',
    note: 'Signed release • com.darsak.ai • Camera only permission',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop v1.1.0',
    description: 'نظام إدارة الفصل للمعلم - students, grades, attendance, exams',
    descriptionEn: 'Teacher desktop app — full classroom & exam management',
    icon: Monitor,
    color: '#ccff00',
    files: [
      { name: 'DarsakAI-Setup.exe', label: 'Windows Installer', size: '14 MB' },
      { name: 'DarsakAI-Windows.zip', label: 'Windows Portable', size: '15 MB' },
      { name: 'DarsakAI-Linux.tar.gz', label: 'Linux Bundle', size: '14 MB' },
    ],
    platform: 'Windows ✓ / Linux ✓',
    note: 'Build 1.1.0.26 • Installer بـ GUI + Desktop Shortcut • Portable ZIP • Linux tar.gz',
  },
  {
    id: 'accounts',
    title: 'DarsakAI Accounts v1.0.0',
    description: 'نظام الحسابات والمالية للفصل',
    descriptionEn: 'Finance & accounts management',
    icon: Monitor,
    color: '#ff003c',
    size: '—',
    platform: 'Windows / Linux',
    note: 'يحتاج بناء',
  },
]

const features = [
  { ar: 'نظام الاختبارات الذكي (AI + PDF ← أسئلة)', en: 'Smart exam system (AI + PDF → questions)' },
  { ar: 'تقييم ذكي: تصحيح + تحليل نقاط القوة/الضعف', en: 'AI grading: auto-correct + strengths/weaknesses' },
  { ar: 'تايمر + أسئلة اختيار متعدد + مقالي', en: 'Timer + MCQs + essay questions' },
  { ar: 'نظام الاشتراكات (Basic 199 / Pro 499 / Unlimited 999)', en: 'Subscription system (Basic 199 / Pro 499 / Unlimited 999)' },
  { ar: 'دفع عبر فودافون كاش + تحميل الإيصال', en: 'Vodafone Cash payment + receipt upload' },
  { ar: 'إشعارات التفعيل والرفض (بوت تليجرام)', en: 'Activation/rejection notifications (Telegram bot)' },
  { ar: 'توليد كود اشتراك عبر بوت تليجرام', en: 'Subscription code generation via Telegram bot' },
  { ar: 'QR Code المسح الضوئي للحضور', en: 'QR code attendance scanning' },
  { ar: 'إدارة PIN للطلاب', en: 'Student PIN management' },
  { ar: 'Offline-first (Hive cache)', en: 'Offline-first (Hive cache)' },
  { ar: 'Signed APK + iOS support', en: 'Signed APK + iOS support' },
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
                  {app.size && (
                    <div className="flex justify-between text-[10px] hud-text">
                      <span className="text-[var(--text-muted)]">{isAr ? 'الحجم' : 'Size'}</span>
                      <span>{app.size}</span>
                    </div>
                  )}
                  {app.note && (
                    <p className="text-[10px] hud-text text-[var(--text-muted)] opacity-60 pt-2 border-t border-[var(--border)]">
                      {app.note}
                    </p>
                  )}

                  {/* Download button(s) */}
                  {'files' in app && app.files ? (
                    <div className="space-y-2">
                      {app.files.map((f: any) => (
                        <a
                          key={f.name}
                          href={`/${f.name}`}
                          download
                          className="w-full flex items-center justify-center gap-2 py-2 text-[11px] font-bold hud-text uppercase tracking-wider transition-all"
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
                          <Download className="w-3 h-3" />
                          {isAr ? f.label : f.label} ({f.size})
                        </a>
                      ))}
                    </div>
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

        {/* Features / Changelog */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
          className="mt-12 max-w-lg mx-auto"
        >
          <div
            className="p-6"
            style={{
              background: 'var(--card-bg)',
              border: '1px solid var(--border)',
            }}
          >
            <h3 className="text-sm font-bold mb-4 hud-text" style={{ fontFamily: 'var(--font-display)' }}>
              {isAr ? 'الميزات في v1.0.0' : 'v1.0.0 FEATURES'}
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {features.map((f, i) => (
                <div key={i} className="flex items-center gap-2 text-[10px] hud-text">
                  <span className="text-[var(--accent-2)]">▸</span>
                  <span className="text-[var(--text-muted)]">
                    {isAr ? f.ar : f.en}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </motion.div>

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
      <style>{`
        @media (max-width: 640px) {
          .fixed.top-4.left-4, .fixed.top-4 { font-size: 7px; }
          .hud-text { letter-spacing: 1px; }
        }
      `}</style>
    </div>
  )
}
