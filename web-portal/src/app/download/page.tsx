'use client'

import Image from 'next/image'
import Link from 'next/link'

const apps = [
  {
    t: 'تطبيق المعلمين',
    d: 'إدارة الطلاب، الامتحانات، الكورسات، الحضور، الفواتير، والتقارير الذكية',
    v: 'v2.5.3',
    s: '78 MB',
    f: 'https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/app-release.apk',
    n: 'DarsakAI-Teacher-v2.5.3.apk',
    color: 'white',
    icon: (
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
        <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
      </svg>
    ),
  },
  {
    t: 'تطبيق الطلاب',
    d: 'متابعة الدرجات، الحضور، الاختبارات، الكورسات، ومدرس AI ذكي، وفصل ذكي بالذكاء الاصطناعي',
    v: 'v1.8.0',
    s: '71 MB',
    f: 'https://github.com/rootkali-cmd/Darsak-ai/releases/download/student-v1.8.0/app-release.apk',
    n: 'DarsakAI-Student-v1.8.0.apk',
    color: 'white',
    icon: (
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" /><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
      </svg>
    ),
  },
]

export default function DownloadPage() {
  return (
    <div className="min-h-screen bg-black text-white/70">
      <div className="max-w-4xl mx-auto px-4 py-20">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/40 hover:text-white/70 transition-colors mb-10">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
          الرئيسية
        </Link>

        <div className="flex items-center gap-3 mb-4">
          <Image src="/icon.png" alt="DarsakAI" width={40} height={40} className="rounded-xl" style={{ width: 40, height: 40 }} />
          <h1 className="text-3xl font-black text-white">تحميل التطبيق</h1>
        </div>
        <p className="text-sm text-white/40 mb-12">تطبيقان منفصلان — واحد للمعلمين وواحد للطلاب</p>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {apps.map((app) => (
            <div key={app.t} className="p-7 rounded-2xl border border-white/[0.06] hover:border-white/[0.12] transition-all duration-500 flex flex-col items-center text-center">
              <div className="w-16 h-16 rounded-2xl overflow-hidden mb-5 bg-white/10 flex items-center justify-center text-white/60">
                {app.icon}
              </div>
              <h3 className="text-lg font-bold text-white mb-2">{app.t}</h3>
              <p className="text-sm text-white/40 mb-5 leading-relaxed">{app.d}</p>
              <div className="flex items-center gap-2 text-xs text-white/30 mb-5">
                <span className="px-2 py-0.5 bg-white/5 rounded">Android</span>
                <span>•</span><span>{app.v}</span><span>•</span><span>{app.s}</span>
              </div>
              <a href={app.f.startsWith('http') ? app.f : `https://darsak-backend.fly.dev/api/downloads/${app.f}`} download={app.n} className="w-full py-3 px-6 bg-white text-black font-bold rounded-full hover:bg-gray-200 transition-colors text-sm cursor-pointer">
                تحميل APK
              </a>
            </div>
          ))}
        </div>

        <div className="mt-10 p-6 rounded-2xl border border-white/[0.06] bg-white/[0.02]">
          <h3 className="text-base font-bold text-white mb-2">متطلبات</h3>
          <ul className="list-disc list-inside space-y-1 text-sm text-white/40">
            <li>أندرويد 7.0 أو أحدث</li>
            <li>اتصال بالإنترنت للتحميل فقط — التطبيق يعمل بدون إنترنت بعد التثبيت</li>
            <li>صلاحيات: الكاميرا (للباركود)، الإشعارات، التخزين</li>
          </ul>
        </div>
      </div>
    </div>
  )
}
