'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Section } from '@/components/ui'
import { Smartphone, Monitor, Download, Sparkles } from 'lucide-react'

const apps = [
  {
    id: 'mobile',
    title: 'DarsakAI Student v1.2.0',
    description: 'تطبيق الهاتف للطلاب — متابعة الدرجات والحضور والاختبارات',
    icon: Smartphone,
    color: '#00f3ff',
    files: [
      { name: 'DarsakAI-Student-v1.2.0+3-universal.apk', label: 'Android APK (Universal)', size: '82 MB' },
    ],
    platform: 'Android',
  },
  {
    id: 'desktop',
    title: 'DarsakAI Desktop v1.2.0',
    description: 'نظام إدارة الفصل للمعلم — students, grades, attendance',
    icon: Monitor,
    color: '#ccff00',
    files: [
      { name: 'DarsakAI-Setup.exe', label: 'Windows Installer', size: '14 MB' },
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
        <p className="text-text-secondary mt-1">حمّل التطبيقات الخاصة بنظام درسك أي</p>
      </Section>

      <div className="grid md:grid-cols-3 gap-6">
        {apps.map((app, i) => (
          <motion.div
            key={app.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="brutal-card p-6 flex flex-col relative"
            style={{ background: 'var(--card-bg)', position: 'relative' }}
          >
            <div className="absolute top-0 left-0 w-4 h-4 border-t border-l" style={{ borderColor: app.color }} />
            <div className="absolute top-0 right-0 w-4 h-4 border-t border-r" style={{ borderColor: app.color }} />
            <div className="absolute bottom-0 left-0 w-4 h-4 border-b border-l" style={{ borderColor: app.color }} />
            <div className="absolute bottom-0 right-0 w-4 h-4 border-b border-r" style={{ borderColor: app.color }} />

            <div className="w-12 h-12 flex items-center justify-center mb-4" style={{ border: `1px solid ${app.color}` }}>
              <app.icon className="w-6 h-6" style={{ color: app.color }} />
            </div>

            <h2 className="text-lg font-bold mb-1">{app.title}</h2>
            <p className="text-xs hud-text text-text-muted mb-4 leading-relaxed">{app.description}</p>

            <div className="mt-auto space-y-3">
              <div className="flex justify-between text-[10px] hud-text">
                <span className="text-text-muted">المنصة</span>
                <span style={{ color: app.color }}>{app.platform}</span>
              </div>

              {'files' in app && app.files ? (
                <div className="space-y-2">
                  {app.files.map((f: any) => (
                    <a
                      key={f.name}
                      href={`https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/${f.name}`}
                      download
                      className="w-full flex items-center justify-center gap-2 py-2 text-[11px] font-bold hud-text uppercase tracking-wider transition-all"
                      style={{ background: app.color, color: '#000', border: `1px solid ${app.color}` }}
                      onMouseEnter={(e) => { e.currentTarget.style.opacity = '0.8' }}
                      onMouseLeave={(e) => { e.currentTarget.style.opacity = '1' }}
                    >
                      <Download className="w-3 h-3" />
                      {f.label} ({f.size})
                    </a>
                  ))}
                </div>
              ) : (
                <div className="w-full flex items-center justify-center gap-2 py-2.5 text-xs font-bold hud-text uppercase tracking-wider cursor-not-allowed"
                  style={{ border: '1px solid var(--border)', color: 'var(--text-muted)', opacity: 0.5 }}
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  قريباً
                </div>
              )}
            </div>
          </motion.div>
        ))}
      </div>

      <Section className="text-center">
        <p className="text-xs hud-text text-text-muted opacity-50">
          التطبيقات تحت التطوير • للاستخدام الداخلي
        </p>
      </Section>
    </div>
  )
}
