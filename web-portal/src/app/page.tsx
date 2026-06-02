'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { auth } from '@/lib/auth'

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 24 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true },
  transition: { delay, duration: 0.5, ease: [0.16, 1, 0.3, 1] },
})

const stagger = {
  initial: {},
  whileInView: { transition: { staggerChildren: 0.06 } },
  viewport: { once: true },
}

const features = [
  {
    num: '01',
    title: 'إدارة الطلاب',
    desc: 'إضافة الطلاب بالباركود، متابعة بيناتهم، تواصل مع أولياء الأمور — كل طالب وله ملف كامل متكامل.',
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
        <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
      </svg>
    ),
  },
  {
    num: '02',
    title: 'الحضور والغياب',
    desc: 'سجل حضور الطلاب بالباركود أو يدوياً. تقارير يومية وشهرية بنسبة حضور كل طالب.',
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M9 11l3 3L22 4" /><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
      </svg>
    ),
  },
  {
    num: '03',
    title: 'الدرجات والامتحانات',
    desc: 'إنشاء امتحانات، تصحيح آلي، تحليل النتائج، وإشعار أولياء الأمور بالنتائج.',
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
        <polyline points="14 2 14 8 20 8" /><line x1="16" y1="13" x2="8" y2="13" />
        <line x1="16" y1="17" x2="8" y2="17" /><polyline points="10 9 9 9 8 9" />
      </svg>
    ),
  },
  {
    num: '04',
    title: 'المجموعات والفصول',
    desc: 'قسم الطلاب حسب المرحلة والمادة والوقت. كل مجموعة لها جدول منفصل.',
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="7" />
        <rect x="14" y="14" width="7" height="7" /><rect x="3" y="14" width="7" height="7" />
      </svg>
    ),
  },
  {
    num: '05',
    title: 'الفواتير والمصاريف',
    desc: 'تحصيل المصاريف إلكترونياً، فواتير مدفوعة وغير مدفوعة، تقارير مالية.',
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="2" y="5" width="20" height="14" rx="2" /><line x1="2" y1="10" x2="22" y2="10" />
      </svg>
    ),
  },
  {
    num: '06',
    title: 'تحليلات AI',
    desc: 'تحليل أداء كل طالب بالذكاء الاصطناعي، اكتشف نقاط القوة والضعف.',
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
      </svg>
    ),
  },
]

const howItWorks = [
  { step: '1', title: 'سجل حسابك', desc: 'أنشئ حساب مجاني في دقيقة. لا تحتاج بطاقة ائتمان.' },
  { step: '2', title: 'أضف طلابك', desc: 'استورد الطلاب أو أضفهم واحداً واحداً. النظام يولد كود QR لكل طالب.' },
  { step: '3', title: 'نظم مجموعاتك', desc: 'قسم الطلاب حسب المستوى والمادة والوقت. كل مجموعة بجدول مستقل.' },
  { step: '4', title: 'تابع وأنجز', desc: 'سجل الحضور، اعمل امتحانات، حصّل المصاريف — كل حاجة من لوحة تحكم واحدة.' },
]

const pricingPlans = [
  {
    name: 'Basic',
    nameAr: 'الأساسي',
    price: '200',
    period: '/شهر',
    desc: 'للسناتر الصغيرة',
    features: ['إدارة حتى 50 طالب', 'تسجيل حضور وغياب', 'تقارير أساسية', 'دعم عبر البريد الإلكتروني'],
    cta: 'ابدأ مجاناً',
    popular: false,
  },
  {
    name: 'Pro',
    nameAr: 'المحترف',
    price: '600',
    period: '/شهر',
    desc: 'للسناتر المتوسطة',
    features: ['إدارة حتى 200 طالب', 'كل ميزات الأساسي', 'امتحانات وتصحيح آلي', 'فواتير إلكترونية', 'تحليلات AI متقدمة', 'دعم فني مباشر'],
    cta: 'ابدأ مجاناً',
    popular: true,
  },
  {
    name: 'Enterprise',
    nameAr: 'المؤسسي',
    price: '1100',
    period: '/شهر',
    desc: 'لسلاسل السناتر الكبيرة',
    features: ['عدد غير محدود من الطلاب', 'كل ميزات Pro', 'تخصيص كامل للمنصة', 'API مفتوح للتكامل', 'مدير حساب مخصص', 'تدريب للفريق'],
    cta: 'تحدث معنا',
    popular: false,
  },
]

