'use client'

import { useState, useEffect, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import Image from 'next/image'
import Link from 'next/link'
import { CanvasRevealEffect } from '@/components/ui/canvas-reveal-effect'

const features = [
  { num: '01', title: 'إدارة الطلاب', desc: 'إضافة الطلاب بالباركود، متابعة بياناتهم، تواصل مع أولياء الأمور.' },
  { num: '02', title: 'الحضور والغياب', desc: 'سجل حضور الطلاب بالباركود أو يدوياً مع تقارير يومية.' },
  { num: '03', title: 'الامتحانات والتصحيح', desc: 'إنشاء امتحانات، تصحيح آلي بالذكاء الاصطناعي، وتحليل النتائج.' },
  { num: '04', title: 'الكورسات التعليمية', desc: 'رفع فيديوهات وملفات، أبواب ودروس، مع حماية المحتوى.' },
  { num: '05', title: 'الفواتير والمصاريف', desc: 'تحصيل المصاريف إلكترونياً مع تقارير مالية مفصلة.' },
  { num: '06', title: 'تحليلات AI', desc: 'تحليل أداء كل طالب بالذكاء الاصطناعي — نقاط القوة والضعف.' },
]

const pricingPlans = [
  { name: 'الأساسي', price: '350', features: ['100 طالب', '5 طلبات AI يومياً', '15GB تخزين', 'حضور QR', 'درجات'], popular: false },
  { name: 'المحترف', price: '750', features: ['400 طالب', '10 طلبات AI يومياً', '60GB تخزين', '2 مساعدين', 'كورسات', 'تقارير AI'], popular: true },
  { name: 'المتكاملة', price: '1250', features: ['1000 طالب', '20 طلب AI يومياً', '200GB تخزين', '5 مساعدين', 'تحضير AI', 'دعم VIP'], popular: false },
]

function AnimatedNavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <a href={href} className="relative text-sm text-gray-300 hover:text-white transition-colors duration-300">
      {children}
    </a>
  )
}

function Navbar() {
  const [isOpen, setIsOpen] = useState(false)
  const [shapeClass, setShapeClass] = useState('rounded-full')
  const timeoutRef = useRef<NodeJS.Timeout | null>(null)

  useEffect(() => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current)
    if (isOpen) setShapeClass('rounded-2xl')
    else timeoutRef.current = setTimeout(() => setShapeClass('rounded-full'), 300)
    return () => { if (timeoutRef.current) clearTimeout(timeoutRef.current) }
  }, [isOpen])

  const navLinks = [
    { label: 'المميزات', href: '#features' },
    { label: 'الباقات', href: '#pricing' },
    { label: 'تحميل', href: '#download' },
    { label: 'تواصل', href: '#contact' },
  ]

  return (
    <header className={`fixed top-5 left-1/2 -translate-x-1/2 z-50 flex items-center px-6 py-3 backdrop-blur-sm ${shapeClass} border border-[#333] bg-[rgba(31,31,31,0.57)] w-[calc(100%-2rem)] sm:w-auto transition-[border-radius] duration-300`}>
      <div className="flex items-center justify-between w-full gap-6 sm:gap-8">
        <div className="flex items-center gap-2 flex-shrink-0">
          <Image src="/logo.png" alt="DARSAK AI" width={24} height={24} className="rounded-md" style={{ width: 24, height: 24 }} />
          <span className="font-bold text-sm text-white whitespace-nowrap">DARSAK AI</span>
        </div>
        <nav className="hidden sm:flex items-center gap-6">
          {navLinks.map((l) => (
            <AnimatedNavLink key={l.href} href={l.href}>{l.label}</AnimatedNavLink>
          ))}
        </nav>
        <button className="sm:hidden w-8 h-8 text-gray-300" onClick={() => setIsOpen(!isOpen)}>
          {isOpen
            ? <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
            : <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6h16M4 12h16M4 18h16" /></svg>
          }
        </button>
      </div>
      <div className={`absolute top-full left-0 right-0 sm:hidden flex flex-col items-center w-full transition-all duration-300 overflow-hidden ${isOpen ? 'max-h-[500px] opacity-100 pt-4' : 'max-h-0 opacity-0 pointer-events-none'}`}>
        <nav className="flex flex-col items-center gap-4 w-full">
          {navLinks.map((l) => (
            <a key={l.href} href={l.href} className="text-gray-300 hover:text-white transition-colors w-full text-center" onClick={() => setIsOpen(false)}>{l.label}</a>
          ))}
        </nav>
      </div>
    </header>
  )
}

