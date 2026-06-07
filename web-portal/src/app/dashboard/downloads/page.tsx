'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Smartphone, Monitor, Download } from 'lucide-react'

const apps = [
  {
    id: 'teacher',
    title: 'DarsakAI Teacher v3.0.2',
    description: 'تطبيق المدرس — مسح باركود • دروس فيديو • ذكاء اصطناعي • إدارة كاملة',
    icon: Monitor,
    gradient: 'linear-gradient(135deg, #6366F1, #818CF8)',
    file: 'https://github.com/rootkali-cmd/Darsak-ai/releases/download/v3.0.2/teacher-v3.0.2.apk',
    label: 'Download',
    size: '~75 MB',
    platform: 'Android 10+',
  },
  {
    id: 'student',
    title: 'DarsakAI Student v1.4.1',
    description: 'تطبيق الطالب — متابعة الدرجات • الحضور • الاختبارات • الملف الشخصي',
    icon: Smartphone,
    gradient: 'linear-gradient(135deg, #06b6d4, #22d3ee)',
    file: 'https://github.com/rootkali-cmd/Darsak-ai/releases/download/v3.0.2/student-v1.4.1.apk',
    label: 'Download',
    size: '~77 MB',
    platform: 'Android',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop v2.0.0',
    description: 'نظام إدارة السنتر — طلاب • درجات • حضور • امتحانات • فواتير',
    icon: Monitor,
    gradient: 'linear-gradient(135deg, #10B981, #34D399)',
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
    <motion.div initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }}
      className="relative max-w-3xl mx-auto">
      <div className="text-center mb-10">
        <h1 className="text-2xl font-bold text-white">{isAr ? 'التطبيقات' : 'Downloads'}</h1>
        <p className="text-slate-400 text-sm mt-1">{isAr ? 'حمّل التطبيقات الخاصة بنظام درسك AI' : 'Download DarsakAI apps'}</p>
      </div>

      <div className="space-y-4">
        {apps.map((app) => (
          <div key={app.id} className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 flex flex-col md:flex-row md:items-center gap-4">
            <div className="w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0"
              style={{ background: app.gradient }}>
              <app.icon className="w-6 h-6 text-white" />
            </div>
            <div className="flex-1">
              <h3 className="text-white font-bold">{app.title}</h3>
              <p className="text-slate-400 text-xs mt-1">{app.description}</p>
              <div className="flex gap-4 mt-2 text-xs text-slate-500">
                <span>{app.platform}</span>
                <span>{app.size || '—'}</span>
              </div>
            </div>
            {'file' in app && app.file ? (
              <a href={app.file}
                className="flex items-center gap-2 px-5 py-2.5 text-sm font-semibold text-white rounded-xl transition-all hover:scale-105 active:scale-95 flex-shrink-0"
                style={{ background: app.gradient }}>
                <Download className="w-4 h-4" /> {app.label}
              </a>
            ) : 'files' in app && app.files ? (
              <div className="flex gap-2 flex-shrink-0">
                {app.files.map((f: any) => (
                  <a key={f.name} href={`/api/download/${f.name}`}
                    className="flex items-center gap-2 px-5 py-2.5 text-sm font-semibold text-white rounded-xl transition-all hover:scale-105 active:scale-95"
                    style={{ background: app.gradient }}>
                    <Download className="w-4 h-4" /> {f.label}
                  </a>
                ))}
              </div>
            ) : null}
          </div>
        ))}
      </div>
    </motion.div>
  )
}
