'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Smartphone, Monitor, Download } from 'lucide-react'

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
    title: 'DarsakAI Student v1.2.1',
    description: 'تطبيق الهاتف للطلاب - متابعة الدرجات والحضور والاختبارات والملف الشخصي',
    descriptionEn: 'Student mobile app — grades, attendance, exams & profile',
    icon: Smartphone,
    color: '#00f3ff',
    files: [
      { name: 'DarsakAI-Student-v1.2.1+4-universal.apk', label: 'Android APK (Universal)', size: '82 MB' },
    ],
    platform: 'Android ✓',
    note: 'إصدار 1.2.0 • مساعد AI ذكي • Camera only permission',
  },
  {
    id: 'teacher',
    title: 'DarsakAI Teacher v1.0.0',
    description: 'تطبيق المدرس - مسح QR للحضور بدون نظام PC',
    descriptionEn: 'Teacher mobile app — QR attendance scanner without PC',
    icon: Monitor,
    color: '#FF6B00',
    files: [
      { name: 'DarsakAI-Teacher.apk', label: 'Android APK (Teacher)', size: '~15 MB' },
    ],
    platform: 'Android ✓',
    note: 'Build 1.0.0 • QR Scanner • Glass Notifications • Offline-ready',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop v1.4.0',
    description: 'نظام إدارة السنتر - طلاب، درجات، حضور، امتحانات، فواتير',
    descriptionEn: 'Learning center management — students, grades, attendance, exams',
    icon: Monitor,
    color: '#ccff00',
    files: [
      { name: 'DarsakAI-Setup.exe', label: 'Windows Installer', size: '~20 MB' },
      { name: 'DarsakAI-Windows.zip', label: 'Windows Portable (ZIP)', size: '~25 MB' },
    ],
    platform: 'Windows ✓',
    note: 'Build 1.4.0 • Offline-first • SQLite • Auto-sync • QR + PIN',
  },
]

const features = [
  { ar: 'مساعد AI ذكي (5 أسئلة/يوم) - you.com', en: 'Smart AI assistant (5 questions/day) - you.com' },
  { ar: 'نظام التحديث التلقائي (Auto-update مع شريط التقدم)', en: 'Auto-update system with progress bar' },
  { ar: 'معرف حساب مميز (UUID) للتواصل مع الدعم', en: 'Unique account ID (UUID) for support' },
  { ar: 'قفل الميزات لحين الاشتراك في باقة', en: 'Feature gating until subscription activated' },
  { ar: 'دفع عبر فودافون كاش + صورة الإيصال + تأكيد', en: 'Vodafone Cash payment + receipt upload + confirm' },
  { ar: 'إشعارات التفعيل والرفض (بوت تليجرام)', en: 'Activation/rejection notifications (Telegram bot)' },
  { ar: 'توليد كود اشتراك عبر بوت تليجرام', en: 'Subscription code generation via Telegram bot' },
  { ar: 'نظام الاختبارات الذكي (AI + PDF ← أسئلة)', en: 'Smart exam system (AI + PDF → questions)' },
  { ar: 'تقييم ذكي: تصحيح + تحليل نقاط القوة/الضعف', en: 'AI grading: auto-correct + strengths/weaknesses' },
  { ar: 'نظام الاشتراكات (Basic 199 / Pro 499 / Unlimited 999)', en: 'Subscription system (Basic 199 / Pro 499 / Unlimited 999)' },
  { ar: 'QR Code المسح الضوئي للحضور', en: 'QR code attendance scanning' },
  { ar: 'إدارة PIN للطلاب', en: 'Student PIN management' },
  { ar: 'Offline-first مع كشف الانترنت', en: 'Offline-first with internet detection' },
  { ar: 'Signed APK + تحديثات أمنية', en: 'Signed APK + security updates' },
]

