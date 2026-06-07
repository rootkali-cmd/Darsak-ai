'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Smartphone, Monitor, Download, ArrowRight, Sparkles, School, User } from 'lucide-react'

const teacherApps = [
  {
    id: 'teacher',
    title: 'DarsakAI Teacher v3.0.2',
    subtitle: 'تطبيق المدرس',
    description: 'مسح باركود للحضور • دروس فيديو • ذكاء اصطناعي • إدارة كاملة للسنتر',
    icon: User,
    color: '#6366F1',
    bgColor: 'rgba(99,102,241,0.12)',
    file: 'https://github.com/rootkali-cmd/Darsak-ai/releases/download/v3.0.2/teacher-v3.0.2.apk',
    label: 'Download',
    size: '~75 MB',
    platform: 'Android 10+',
    note: 'v3.0.2 • إصلاح الوضع الفاتح والداكن • نظام حظر المحاولات',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop',
    subtitle: 'نظام إدارة السنتر',
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

const studentApps = [
  {
    id: 'student',
    title: 'DarsakAI Student v1.4.1',
    subtitle: 'تطبيق الطالب',
    description: 'متابعة الدرجات • الحضور • الاختبارات • الملف الشخصي',
    icon: School,
    color: '#00f3ff',
    bgColor: 'rgba(0,243,255,0.12)',
    file: 'https://github.com/rootkali-cmd/Darsak-ai/releases/download/v3.0.2/student-v1.4.1.apk',
    label: 'Download',
    size: '~73 MB',
    platform: 'Android',
    note: 'v1.4.1 • تصميم iOS زجاجي • إصلاح تسجيل الدخول • اتصال حقيقي',
  },
]

function AppCard({ app, isAr }: { app: any; isAr: boolean }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      animate={{ opacity: 1, y: 0 }}
      className="relative group"
    >
      <div className="absolute inset-0 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-500"
        style={{ background: `radial-gradient(circle at center, ${app.color}20, transparent 70%)` }}
      />
      <div className="relative bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 flex flex-col h-full hover:border-white/[0.15] transition-all duration-300">
        <div className="w-14 h-14 rounded-2xl flex items-center justify-center mb-5" style={{ background: app.bgColor }}>
          <app.icon className="w-7 h-7" style={{ color: app.color }} />
        </div>
        <span className="text-xs font-medium px-2 py-0.5 rounded-full mb-1 w-fit" style={{ color: app.color, background: `${app.color}15` }}>
          {app.subtitle}
        </span>
        <h2 className="text-xl font-bold text-white mb-2">{app.title}</h2>
        <p className="text-slate-400 text-sm mb-6 leading-relaxed flex-1">{app.description}</p>
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
        {app.note && <p className="text-[10px] text-slate-500 mb-4 pb-4 border-b border-white/[0.06]">{app.note}</p>}
        {'file' in app && app.file ? (
          <a href={app.file} className="flex items-center justify-center gap-2 w-full py-3 rounded-xl text-sm font-semibold text-white transition-all hover:scale-[1.02] active:scale-95"
            style={{ background: `linear-gradient(135deg, ${app.color}, ${app.color}cc)` }}>
            <Download className="w-4 h-4" /> {app.label} ({app.size})
          </a>
        ) : 'files' in app && app.files ? (
          <div className="space-y-2">
            {app.files.map((f: any) => (
              <a key={f.name} href={`/api/download/${f.name}`}
                className="flex items-center justify-center gap-2 w-full py-2.5 rounded-xl text-sm font-semibold text-white transition-all hover:scale-[1.02] active:scale-95"
                style={{ background: `linear-gradient(135deg, ${app.color}, ${app.color}cc)` }}>
                <Download className="w-4 h-4" /> {f.label} ({f.size})
              </a>
            ))}
          </div>
        ) : null}
      </div>
    </motion.div>
  )
}

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
        <motion.button onClick={() => router.push('/')} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }}
          className="text-sm text-slate-400 hover:text-white transition-colors mb-8 inline-flex items-center gap-1">
          <ArrowRight className="w-4 h-4 rotate-180" /> {isAr ? 'رجوع' : 'Back'}
        </motion.button>

        {/* Header */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="text-center mb-16">
          <span className="inline-flex items-center gap-2 px-4 py-1.5 bg-indigo-500/10 text-indigo-400 text-sm font-semibold rounded-full mb-4 border border-indigo-500/20">
            <Sparkles className="w-4 h-4" /> {isAr ? 'التطبيقات' : 'Applications'}
          </span>
          <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">
            {isAr ? 'حمّل تطبيقات درسك AI' : 'Download DarsakAI Apps'}
          </h1>
          <p className="text-slate-400 text-lg max-w-2xl mx-auto">
            {isAr ? 'جميع التطبيقات متاحة للتحميل المباشر' : 'All apps available for direct download'}
          </p>
        </motion.div>

        {/* Teacher Section */}
        <div className="mb-20" id="teacher">
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.1 }}
            className="flex items-center gap-3 mb-8">
            <div className="h-10 w-1 rounded-full bg-indigo-500" />
            <div>
              <h2 className="text-2xl font-bold text-white">{isAr ? 'تطبيقات المدرس والنظام' : 'Teacher & System Apps'}</h2>
              <p className="text-slate-400 text-sm mt-1">{isAr ? 'لإدارة السنتر التعليمي' : 'For center management'}</p>
            </div>
          </motion.div>
          <div className="grid md:grid-cols-2 gap-6">
            {teacherApps.map((app, i) => (
              <div key={app.id} style={{ animationDelay: `${0.2 + i * 0.1}s` }}>
                <AppCard app={app} isAr={isAr} />
              </div>
            ))}
          </div>
        </div>

        {/* Divider */}
        <div className="flex items-center gap-4 mb-20">
          <div className="flex-1 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
          <span className="text-slate-500 text-sm">{isAr ? 'المزيد' : 'More'}</span>
          <div className="flex-1 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
        </div>

        {/* Student Section */}
        <div id="student">
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.3 }}
            className="flex items-center gap-3 mb-8">
            <div className="h-10 w-1 rounded-full bg-cyan-400" />
            <div>
              <h2 className="text-2xl font-bold text-white">{isAr ? 'تطبيق الطالب' : 'Student App'}</h2>
              <p className="text-slate-400 text-sm mt-1">{isAr ? 'لمتابعة الأداء والدرجات' : 'Track performance & grades'}</p>
            </div>
          </motion.div>
          <div className="grid md:grid-cols-1 max-w-md">
            {studentApps.map((app) => (
              <AppCard key={app.id} app={app} isAr={isAr} />
            ))}
          </div>
        </div>

        <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.8 }}
          className="text-center text-xs text-slate-500 mt-20">
          {isAr ? 'التطبيقات تُحدّث باستمرار • تابع التحديثات من داخل التطبيق' : 'Apps are updated regularly'}
        </motion.p>
      </div>
    </div>
  )
}

