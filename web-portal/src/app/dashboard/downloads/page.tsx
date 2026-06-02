'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Smartphone, Monitor, Download } from 'lucide-react'

const apps = [
  {
    id: 'mobile',
    title: 'DarsakAI Student v1.3.0',
    description: 'تطبيق الهاتف للطلاب — متابعة الدرجات والحضور والاختبارات',
    icon: Smartphone,
    gradient: 'linear-gradient(135deg, #06b6d4, #22d3ee)',
    files: [
      { name: 'DarsakAI-Student.apk', label: 'Android APK v1.3.0', size: '~80 MB' },
    ],
    platform: 'Android',
  },
  {
    id: 'teacher',
    title: 'DarsakAI Teacher v1.2.4',
    description: 'تطبيق المدرس — مسح باركود للحضور بدون نظام PC',
    icon: Monitor,
    gradient: 'linear-gradient(135deg, #f97316, #fb923c)',
    files: [
      { name: 'DarsakAI-Teacher-v1.2.4.apk', label: 'Android APK v1.2.4', size: '~34 MB' },
    ],
    platform: 'Android 10+',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop v2.0.0',
    description: 'نظام إدارة الفصل للمعلم — students, grades, attendance, exams, invoices',
    icon: Monitor,
    gradient: 'linear-gradient(135deg, #6366f1, #8b5cf6)',
    files: [
      { name: 'DarsakAI-Setup.exe', label: 'Windows Installer v2.0.0', size: '~15 MB' },
      { name: 'DarsakAI-Windows.zip', label: 'Windows Portable v2.0.0', size: '~18 MB' },
    ],
    platform: 'Windows',
  },
]

export default function DownloadsPage() {
  const [isAr] = useState(true)

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      className="space-y-6"
    >
      <div>
        <h1 className="text-3xl font-bold text-white">التطبيقات</h1>
        <p className="text-slate-400 mt-1">حمّل التطبيقات الخاصة بنظام درسك أي</p>
      </div>

      <div className="grid md:grid-cols-3 gap-6">
        {apps.map((app, i) => (
          <motion.div
            key={app.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 flex flex-col"
          >
            <div
              className="w-12 h-12 rounded-xl flex items-center justify-center mb-4"
              style={{
                background: 'rgba(255,255,255,0.03)',
                border: '1px solid rgba(255,255,255,0.08)',
              }}
            >
              <app.icon className="w-6 h-6" style={{ color: '#a5b4fc' }} />
            </div>

            <h2 className="text-lg font-bold text-white mb-1">{app.title}</h2>
            <p className="text-xs text-slate-400 mb-4 leading-relaxed">{app.description}</p>

            <div className="mt-auto space-y-3">
              <div className="flex justify-between text-xs">
                <span className="text-slate-400">المنصة</span>
                <span className="text-indigo-300">{app.platform}</span>
              </div>

              {'files' in app && app.files ? (
                <div className="space-y-2">
                  {app.files.map((f: any) => (
                    <a
                      key={f.name}
                      href={`/api/download/${f.name}`}
                      download
                      className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-xs font-bold text-white transition-all hover:opacity-90 active:scale-[0.97]"
                      style={{ background: app.gradient }}
                    >
                      <Download className="w-3 h-3" />
                      {f.label} ({f.size})
                    </a>
                  ))}
                </div>
              ) : (
                <div className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-xs border border-white/[0.08] text-slate-500 cursor-not-allowed">
                  قريباً
                </div>
              )}
            </div>
          </motion.div>
        ))}
      </div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.4, ease: [0.16, 1, 0.3, 1] }}
        className="text-center"
      >
        <p className="text-xs text-slate-500">
          التطبيقات تحت التطوير • للاستخدام الداخلي
        </p>
      </motion.div>
    </motion.div>
  )
}
