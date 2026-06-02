'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Smartphone, Monitor, Download, ArrowRight, Check, Sparkles } from 'lucide-react'

const apps = [
  {
    id: 'teacher',
    title: 'DarsakAI Teacher',
    subtitle: 'تطبيق المدرس',
    description: 'مسح باركود للحضور • دروس فيديو • ذكاء اصطناعي • إدارة كاملة للسنتر',
    icon: Smartphone,
    color: '#6366F1',
    bgColor: 'rgba(99,102,241,0.12)',
    file: '/teacher-v2.apk',
    label: 'Android APK v2.0.1',
    size: '~74 MB',
    platform: 'Android 10+',
    note: 'CameraX + ML Kit • تسجيل دائم • نظام متكامل',
  },
  {
    id: 'student',
    title: 'DarsakAI Student',
    subtitle: 'تطبيق الطالب',
    description: 'متابعة الدرجات • الحضور • الاختبارات • الملف الشخصي',
    icon: Smartphone,
    color: '#00f3ff',
    bgColor: 'rgba(0,243,255,0.12)',
    file: '/api/download/DarsakAI-Student.apk',
    label: 'Android APK v1.3.0',
    size: '~80 MB',
    platform: 'Android ✓',
    note: 'مساعد AI ذكي • متابعة الأداء • إشعارات',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop',
    subtitle: 'نظام الإدارة',
    description: 'طلاب • درجات • حضور • امتحانات • فواتير • Offline',
    icon: Monitor,
    color: '#10B981',
    bgColor: 'rgba(16,185,129,0.12)',
    files: [
      { name: 'DarsakAI-Setup.exe', label: 'Windows Installer', size: '~15 MB' },
      { name: 'DarsakAI-Windows.zip', label: 'Windows Portable', size: '~18 MB' },
    ],
    platform: 'Windows',
    note: 'Offline-first • SQLite • Auto-sync',
  },
]

export default function DownloadPage() {
  const router = useRouter()
  const [isAr, setIsAr] = useState(true)

  useEffect(() => { setIsAr(document.dir === 'rtl') }, [])

  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(180deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)' }}>
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-indigo-500/5 rounded-full blur-3xl" />
      </div>

      <div className="relative max-w-6xl mx-auto px-4 py-20">
        {/* Back */}
        <motion.button
          onClick={() => router.push('/')}
          initial={{ opacity: 0, x: -10 }}
          animate={{ opacity: 1, x: 0 }}
          className="text-sm text-slate-400 hover:text-white transition-colors mb-8 inline-flex items-center gap-1"
        >
          <ArrowRight className="w-4 h-4 rotate-180" />
          {isAr ? 'رجوع للرئيسية' : 'Back'}
        </motion.button>

        {/* Header */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="text-center mb-16">
          <span className="inline-flex items-center gap-2 px-4 py-1.5 bg-indigo-500/10 text-indigo-400 text-sm font-semibold rounded-full mb-4 border border-indigo-500/20">
            <Sparkles className="w-4 h-4" />
            {isAr ? 'التطبيقات' : 'Applications'}
          </span>
          <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">
            {isAr ? 'حمّل تطبيقات درسك AI' : 'Download DarsakAI Apps'}
          </h1>
          <p className="text-slate-400 text-lg max-w-2xl mx-auto">
            {isAr
              ? 'جميع التطبيقات متاحة للتحميل المباشر. اختر التطبيق المناسب وابدأ الآن.'
              : 'All apps available for direct download. Choose your app and get started.'}
          </p>
        </motion.div>

        {/* App Cards */}
        <div className="grid md:grid-cols-3 gap-6">
          {apps.map((app, i) => (
            <motion.div
              key={app.id}
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 * (i + 1) }}
              className="relative group"
            >
              <div className="absolute inset-0 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-500"
                style={{ background: `radial-gradient(circle at center, ${app.color}20, transparent 70%)` }}
              />
              <div className="relative bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 flex flex-col h-full hover:border-white/[0.15] transition-all duration-300">
                {/* Icon */}
                <div className="w-14 h-14 rounded-2xl flex items-center justify-center mb-5"
                  style={{ background: app.bgColor }}>
                  <app.icon className="w-7 h-7" style={{ color: app.color }} />
                </div>

                {/* Title */}
                <div className="mb-1">
                  <span className="text-xs font-medium px-2 py-0.5 rounded-full" style={{ color: app.color, background: `${app.color}15` }}>
                    {app.subtitle}
                  </span>
                </div>
                <h2 className="text-xl font-bold text-white mb-2">{app.title}</h2>
                <p className="text-slate-400 text-sm mb-6 leading-relaxed flex-1">
                  {app.description}
                </p>

                {/* Meta */}
                <div className="space-y-2 mb-6">
                  <div className="flex justify-between text-xs">
                    <span className="text-slate-500">{isAr ? 'المنصة' : 'Platform'}</span>
                    <span className="text-slate-300">{app.platform}</span>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-slate-500">{isAr ? 'الحجم' : 'Size'}</span>
                    <span className="text-slate-300">{app.size || '—'}</span>
                  </div>
                </div>

                {app.note && (
                  <p className="text-[10px] text-slate-500 mb-4 pb-4 border-b border-white/[0.06]">
                    {app.note}
                  </p>
                )}

                {/* Download Button(s) */}
                {'file' in app && app.file ? (
                  <a
                    href={app.file}
                    className="flex items-center justify-center gap-2 w-full py-3 rounded-xl text-sm font-semibold text-white transition-all hover:scale-[1.02] active:scale-95"
                    style={{ background: `linear-gradient(135deg, ${app.color}, ${app.color}cc)` }}
                  >
                    <Download className="w-4 h-4" />
                    {app.label} ({app.size})
                  </a>
                ) : 'files' in app && app.files ? (
                  <div className="space-y-2">
                    {app.files.map((f: any) => (
                      <a
                        key={f.name}
                        href={`/api/download/${f.name}`}
                        className="flex items-center justify-center gap-2 w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-all hover:scale-[1.02] active:scale-95"
                        style={{ background: `linear-gradient(135deg, ${app.color}, ${app.color}cc)` }}
                      >
                        <Download className="w-4 h-4" />
                        {f.label} ({f.size})
                      </a>
                    ))}
                  </div>
                ) : (
                  <div className="flex items-center justify-center gap-2 w-full py-3 rounded-xl text-sm text-slate-500 bg-white/[0.02] border border-white/[0.05] cursor-not-allowed">
                    {isAr ? 'قريباً' : 'Coming Soon'}
                  </div>
                )}
              </div>
            </motion.div>
          ))}
        </div>

        {/* Footer */}
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          className="text-center text-xs text-slate-500 mt-16"
        >
          {isAr
            ? 'التطبيقات تُحدّث باستمرار • تابع التحديثات من داخل التطبيق'
            : 'Apps are updated regularly • Check for updates from within the app'}
        </motion.p>
      </div>
    </div>
  )
}
