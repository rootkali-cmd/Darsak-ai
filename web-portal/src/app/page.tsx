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
    desc: 'إضافة الطلاب بالباركود، متابعة بياناتهم، تواصل مع أولياء الأمور — كل طالب وله ملف كامل متكامل.',
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
    price: '199',
    period: '/شهر',
    desc: 'للسناتر الصغيرة',
    features: ['إدارة حتى 100 طالب', 'تسجيل حضور وغياب', 'تخزين فيديو 2GB', '5 تحليلات AI شهرياً'],
    cta: 'ابدأ مجاناً',
    trial: true,
    popular: false,
  },
  {
    name: 'Pro',
    nameAr: 'المحترف',
    price: '499',
    period: '/شهر',
    desc: 'للسناتر المتوسطة',
    features: ['إدارة حتى 400 طالب', 'كل ميزات الأساسي', 'تخزين فيديو 6GB', '30 تحليل AI شهرياً', 'فواتير إلكترونية', 'دعم فني مباشر'],
    cta: 'اشتراك',
    popular: true,
  },
  {
    name: 'Premium',
    nameAr: 'المتكاملة',
    price: '999',
    period: '/شهر',
    desc: 'للسناتر الكبيرة',
    features: ['عدد غير محدود من الطلاب', 'كل ميزات Pro', 'تخزين فيديو غير محدود', 'AI غير محدود', 'تخصيص كامل', 'دعم 24/7'],
    cta: 'اشتراك',
    popular: false,
  },
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
    <div className="min-h-screen flex flex-col bg-[#0a0a1a]">
      {/* ─── Header ─── */}
      <motion.header
        className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-4 md:px-10 py-4"
        style={{ background: 'rgba(10,10,26,0.9)', backdropFilter: 'blur(16px)', borderBottom: '1px solid rgba(255,255,255,0.06)' }}
        initial={{ y: -20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-lg flex items-center justify-center">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" className="text-white">
              <path d="M12 2L2 7l10 5 10-5-10-5z" fill="currentColor" opacity="0.3" />
              <path d="M2 17l10 5 10-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M2 12l10 5 10-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <span className="font-bold text-base text-white tracking-tight" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</span>
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
          className="fixed top-16 left-0 right-0 z-40 flex flex-col items-center gap-4 p-6 bg-[#0a0a1a] border-b border-white/10"
        >
          {navLinks}
        </motion.div>
      )}

      <main className="flex-1">
        {/* ─── Hero ─── */}
        <section className="relative min-h-screen flex items-center overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-b from-indigo-600/10 via-transparent to-transparent" />
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-gradient-to-b from-indigo-600/15 via-purple-600/5 to-transparent rounded-full blur-3xl" />
          <div className="absolute bottom-0 left-0 w-[600px] h-[600px] bg-gradient-to-tr from-blue-600/5 to-transparent rounded-full blur-3xl" />
          <div
            className="absolute inset-0 opacity-[0.02]"
            style={{ backgroundImage: 'linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)', backgroundSize: '64px 64px' }}
          />

          <div className="relative z-10 w-full max-w-6xl mx-auto px-4 md:px-6 pt-24 md:pt-28 pb-16">
            <div className="text-center max-w-4xl mx-auto">
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6 }}
                className="mb-6"
              >
                <span className="inline-flex items-center gap-2 px-4 py-2 text-xs font-semibold text-indigo-300 bg-indigo-500/10 border border-indigo-500/20 rounded-full">
                  <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 animate-pulse" />
                  منصة إدارة السناتر التعليمية
                </span>
              </motion.div>

              <motion.h1
                className="text-4xl md:text-6xl lg:text-7xl font-extrabold text-white leading-[1.1] mb-6"
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.1, duration: 0.7 }}
              >
                أدر سنترك التعليمي
                <br />
                <span className="text-transparent bg-clip-text bg-gradient-to-l from-indigo-400 via-purple-400 to-pink-400">بذكاء وسهولة</span>
              </motion.h1>

              <motion.p
                className="text-lg md:text-xl text-slate-400 leading-relaxed max-w-2xl mx-auto mb-10"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2, duration: 0.6 }}
              >
                وفر 80% من وقتك الإداري. نظام متكامل لإدارة الطلاب، الحضور، الدرجات، الفواتير، والفيديوهات التعليمية — بالذكاء الاصطناعي
              </motion.p>

              <motion.div
                className="flex flex-col sm:flex-row gap-4 justify-center mb-12"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3, duration: 0.6 }}
              >
                {loggedIn ? (
                  <motion.button
                    className="inline-flex items-center justify-center gap-2 px-8 py-4 text-lg font-bold text-white bg-gradient-to-l from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 rounded-xl shadow-lg shadow-indigo-600/25 transition-all"
                    onClick={() => router.push('/dashboard')}
                    whileHover={{ scale: 1.03 }}
                    whileTap={{ scale: 0.97 }}
                  >لوحة التحكم ←</motion.button>
                ) : (
                  <>
                    <motion.button
                      className="inline-flex items-center justify-center gap-2 px-8 py-4 text-lg font-bold text-white bg-gradient-to-l from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 rounded-xl shadow-lg shadow-indigo-600/25 transition-all"
                      onClick={() => router.push('/register')}
                      whileHover={{ scale: 1.03 }}
                      whileTap={{ scale: 0.97 }}
                    >ابدأ مجاناً ←</motion.button>
                    <motion.button
                      className="inline-flex items-center justify-center gap-2 px-8 py-4 text-lg font-semibold text-slate-300 bg-white/5 border border-white/10 hover:bg-white/10 hover:border-white/20 rounded-xl transition-all"
                      onClick={() => router.push('/download')}
                      whileHover={{ scale: 1.03 }}
                      whileTap={{ scale: 0.97 }}
                    >
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                      تحميل التطبيقات
                    </motion.button>
                  </>
                )}
              </motion.div>

              {/* Stats */}
              <motion.div
                className="flex flex-wrap items-center justify-center gap-8 md:gap-12"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.4, duration: 0.6 }}
              >
                {[
                  { num: '+2000', label: 'معلم' },
                  { num: '+50K', label: 'طالب' },
                  { num: '+50', label: 'سنتر تعليمي' },
                  { num: '99%', label: 'رضا' },
                ].map((stat) => (
                  <div key={stat.label} className="text-center">
                    <div className="text-2xl md:text-3xl font-bold text-white" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{stat.num}</div>
                    <div className="text-xs text-slate-500">{stat.label}</div>
                  </div>
                ))}
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

        {/* ─── Features ─── */}
        <section className="py-20 md:py-28 px-6">
          <div className="max-w-6xl mx-auto">
            <motion.div className="text-center mb-16" {...fadeUp()}>
              <span className="inline-block px-3 py-1 text-xs font-semibold text-indigo-400 bg-indigo-500/10 rounded-full mb-4">الميزات</span>
              <h2 className="text-3xl md:text-4xl font-extrabold text-white mb-3">كل اللي تحتاجه لإدارة سنترك</h2>
              <p className="text-slate-400 max-w-lg mx-auto">من الطالب الأول لباقي الشهر — كل حاجة في مكان واحد</p>
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
                  className="group bg-white/[0.03] border border-white/[0.08] rounded-xl p-6 hover:border-indigo-500/30 hover:bg-white/[0.06] transition-all duration-300"
                  variants={{ initial: { opacity: 0, y: 20 }, whileInView: { opacity: 1, y: 0 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <div className="w-11 h-11 rounded-xl bg-indigo-500/10 text-indigo-400 flex items-center justify-center mb-4 group-hover:bg-indigo-500/20 transition-colors duration-300">
                    {f.icon}
                  </div>
                  <div className="text-xs font-bold text-indigo-500 mb-1">{f.num}</div>
                  <h3 className="text-lg font-bold text-white mb-2">{f.title}</h3>
                  <p className="text-sm text-slate-400 leading-relaxed">{f.desc}</p>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── How It Works ─── */}
        <section className="py-20 md:py-28 px-6 bg-white/[0.02]">
          <div className="max-w-5xl mx-auto">
            <motion.div className="text-center mb-16" {...fadeUp()}>
              <span className="inline-block px-3 py-1 text-xs font-semibold text-indigo-400 bg-indigo-500/10 rounded-full mb-4">كيف يعمل</span>
              <h2 className="text-3xl md:text-4xl font-extrabold text-white mb-3">ابدأ في ٤ خطوات بس</h2>
              <p className="text-slate-400">من التسجيل لأول يوم دراسة — النظام جاهز في ١٠ دقائق</p>
            </motion.div>

            <motion.div
              className="relative grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6"
              variants={{ ...stagger, whileInView: { transition: { staggerChildren: 0.1 } } }}
              initial="initial"
              whileInView="whileInView"
              viewport={{ once: true }}
            >
              {/* Connecting line — desktop only */}
              <div className="hidden lg:block absolute top-9 left-[12%] right-[12%] h-0.5 bg-gradient-to-r from-indigo-500/20 via-indigo-500/40 to-indigo-500/20" />

              {howItWorks.map((item) => (
                <motion.div
                  key={item.step}
                  className="relative text-center"
                  variants={{ initial: { opacity: 0, y: 20, scale: 0.95 }, whileInView: { opacity: 1, y: 0, scale: 1 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <motion.div
                    className="relative z-10 w-12 h-12 flex items-center justify-center mx-auto mb-5 rounded-full text-base font-extrabold text-white bg-gradient-to-br from-indigo-500 to-purple-600 shadow-lg shadow-indigo-500/25"
                    whileHover={{ scale: 1.1 }}
                  >{item.step}</motion.div>
                  <h3 className="font-bold text-white mb-2">{item.title}</h3>
                  <p className="text-sm text-slate-400 leading-relaxed">{item.desc}</p>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── Pricing ─── */}
        <section className="py-20 md:py-28 px-6">
          <div className="max-w-5xl mx-auto">
            <motion.div className="text-center mb-16" {...fadeUp()}>
              <span className="inline-block px-3 py-1 text-xs font-semibold text-indigo-400 bg-indigo-500/10 rounded-full mb-4">الباقات</span>
              <h2 className="text-3xl md:text-4xl font-extrabold text-white mb-3">باقات تناسب كل سنتر</h2>
              <p className="text-slate-400 max-w-lg mx-auto">اختر الباقة المناسبة — الباقة الأساسية تبدأ بـ ٣٠ يوم مجاناً</p>
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
                  className={`relative bg-white/[0.04] border rounded-2xl p-7 flex flex-col transition-all duration-300 hover:bg-white/[0.06] ${
                    plan.popular ? 'border-indigo-500/50 shadow-lg shadow-indigo-500/10' : 'border-white/[0.08]'
                  }`}
                  variants={{ initial: { opacity: 0, y: 20 }, whileInView: { opacity: 1, y: 0 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  {plan.popular && (
                    <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 bg-gradient-to-l from-indigo-600 to-purple-600 text-white text-xs font-bold rounded-full">
                      الأكثر طلباً
                    </div>
                  )}

                  <div className="mb-6">
                    <div className="text-sm font-semibold text-indigo-400 mb-1">{plan.nameAr}</div>
                    <div className="text-xs text-slate-500">{plan.desc}</div>
                  </div>

                  <div className="mb-6">
                    <div className="flex items-baseline gap-1">
                      <span className="text-4xl font-extrabold text-white">{plan.price}</span>
                      <span className="text-sm text-slate-400">ج.م</span>
                      <span className="text-sm text-slate-400">{plan.period}</span>
                    </div>
                  </div>

                  <ul className="space-y-3 mb-8 flex-1">
                    {plan.features.map((f, i) => (
                      <li key={i} className="flex items-center gap-2.5 text-sm text-slate-300">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#818CF8" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="shrink-0"><polyline points="20 6 9 17 4 12" /></svg>
                        {f}
                      </li>
                    ))}
                  </ul>

                  <motion.button
                    className={`w-full py-3 text-sm font-bold rounded-xl transition-all ${
                      plan.popular
                        ? 'bg-gradient-to-l from-indigo-600 to-purple-600 text-white hover:from-indigo-500 hover:to-purple-500 shadow-lg shadow-indigo-500/25'
                        : 'bg-white/[0.06] text-indigo-400 border border-white/[0.1] hover:bg-white/[0.1] hover:border-indigo-500/30'
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
        <section className="py-24 md:py-32 px-6 relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-b from-indigo-600/10 to-transparent" />
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-gradient-to-b from-indigo-600/10 to-transparent rounded-full blur-3xl" />

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
                className="flex-1 px-4 py-3.5 rounded-xl bg-white/[0.06] border border-white/[0.1] text-white placeholder:text-slate-500 focus:outline-none focus:border-indigo-500 focus:bg-white/[0.08] transition-colors text-sm"
              />
              <motion.button
                className="px-6 py-3.5 bg-gradient-to-l from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white font-bold rounded-xl shadow-lg shadow-indigo-600/25 transition-colors text-sm whitespace-nowrap"
                onClick={() => router.push('/register')}
                whileHover={{ scale: 1.03 }}
                whileTap={{ scale: 0.97 }}
              >ابدأ الآن ←</motion.button>
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
        className="border-t border-white/[0.06] py-12 px-6"
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className="max-w-5xl mx-auto">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-8 mb-10">
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.1 }}>
              <div className="flex items-center gap-2 mb-3">
                <div className="w-7 h-7 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-lg flex items-center justify-center">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" className="text-white">
                    <path d="M12 2L2 7l10 5 10-5-10-5z" fill="currentColor" opacity="0.3" />
                    <path d="M2 17l10 5 10-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </div>
                <span className="font-bold text-sm text-white tracking-tight" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</span>
              </div>
              <p className="text-xs text-slate-500 leading-relaxed">أول منصة مصرية متكاملة لإدارة السناتر التعليمية بالذكاء الاصطناعي.</p>
            </motion.div>
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.2 }}>
              <h4 className="font-bold text-sm mb-3 text-white">الروابط</h4>
              <div className="flex flex-col gap-2 text-sm text-slate-500">
                <a href="/about" className="hover:text-indigo-400 transition-colors">من نحن</a>
                <a href="/pricing" className="hover:text-indigo-400 transition-colors">الباقات</a>
                <a href="/download" className="hover:text-indigo-400 transition-colors">التطبيقات</a>
                <a href="/faq" className="hover:text-indigo-400 transition-colors">الأسئلة الشائعة</a>
              </div>
            </motion.div>
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.3 }}>
              <h4 className="font-bold text-sm mb-3 text-white">القانوني</h4>
              <div className="flex flex-col gap-2 text-sm text-slate-500">
                <a href="/privacy" className="hover:text-indigo-400 transition-colors">سياسة الخصوصية</a>
                <a href="/terms" className="hover:text-indigo-400 transition-colors">شروط الخدمة</a>
                <a href="/contact" className="hover:text-indigo-400 transition-colors">اتصل بنا</a>
              </div>
            </motion.div>
          </div>
          <motion.div
            className="border-t border-white/[0.06] text-center pt-6 text-xs text-slate-500"
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
