'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Section } from '@/components/ui'
import { Smartphone, Monitor, Download } from 'lucide-react'

const apps = [
  {
    id: 'mobile',
    title: 'DarsakAI Student v1.3.0',
    description: 'تطبيق الهاتف للطلاب — متابعة الدرجات والحضور والاختبارات',
    icon: Smartphone,
    color: '#00f3ff',
    files: [
      { name: 'DarsakAI-Student-v1.3.0+5-universal.apk', label: 'Android APK (Universal)', size: '~80 MB' },
    ],
    platform: 'Android',
  },
  {
    id: 'teacher',
    title: 'DarsakAI Teacher v1.1.0',
    description: 'تطبيق المدرس — مسح باركود للحضور بدون نظام PC',
    icon: Monitor,
    color: '#FF6B00',
    files: [
      { name: 'DarsakAI-Teacher-v1.1.0+2.apk', label: 'Android APK (Teacher)', size: '~70 MB' },
    ],
    platform: 'Android',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop v2.0.0',
    description: 'نظام إدارة الفصل للمعلم — students, grades, attendance, exams, invoices',
    icon: Monitor,
    color: '#ccff00',
    files: [
      { name: 'DarsakAI-Setup-v2.0.0+1.exe', label: 'Windows Installer', size: '~15 MB' },
      { name: 'DarsakAI-Windows-v2.0.0+1.zip', label: 'Windows Portable (ZIP)', size: '~18 MB' },
    ],
    platform: 'Windows',
  },
]

export default function DownloadsPage() {
  const [isAr] = useState(true)

  return (
    <div className="space-y-6">
      <Section>
        <h1 className="text-3xl font-bold">التطبيقات</h1>
        <p className="text-[var(--text-muted)] mt-1">حمّل التطبيقات الخاصة بنظام درسك أي</p>
      </Section>

      <div className="grid md:grid-cols-3 gap-6">
        {apps.map((app, i) => (
          <motion.div
            key={app.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="card p-6 flex flex-col"
            style={{ borderColor: `color-mix(in srgb, ${app.color} 30%, transparent)` }}
          >
            <div className="w-12 h-12 flex items-center justify-center mb-4" style={{ border: `1px solid ${app.color}` }}>
              <app.icon className="w-6 h-6" style={{ color: app.color }} />
            </div>

            <h2 className="text-lg font-bold mb-1">{app.title}</h2>
            <p className="text-xs text-[var(--text-muted)] mb-4 leading-relaxed">{app.description}</p>

            <div className="mt-auto space-y-3">
              <div className="flex justify-between text-xs">
                <span className="text-[var(--text-muted)]">المنصة</span>
                <span style={{ color: app.color }}>{app.platform}</span>
              </div>

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
                  قريباً
                </div>
              )}
            </div>
          </motion.div>
        ))}
      </div>

      <Section className="text-center">
        <p className="text-xs text-[var(--text-muted)] opacity-50">
          التطبيقات تحت التطوير • للاستخدام الداخلي
        </p>
      </Section>
    </div>
  )
}