export default function LandingPage() {
  return (
    <div className="flex w-full flex-col min-h-screen bg-black relative overflow-x-hidden">
      {/* Background shader */}
      <div className="fixed inset-0 z-0">
        <CanvasRevealEffect
          containerClassName="bg-black"
          dotSize={5}
        />
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,_rgba(0,0,0,1)_0%,_transparent_100%)]" />
        <div className="absolute top-0 left-0 right-0 h-1/3 bg-gradient-to-b from-black to-transparent" />
      </div>

      <Navbar />

      {/* Hero */}
      <section className="relative z-10 min-h-screen flex flex-col items-center justify-center px-4 text-center">
        <motion.div initial={{ opacity: 0, y: 40 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }} className="max-w-3xl">
          <h1 className="text-5xl md:text-7xl lg:text-8xl font-black leading-[0.95] mb-6 tracking-tight text-white">
            DARSAK <span className="text-transparent bg-clip-text bg-gradient-to-r from-gray-200 via-white to-gray-400">AI</span>
          </h1>
          <p className="text-lg md:text-xl text-white/50 font-light mb-10 max-w-xl mx-auto leading-relaxed">
            منصة تعليمية ذكية بالذكاء الاصطناعي — إدارة الطلاب، الامتحانات، الكورسات، والتحليلات في مكان واحد
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <a href="#download" className="px-8 py-3 bg-white text-black font-semibold rounded-full hover:bg-gray-200 transition-colors text-sm">حمّل التطبيق</a>
            <a href="#features" className="px-8 py-3 border border-white/20 text-white/70 rounded-full hover:border-white/40 hover:text-white transition-colors text-sm">اكتشف المزيد</a>
          </div>
        </motion.div>
      </section>

      {/* Stats */}
      <section className="relative z-10 py-20 px-4">
        <div className="max-w-4xl mx-auto grid grid-cols-3 gap-6">
          {[{ n: '+50', l: 'مدرس نشط' }, { n: '+500', l: 'طالب مسجل' }, { n: '98%', l: 'رضا المستخدمين' }].map((s, i) => (
            <motion.div key={s.l} className="text-center p-6 rounded-2xl border border-white/[0.06]" initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.1 }}>
              <div className="text-3xl md:text-5xl font-black mb-1 text-white" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{s.n}</div>
              <div className="text-sm text-white/40">{s.l}</div>
            </motion.div>
          ))}
        </div>
      </section>

      {/* Features */}
      <section id="features" className="relative z-10 py-24 px-4">
        <div className="max-w-6xl mx-auto">
          <motion.div className="text-center mb-16" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}>
            <h2 className="text-3xl md:text-5xl font-black mb-3 text-white">كل اللي تحتاجه في مكان واحد</h2>
            <p className="text-white/40 text-lg">أدوات ذكية تساعدك تدير سنترك بكفاءة</p>
          </motion.div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            {features.map((f, i) => (
              <motion.div key={f.title} className="p-6 rounded-2xl border border-white/[0.06] hover:border-white/[0.12] hover:bg-white/[0.02] transition-all duration-500" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.08 }}>
                <div className="text-[10px] font-bold text-white/20 mb-3 tracking-widest" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{f.num}</div>
                <h3 className="text-lg font-bold text-white mb-2">{f.title}</h3>
                <p className="text-sm text-white/40 leading-relaxed">{f.desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <div className="max-w-5xl mx-auto h-px bg-gradient-to-r from-transparent via-white/10 to-transparent mx-4" />

      {/* Pricing */}
      <section id="pricing" className="relative z-10 py-24 px-4">
        <div className="max-w-5xl mx-auto">
          <motion.div className="text-center mb-16" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}>
            <h2 className="text-3xl md:text-5xl font-black mb-3 text-white">باقات تناسب كل سنتر</h2>
            <p className="text-white/40 text-lg">جميع الأسعار بالجنيه المصري</p>
          </motion.div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {pricingPlans.map((plan, i) => (
              <motion.div key={plan.name} className={`relative border rounded-2xl p-7 flex flex-col transition-all duration-500 hover:bg-white/[0.02] ${plan.popular ? 'border-white/30' : 'border-white/[0.06]'}`} initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.1 }}>
                {plan.popular && <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 bg-white text-black text-xs font-bold rounded-full">الأكثر طلباً</div>}
                <div className="text-sm font-semibold text-white/50 mb-1">{plan.name}</div>
                <div className="flex items-baseline gap-1 mb-6">
                  <span className="text-4xl font-black text-white" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{plan.price}</span>
                  <span className="text-sm text-white/40">ج.م/شهر</span>
                </div>
                <ul className="space-y-3 flex-1">
                  {plan.features.map((f, j) => (
                    <li key={j} className="flex items-center gap-2 text-sm text-white/60">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="shrink-0 text-white/30"><polyline points="20 6 9 17 4 12" /></svg>
                      {f}
                    </li>
                  ))}
                </ul>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <div className="max-w-5xl mx-auto h-px bg-gradient-to-r from-transparent via-white/10 to-transparent mx-4" />

      {/* Download */}
      <section id="download" className="relative z-10 py-24 px-4">
        <div className="max-w-4xl mx-auto">
          <motion.div className="text-center mb-16" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}>
            <h2 className="text-3xl md:text-5xl font-black mb-3 text-white">حمّل التطبيق</h2>
            <p className="text-white/40 text-lg">تطبيقان منفصلان — واحد للمعلمين وواحد للطلاب</p>
          </motion.div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {[
              { t: 'تطبيق المعلمين', d: 'إدارة الطلاب، الامتحانات، الكورسات، الحضور، الفواتير، والتقارير الذكية', v: 'v2.5.0', s: '38 MB', f: 'teacher-v2.5.0.apk', n: 'DarsakAI-Teacher-v2.5.0.apk' },
              { t: 'تطبيق الطلاب', d: 'متابعة الدرجات، الحضور، الاختبارات، الكورسات، ومدرس AI ذكي', v: 'v1.7.3', s: '36 MB', f: 'student-v1.7.3.apk', n: 'DarsakAI-Student-v1.7.3.apk' },
            ].map((app, i) => (
              <motion.div key={app.t} className="p-7 rounded-2xl border border-white/[0.06] hover:border-white/[0.12] transition-all duration-500 flex flex-col items-center text-center" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.1 }}>
                <div className="w-16 h-16 rounded-2xl overflow-hidden mb-5 bg-white/10 flex items-center justify-center">
                  <Image src="/logo.png" alt={app.t} width={64} height={64} className="w-full h-full object-cover" />
                </div>
                <h3 className="text-lg font-bold text-white mb-2">{app.t}</h3>
                <p className="text-sm text-white/40 mb-5 leading-relaxed">{app.d}</p>
                <div className="flex items-center gap-2 text-xs text-white/30 mb-5">
                  <span className="px-2 py-0.5 bg-white/5 rounded">Android</span>
                  <span>•</span><span>{app.v}</span><span>•</span><span>{app.s}</span>
                </div>
                <a href={`https://darsak-backend.fly.dev/api/downloads/${app.f}`} download={app.n} className="w-full py-3 px-6 bg-white text-black font-bold rounded-full hover:bg-gray-200 transition-colors text-sm cursor-pointer">
                  تحميل APK
                </a>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <div className="max-w-5xl mx-auto h-px bg-gradient-to-r from-transparent via-white/10 to-transparent mx-4" />

      {/* Contact */}
      <section id="contact" className="relative z-10 py-24 px-4">
        <div className="max-w-3xl mx-auto text-center">
          <motion.div initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}>
            <h2 className="text-3xl md:text-5xl font-black mb-3 text-white">عندك استفسار؟</h2>
            <p className="text-white/40 text-lg mb-10">تواصل معنا وسنرد عليك في أقرب وقت</p>
          </motion.div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
            {[
              { icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>, l: 'الموقع', v: 'مصر — القاهرة' },
              { icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>, l: 'البريد', v: 'support@darsakai.com' },
              { icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>, l: 'واتساب', v: '01055359719' },
            ].map((item, i) => (
              <motion.div key={item.l} className="p-6 rounded-2xl border border-white/[0.06] hover:border-white/[0.12] transition-all duration-500" initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.1 }}>
                <div className="w-10 h-10 rounded-xl bg-white/[0.04] text-white/40 flex items-center justify-center mx-auto mb-3">{item.icon}</div>
                <div className="text-xs text-white/30 mb-1">{item.l}</div>
                <div className="text-sm text-white font-semibold" dir="ltr">{item.v}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative z-10 border-t border-white/[0.06] py-10 px-4">
        <div className="max-w-5xl mx-auto">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">
            <div>
              <div className="flex items-center gap-2 mb-3">
                <Image src="/logo.png" alt="" width={18} height={18} className="rounded" style={{ width: 18, height: 18 }} />
                <span className="text-sm font-bold text-white" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</span>
              </div>
              <p className="text-xs text-white/30 leading-relaxed">منصة تعليمية ذكية بالذكاء الاصطناعي — لإدارة المدارس والسنترات بكفاءة.</p>
            </div>
            <div>
              <h4 className="text-xs font-bold text-white/50 mb-3 tracking-wider">روابط سريعة</h4>
              <div className="flex flex-col gap-2">
                <a href="#features" className="text-xs text-white/30 hover:text-white/60 transition-colors">المميزات</a>
                <a href="#pricing" className="text-xs text-white/30 hover:text-white/60 transition-colors">الباقات</a>
                <a href="#download" className="text-xs text-white/30 hover:text-white/60 transition-colors">تحميل التطبيق</a>
                <a href="#contact" className="text-xs text-white/30 hover:text-white/60 transition-colors">تواصل معنا</a>
              </div>
            </div>
            <div>
              <h4 className="text-xs font-bold text-white/50 mb-3 tracking-wider">سياسات وشروط</h4>
              <div className="flex flex-col gap-2">
                <Link href="/privacy" className="text-xs text-white/30 hover:text-white/60 transition-colors">سياسة الخصوصية</Link>
                <Link href="/terms" className="text-xs text-white/30 hover:text-white/60 transition-colors">الشروط والأحكام</Link>
                <Link href="/refund" className="text-xs text-white/30 hover:text-white/60 transition-colors">سياسة استرجاع الأموال</Link>
              </div>
            </div>
          </div>
          <div className="border-t border-white/[0.06] pt-6 flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="text-xs text-white/30">© 2026 DarsakAI — جميع الحقوق محفوظة</div>
            <div className="flex items-center gap-4">
              <a href="https://wa.me/201055359719" target="_blank" rel="noopener noreferrer" className="text-white/20 hover:text-white/50 transition-colors">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
              </a>
              <a href="mailto:support@darsakai.com" className="text-white/20 hover:text-white/50 transition-colors">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