export default function DownloadPage() {
  const router = useRouter()
  const [isAr, setIsAr] = useState(true)

  useEffect(() => {
    setIsAr(document.dir === 'rtl')
  }, [])

  return (
    <div className="min-h-screen py-16 px-4">
      <button
        onClick={() => router.push('/')}
        className="fixed top-4 left-4 z-50 text-sm text-[var(--text-muted)] hover:text-[var(--accent)] transition-colors"
      >
        ← {isAr ? 'رجوع' : 'BACK'}
      </button>

      <div className="w-full max-w-5xl mx-auto mt-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <h1 className="text-3xl font-bold mb-2">DOWNLOADS</h1>
          <p className="text-sm text-[var(--text-muted)]">
            {isAr ? 'حمّل تطبيقات درسك أي' : 'Download DarsakAI apps'}
          </p>
        </motion.div>

        <div className="grid md:grid-cols-3 gap-6">
          {apps.map((app, i) => (
            <motion.div
              key={app.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 * (i + 1) }}
              className="card p-6 flex flex-col h-full"
              style={{ borderColor: `color-mix(in srgb, ${app.color} 25%, transparent)` }}
            >
              <div className="w-12 h-12 flex items-center justify-center mb-4" style={{ border: `1px solid ${app.color}` }}>
                <app.icon className="w-6 h-6" style={{ color: app.color }} />
              </div>

              <h2 className="text-lg font-bold mb-1">{app.title}</h2>

              <p className="text-xs text-[var(--text-muted)] mb-4 leading-relaxed">
                {isAr ? app.description : app.descriptionEn}
              </p>

              <div className="mt-auto space-y-3">
                <div className="flex justify-between text-xs">
                  <span className="text-[var(--text-muted)]">{isAr ? 'المنصة' : 'Platform'}</span>
                  <span style={{ color: app.color }}>{app.platform}</span>
                </div>
                {app.size && (
                  <div className="flex justify-between text-xs">
                    <span className="text-[var(--text-muted)]">{isAr ? 'الحجم' : 'Size'}</span>
                    <span>{app.size}</span>
                  </div>
                )}
                {app.note && (
                  <p className="text-[10px] text-[var(--text-muted)] opacity-60 pt-2 border-t border-[var(--card-border)]">
                    {app.note}
                  </p>
                )}

                {'files' in app && app.files ? (
                  <div className="space-y-2">
                    {app.files.map((f: any) => (
                      <a
                        key={f.name}
                        href={`https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/${f.name}`}
                        download
                        className="w-full flex items-center justify-center gap-2 py-2 text-xs font-bold transition-opacity"
                        style={{ background: app.color, color: '#000' }}
                        onMouseEnter={(e) => { e.currentTarget.style.opacity = '0.8' }}
                        onMouseLeave={(e) => { e.currentTarget.style.opacity = '1' }}
                      >
                        <Download className="w-3 h-3" />
                        {f.label} ({f.size})
                      </a>
                    ))}
                  </div>
                ) : (
                  <div className="w-full flex items-center justify-center gap-2 py-2.5 text-xs cursor-not-allowed"
                    style={{ border: '1px solid var(--card-border)', color: 'var(--text-muted)', opacity: 0.5 }}
                  >
                    {isAr ? 'قريباً' : 'COMING SOON'}
                  </div>
                )}
              </div>
            </motion.div>
          ))}
        </div>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.6 }}
          className="mt-12 max-w-lg mx-auto"
        >
          <div className="card p-6">
            <h3 className="text-sm font-bold mb-4">
              {isAr ? 'الميزات الجديدة v1.4.0' : 'NEW FEATURES v1.4.0'}
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {features.map((f, i) => (
                <div key={i} className="flex items-center gap-2 text-xs">
                  <span className="text-[var(--accent-2)]">▸</span>
                  <span className="text-[var(--text-muted)]">
                    {isAr ? f.ar : f.en}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          className="text-center text-xs text-[var(--text-muted)] mt-8 opacity-50"
        >
          {isAr
            ? 'التطبيقات تحت التطوير • للاستخدام الداخلي'
            : 'Apps are under active development • For internal use'}
        </motion.p>
      </div>
    </div>
  )
}