const trustLogos = [
  { initials: 'م.ن', color: '#EF4444', name: 'مدرسة النيل' },
  { initials: 'م.ع', color: '#3B82F6', name: 'مدرسة العصر' },
  { initials: 'م.ا', color: '#10B981', name: 'مدرسة الأمل' },
  { initials: 'م.ف', color: '#8B5CF6', name: 'مدرسة الفاروق' },
  { initials: 'م.ر', color: '#F59E0B', name: 'مدرسة الرشاد' },
]

export default function LandingPage() {
  const router = useRouter()
  const [loggedIn, setLoggedIn] = useState(false)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  useEffect(() => {
    setLoggedIn(auth.isAuthenticated())
  }, [])

  const navLinks = (
    <>
      <a href="/about" className="text-sm text-slate-300 hover:text-white transition-colors" onClick={() => setMobileMenuOpen(false)}>من نحن</a>
      <a href="/pricing" className="text-sm text-slate-300 hover:text-white transition-colors" onClick={() => setMobileMenuOpen(false)}>الباقات</a>
      <a href="/download" className="text-sm text-slate-300 hover:text-white transition-colors" onClick={() => setMobileMenuOpen(false)}>التطبيقات</a>
      <a href="/faq" className="text-sm text-slate-300 hover:text-white transition-colors" onClick={() => setMobileMenuOpen(false)}>الأسئلة الشائعة</a>
      {loggedIn ? (
        <motion.button
          className="inline-flex items-center justify-center gap-1.5 px-4 py-2 text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-500 rounded-lg transition-colors w-full sm:w-auto"
          onClick={() => router.push('/dashboard')}
          whileHover={{ scale: 1.04 }}
          whileTap={{ scale: 0.96 }}
        >لوحة التحكم</motion.button>
      ) : (
        <>
          <motion.button
            className="inline-flex items-center justify-center gap-1.5 px-4 py-2 text-sm font-semibold text-slate-300 hover:text-white rounded-lg border border-slate-600 hover:border-slate-400 transition-colors w-full sm:w-auto"
            onClick={() => router.push('/login')}
            whileHover={{ scale: 1.04 }}
            whileTap={{ scale: 0.96 }}
          >دخول</motion.button>
          <motion.button
            className="inline-flex items-center justify-center gap-1.5 px-4 py-2 text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-500 rounded-lg transition-colors w-full sm:w-auto"
            onClick={() => router.push('/register')}
            whileHover={{ scale: 1.04 }}
            whileTap={{ scale: 0.96 }}
          >ابدأ مجاناً</motion.button>
        </>
      )}
    </>
  )

  return (
    <div className="min-h-screen flex flex-col bg-white">
      {/* ─── Header ─── */}
      <motion.header
        className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-4 md:px-10 py-4"
        style={{ background: 'rgba(15,23,42,0.85)', backdropFilter: 'blur(16px)', borderBottom: '1px solid rgba(255,255,255,0.08)' }}
        initial={{ y: -20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className="flex items-center gap-2">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" className="text-indigo-500">
            <path d="M12 2L2 7l10 5 10-5-10-5z" fill="currentColor" opacity="0.3" />
            <path d="M2 17l10 5 10-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M2 12l10 5 10-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <span className="font-bold text-base text-white tracking-tight">DARSAK AI</span>
        </div>
        <nav className="hidden md:flex items-center gap-6">
          {navLinks}
        </nav>
        <button
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          className="md:hidden p-2 text-slate-300 hover:text-white"
          aria-label="القائمة"
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            {mobileMenuOpen ? <><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></> : <><line x1="3" y1="6" x2="21" y2="6" /><line x1="3" y1="12" x2="21" y2="12" /><line x1="3" y1="18" x2="21" y2="18" /></>}
          </svg>
        </button>
      </motion.header>

      {mobileMenuOpen && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="fixed top-16 left-0 right-0 z-40 flex flex-col items-center gap-4 p-6 bg-[#0F172A] border-b border-white/10"
        >
          {navLinks}
        </motion.div>
      )}

      <main className="flex-1">
        {/* ─── Hero ─── */}
        <section className="relative min-h-screen flex items-center overflow-hidden bg-gradient-to-b from-[#0F172A] via-[#0F172A] to-[#1E293B]">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,rgba(99,102,241,0.12),transparent_50%)]" />
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_bottom_left,rgba(79,70,229,0.08),transparent_50%)]" />
          <div
            className="absolute inset-0 opacity-[0.03]"
            style={{ backgroundImage: 'linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)', backgroundSize: '64px 64px' }}
          />

          <div className="relative z-10 w-full max-w-6xl mx-auto px-4 md:px-6 pt-24 md:pt-28 pb-16">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-10 lg:gap-14 items-center">

              {/* Left: Text */}
              <motion.div
                className="order-2 lg:order-1"
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
              >
                <motion.span
                  className="inline-flex items-center gap-2 px-3.5 py-1.5 text-xs font-semibold text-indigo-300 bg-indigo-500/10 border border-indigo-500/20 rounded-full mb-6"
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1, duration: 0.4 }}
                >
                  <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 animate-pulse" />
                  منصة إدارة السناتر التعليمية
                </motion.span>

                <motion.h1
                  className="text-4xl md:text-5xl lg:text-6xl font-extrabold text-white leading-[1.1] mb-5"
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.15, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                >
                  أدر سنترك التعليمي
                  <br />
                  <span className="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-purple-400">من مكان واحد</span>
                </motion.h1>

                <motion.p
                  className="text-base md:text-lg text-slate-400 leading-relaxed max-w-lg mb-8"
                  initial={{ opacity: 0, y: 15 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.25, duration: 0.5 }}
                >
                  وفر 80% من وقتك الإداري. نظام متكامل لإدارة الطلاب، الحضور، الدرجات، الفواتير، والفيديوهات التعليمية — بالذكاء الاصطناعي
                </motion.p>

                <motion.div
                  className="flex flex-col sm:flex-row gap-3 mb-10"
                  initial={{ opacity: 0, y: 15 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.35, duration: 0.5 }}
                >
                  {loggedIn ? (
                    <motion.button
                      className="inline-flex items-center justify-center gap-2 px-7 py-3.5 text-base font-bold text-white bg-indigo-600 hover:bg-indigo-500 rounded-xl shadow-lg shadow-indigo-600/25 transition-all"
                      onClick={() => router.push('/dashboard')}
                      whileHover={{ scale: 1.03 }}
                      whileTap={{ scale: 0.97 }}
                    >لوحة التحكم →</motion.button>
                  ) : (
                    <>
                      <motion.button
                        className="inline-flex items-center justify-center gap-2 px-7 py-3.5 text-base font-bold text-white bg-indigo-600 hover:bg-indigo-500 rounded-xl shadow-lg shadow-indigo-600/25 transition-all"
                        onClick={() => router.push('/register')}
                        whileHover={{ scale: 1.03 }}
                        whileTap={{ scale: 0.97 }}
                      >ابدأ مجاناً →</motion.button>
                      <motion.button
                        className="inline-flex items-center justify-center gap-2 px-7 py-3.5 text-base font-semibold text-slate-300 bg-white/5 border border-white/10 hover:bg-white/10 hover:border-white/20 rounded-xl transition-all"
                        onClick={() => router.push('/login')}
                        whileHover={{ scale: 1.03 }}
                        whileTap={{ scale: 0.97 }}
                      >
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polygon points="5 3 19 12 5 21 5 3" /></svg>
                        شاهد العرض التوضيحي
                      </motion.button>
                    </>
                  )}
                </motion.div>

                {/* Social proof */}
                <motion.div
                  className="flex items-center gap-4"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.5, duration: 0.5 }}
                >
                  <div className="flex -space-x-2 rtl:space-x-reverse">
                    {['#6366F1', '#8B5CF6', '#A78BFA', '#C4B5FD'].map((color, i) => (
                      <div key={i} className="w-8 h-8 rounded-full border-2 border-[#0F172A] flex items-center justify-center text-[10px] font-bold text-white" style={{ background: color }}>
                        {String.fromCharCode(1575 + i)}
                      </div>
                    ))}
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-slate-200">موثوق من +50 سنتر تعليمي</p>
                    <div className="flex items-center gap-1 mt-0.5">
                      {[1, 2, 3, 4, 5].map((s) => (
                        <svg key={s} width="12" height="12" viewBox="0 0 24 24" fill="#F59E0B"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" /></svg>
                      ))}
                      <span className="text-xs text-slate-400 mr-1">4.9 من 5</span>
                    </div>
                  </div>
                </motion.div>
              </motion.div>

              {/* Right: Dashboard mockup with floating cards */}
              <motion.div
                className="order-1 lg:order-2 relative"
                initial={{ opacity: 0, scale: 0.92, y: 20 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                transition={{ duration: 0.8, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
              >
                <div className="relative">
                  <div className="absolute -inset-1 bg-gradient-to-br from-indigo-500/20 to-purple-500/20 rounded-2xl blur-2xl" />
                  <img
                    src="/hero.webp"
                    alt="DARSAK AI platform"
                    className="w-full h-auto relative rounded-xl shadow-2xl shadow-black/40 border border-white/10"
                  />

                  {/* Floating stat card 1 */}
                  <motion.div
                    className="absolute -top-5 -left-5 bg-white/[0.08] backdrop-blur-xl border border-white/10 rounded-xl px-4 py-3 shadow-lg hidden md:block"
                    initial={{ opacity: 0, x: -20, y: 20 }}
                    animate={{ opacity: 1, x: 0, y: 0 }}
                    transition={{ delay: 0.7, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                  >
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 rounded-lg bg-indigo-500/20 flex items-center justify-center">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#818CF8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 20V10" /><path d="M18 20V4" /><path d="M6 20v-4" /></svg>
                      </div>
                      <div>
                        <div className="text-sm font-bold text-white">توفير 80%</div>
                        <div className="text-[10px] text-slate-400">من الوقت الإداري</div>
                      </div>
                    </div>
                  </motion.div>

                  {/* Floating stat card 2 */}
                  <motion.div
                    className="absolute -bottom-4 -right-4 bg-white/[0.08] backdrop-blur-xl border border-white/10 rounded-xl px-4 py-3 shadow-lg hidden md:block"
                    initial={{ opacity: 0, x: 20, y: -20 }}
                    animate={{ opacity: 1, x: 0, y: 0 }}
                    transition={{ delay: 0.85, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                  >
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 rounded-lg bg-emerald-500/20 flex items-center justify-center">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#34D399" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" /><polyline points="22 4 12 14.01 9 11.01" /></svg>
                      </div>
                      <div>
                        <div className="text-sm font-bold text-white">AI-Powered</div>
                        <div className="text-[10px] text-slate-400">تحليلات ذكية</div>
                      </div>
                    </div>
                  </motion.div>

                  {/* Floating stat card 3 */}
                  <motion.div
                    className="absolute top-1/3 -right-6 bg-white/[0.08] backdrop-blur-xl border border-white/10 rounded-xl px-3 py-2.5 shadow-lg hidden lg:block"
                    initial={{ opacity: 0, y: -20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 1.0, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                  >
                    <div className="text-xs text-slate-400 mb-0.5">السناتر النشطة</div>
                    <div className="text-lg font-bold text-white">+50</div>
                  </motion.div>
                </div>
              </motion.div>

            </div>
          </div>

          {/* Scroll indicator */}
          <motion.div
            className="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1.2, duration: 0.5 }}
          >
            <span className="text-[10px] text-slate-500 tracking-widest">استكشف المزيد</span>
            <motion.div
              animate={{ y: [0, 6, 0] }}
              transition={{ repeat: Infinity, duration: 1.8, ease: 'easeInOut' }}
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#64748B" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="12" y1="5" x2="12" y2="19" /><polyline points="19 12 12 19 5 12" /></svg>
            </motion.div>
          </motion.div>
        </section>

        {/* ─── Trust Section ─── */}
        <section className="py-16 md:py-20 px-6 border-b border-slate-100">
          <div className="max-w-5xl mx-auto">
            <motion.p
              className="text-center text-sm font-medium text-slate-400 mb-8 tracking-wide"
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5 }}
            >معتمد من سناتر تعليمية رائدة</motion.p>

            <motion.div
              className="flex flex-wrap items-center justify-center gap-6 md:gap-10 mb-14"
              variants={stagger}
              initial="initial"
              whileInView="whileInView"
              viewport={{ once: true }}
            >
              {trustLogos.map((logo) => (
                <motion.div
                  key={logo.name}
                  className="flex items-center gap-2.5"
                  variants={{ initial: { opacity: 0, scale: 0.9 }, whileInView: { opacity: 1, scale: 1 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <div
                    className="w-10 h-10 rounded-xl flex items-center justify-center text-sm font-bold text-white shadow-sm"
                    style={{ backgroundColor: logo.color }}
                  >{logo.initials}</div>
                  <span className="text-xs text-slate-500 font-medium hidden sm:block">{logo.name}</span>
                </motion.div>
              ))}
            </motion.div>

            <motion.div
              className="grid grid-cols-2 md:grid-cols-4 gap-6"
              variants={stagger}
              initial="initial"
              whileInView="whileInView"
              viewport={{ once: true }}
            >
              {[
                { value: '+5,000', label: 'طالب مسجل' },
                { value: '+12,000', label: 'حصه مسجلة' },
                { value: '80%', label: 'توفير في الوقت' },
                { value: '+50', label: 'سنتر تعليمي' },
              ].map((stat) => (
                <motion.div
                  key={stat.label}
                  className="text-center"
                  variants={{ initial: { opacity: 0, y: 15 }, whileInView: { opacity: 1, y: 0 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <div className="text-3xl md:text-4xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-indigo-600 to-purple-600 mb-1">{stat.value}</div>
                  <div className="text-sm text-slate-500">{stat.label}</div>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── Features ─── */}
        <section className="py-20 md:py-28 px-6 bg-slate-50/50">
          <div className="max-w-6xl mx-auto">
            <motion.div className="text-center mb-16" {...fadeUp()}>
              <span className="inline-block px-3 py-1 text-xs font-semibold text-indigo-600 bg-indigo-50 rounded-full mb-4">الميزات</span>
              <h2 className="text-3xl md:text-4xl font-extrabold text-slate-900 mb-3">كل اللي تحتاجه لإدارة سنترك</h2>
              <p className="text-slate-500 max-w-lg mx-auto">من الطالب الأول لباقي الشهر — كل حاجة في مكان واحد</p>
            </motion.div>

            <motion.div
              className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5"
              variants={stagger}
              initial="initial"
              whileInView="whileInView"
              viewport={{ once: true }}
            >
              {features.map((f) => (
                <motion.div
                  key={f.title}
                  className="group bg-white border border-slate-200 rounded-xl p-6 hover:shadow-lg hover:shadow-slate-200/50 hover:border-indigo-200 transition-all duration-300"
                  variants={{ initial: { opacity: 0, y: 20 }, whileInView: { opacity: 1, y: 0 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <div className="w-11 h-11 rounded-xl bg-indigo-50 text-indigo-600 flex items-center justify-center mb-4 group-hover:bg-indigo-600 group-hover:text-white transition-colors duration-300">
                    {f.icon}
                  </div>
                  <div className="text-xs font-bold text-indigo-500 mb-1">{f.num}</div>
                  <h3 className="text-lg font-bold text-slate-900 mb-2">{f.title}</h3>
                  <p className="text-sm text-slate-500 leading-relaxed">{f.desc}</p>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── How It Works ─── */}
        <section className="py-20 md:py-28 px-6 bg-white">
          <div className="max-w-5xl mx-auto">
            <motion.div className="text-center mb-16" {...fadeUp()}>
              <span className="inline-block px-3 py-1 text-xs font-semibold text-indigo-600 bg-indigo-50 rounded-full mb-4">كيف يعمل</span>
              <h2 className="text-3xl md:text-4xl font-extrabold text-slate-900 mb-3">ابدأ في ٤ خطوات بس</h2>
              <p className="text-slate-500">من التسجيل لأول يوم دراسة — النظام جاهز في ١٠ دقائق</p>
            </motion.div>

            <motion.div
              className="relative grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6"
              variants={{ ...stagger, whileInView: { transition: { staggerChildren: 0.1 } } }}
              initial="initial"
              whileInView="whileInView"
              viewport={{ once: true }}
            >
              {/* Connecting line — desktop only */}
              <div className="hidden lg:block absolute top-9 left-[12%] right-[12%] h-0.5 bg-gradient-to-r from-indigo-200 via-indigo-400 to-indigo-200" />

              {howItWorks.map((item) => (
                <motion.div
                  key={item.step}
                  className="relative text-center"
                  variants={{ initial: { opacity: 0, y: 20, scale: 0.95 }, whileInView: { opacity: 1, y: 0, scale: 1 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <motion.div
                    className="relative z-10 w-12 h-12 flex items-center justify-center mx-auto mb-5 rounded-full text-base font-extrabold text-white bg-gradient-to-br from-indigo-500 to-indigo-600 shadow-lg shadow-indigo-200"
                    whileHover={{ scale: 1.1 }}
                  >{item.step}</motion.div>
                  <h3 className="font-bold text-slate-900 mb-2">{item.title}</h3>
                  <p className="text-sm text-slate-500 leading-relaxed">{item.desc}</p>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── Pricing ─── */}
        <section className="py-20 md:py-28 px-6 bg-slate-50/50">
          <div className="max-w-5xl mx-auto">
            <motion.div className="text-center mb-16" {...fadeUp()}>
              <span className="inline-block px-3 py-1 text-xs font-semibold text-indigo-600 bg-indigo-50 rounded-full mb-4">الباقات</span>
              <h2 className="text-3xl md:text-4xl font-extrabold text-slate-900 mb-3">باقات تناسب كل سنتر</h2>
              <p className="text-slate-500 max-w-lg mx-auto">اختر الباقة المناسبة — كل الباقات تبدأ بـ ٣٠ يوم مجاناً بدون بطاقة ائتمان</p>
            </motion.div>

            <motion.div
              className="grid grid-cols-1 md:grid-cols-3 gap-6"
              variants={stagger}
              initial="initial"
              whileInView="whileInView"
              viewport={{ once: true }}
            >
              {pricingPlans.map((plan) => (
                <motion.div
                  key={plan.name}
                  className={`relative bg-white border rounded-2xl p-7 flex flex-col transition-all duration-300 hover:shadow-xl hover:shadow-slate-200/50 ${
                    plan.popular ? 'border-indigo-400 shadow-lg shadow-indigo-100 scale-[1.02]' : 'border-slate-200'
                  }`}
                  variants={{ initial: { opacity: 0, y: 20 }, whileInView: { opacity: 1, y: 0 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  {plan.popular && (
                    <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 bg-indigo-600 text-white text-xs font-bold rounded-full">
                      الأكثر طلباً
                    </div>
                  )}

                  <div className="mb-6">
                    <div className="text-sm font-semibold text-indigo-600 mb-1">{plan.nameAr}</div>
                    <div className="text-xs text-slate-400">{plan.desc}</div>
                  </div>

                  <div className="mb-6">
                    <div className="flex items-baseline gap-1">
                      <span className="text-4xl font-extrabold text-slate-900">{plan.price}</span>
                      <span className="text-sm text-slate-400">ج.م</span>
                      <span className="text-sm text-slate-400">{plan.period}</span>
                    </div>
                  </div>

                  <ul className="space-y-3 mb-8 flex-1">
                    {plan.features.map((f, i) => (
                      <li key={i} className="flex items-center gap-2.5 text-sm text-slate-600">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#6366F1" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="shrink-0"><polyline points="20 6 9 17 4 12" /></svg>
                        {f}
                      </li>
                    ))}
                  </ul>

                  <motion.button
                    className={`w-full py-3 text-sm font-bold rounded-xl transition-all ${
                      plan.popular
                        ? 'bg-indigo-600 text-white hover:bg-indigo-500 shadow-lg shadow-indigo-200'
                        : 'bg-white text-indigo-600 border-2 border-indigo-200 hover:bg-indigo-50 hover:border-indigo-400'
                    }`}
                    onClick={() => router.push('/register')}
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                  >{plan.cta}</motion.button>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── Final CTA ─── */}
        <section className="py-24 md:py-32 px-6 relative overflow-hidden" style={{ background: '#0F172A' }}>
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(99,102,241,0.15),transparent_70%)]" />
          <div
            className="absolute inset-0 opacity-[0.03]"
            style={{ backgroundImage: 'linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)', backgroundSize: '48px 48px' }}
          />

          <motion.div
            className="relative z-10 max-w-xl mx-auto text-center"
            initial={{ opacity: 0, y: 24, scale: 0.97 }}
            whileInView={{ opacity: 1, y: 0, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
          >
            <h2 className="text-3xl md:text-4xl font-extrabold text-white mb-4">جاهز تبدأ؟</h2>
            <p className="text-slate-400 mb-8 leading-relaxed">أول ٣٠ يوم مجاناً — بدون بطاقة ائتمان — إلغاء في أي وقت</p>

            <div className="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
              <input
                type="email"
                placeholder="أدخل بريدك الإلكتروني"
                className="flex-1 px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder:text-slate-500 focus:outline-none focus:border-indigo-500 focus:bg-white/[0.07] transition-colors text-sm"
              />
              <motion.button
                className="px-6 py-3.5 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl shadow-lg shadow-indigo-600/25 transition-colors text-sm whitespace-nowrap"
                onClick={() => router.push('/register')}
                whileHover={{ scale: 1.03 }}
                whileTap={{ scale: 0.97 }}
              >ابدأ الآن →</motion.button>
            </div>

            <div className="flex flex-wrap items-center justify-center gap-x-4 gap-y-1 mt-6 text-xs text-slate-500">
              <span>✓ لا تحتاج بطاقة بنكية</span>
              <span className="w-1 h-1 rounded-full bg-slate-600" />
              <span>✓ دعم فني مجاني</span>
              <span className="w-1 h-1 rounded-full bg-slate-600" />
              <span>✓ إلغاء في أي وقت</span>
            </div>
          </motion.div>
        </section>
      </main>

      {/* ─── Footer ─── */}
      <motion.footer
        className="border-t py-12 px-6 bg-slate-50"
        style={{ borderColor: '#e2e8f0' }}
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className="max-w-5xl mx-auto">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-8 mb-10">
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.1 }}>
              <div className="flex items-center gap-2 mb-3">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" className="text-indigo-500">
                  <path d="M12 2L2 7l10 5 10-5-10-5z" fill="currentColor" opacity="0.3" />
                  <path d="M2 17l10 5 10-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M2 12l10 5 10-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                <span className="font-bold text-sm text-slate-900 tracking-tight">DARSAK AI</span>
              </div>
              <p className="text-xs text-slate-500 leading-relaxed">أول منصة مصرية متكاملة لإدارة السناتر التعليمية بالذكاء الاصطناعي.</p>
            </motion.div>
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.2 }}>
              <h4 className="font-bold text-sm mb-3 text-slate-900">الروابط</h4>
              <div className="flex flex-col gap-2 text-sm text-slate-500">
                <a href="/about" className="hover:text-indigo-600 transition-colors">من نحن</a>
                <a href="/pricing" className="hover:text-indigo-600 transition-colors">الباقات</a>
                <a href="/download" className="hover:text-indigo-600 transition-colors">التطبيقات</a>
                <a href="/faq" className="hover:text-indigo-600 transition-colors">الأسئلة الشائعة</a>
              </div>
            </motion.div>
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.3 }}>
              <h4 className="font-bold text-sm mb-3 text-slate-900">القانوني</h4>
              <div className="flex flex-col gap-2 text-sm text-slate-500">
                <a href="/privacy" className="hover:text-indigo-600 transition-colors">سياسة الخصوصية</a>
                <a href="/terms" className="hover:text-indigo-600 transition-colors">شروط الخدمة</a>
                <a href="/contact" className="hover:text-indigo-600 transition-colors">اتصل بنا</a>
              </div>
            </motion.div>
          </div>
          <motion.div
            className="border-t text-center pt-6 text-xs text-slate-400"
            style={{ borderColor: '#e2e8f0' }}
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.4 }}
          >© 2026 DARSAK AI. جميع الحقوق محفوظة.</motion.div>
        </div>
      </motion.footer>
    </div>
  )
}
