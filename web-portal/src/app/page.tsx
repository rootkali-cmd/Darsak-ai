'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Image from 'next/image'
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
  { num: '01', title: 'إدارة الطلاب', desc: 'إضافة الطلاب بالباركود، متابعة بيناتهم، تواصل مع أولياء الأمور — كل طالب وله ملف كامل متكامل.' },
  { num: '02', title: 'الحضور والغياب', desc: 'سجل حضور الطلاب بالباركود أو يدوياً. تقارير يومية وشهرية بنسبة حضور كل طالب.' },
  { num: '03', title: 'الدرجات والامتحانات', desc: 'إنشاء امتحانات، تصحيح آلي، تحليل النتائج، وإشعار أولياء الأمور بالنتائج.' },
  { num: '04', title: 'المجموعات والفصول', desc: 'قسم الطلاب حسب المرحلة والمادة والوقت. كل مجموعة لها جدول منفصل.' },
  { num: '05', title: 'الفواتير والمصاريف', desc: 'تحصيل المصاريف إلكترونياً، فواتير مدفوعة وغير مدفوعة، تقارير مالية.' },
  { num: '06', title: 'تحليلات AI', desc: 'تحليل أداء كل طالب بالذكاء الاصطناعي، اكتشف نقاط القوة والضعف.' },
]

const howItWorks = [
  { step: '1', title: 'سجل حسابك', desc: 'أنشئ حساب مجاني في دقيقة. لا تحتاج بطاقة ائتمان.' },
  { step: '2', title: 'أضف طلابك', desc: 'استورد الطلاب أو أضفهم واحداً واحداً. النظام يولد كود QR لكل طالب.' },
  { step: '3', title: 'نظم مجموعاتك', desc: 'قسم الطلاب حسب المستوى والمادة والوقت. كل مجموعة بجدول مستقل.' },
  { step: '4', title: 'تابع وأنجز', desc: 'سجل الحضور، اعمل امتحانات، حصّل المصاريف — كل حاجة من لوحة تحكم واحدة.' },
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
      <a href="/about" className="text-sm text-[var(--text-muted)] hover:text-[var(--text)] transition-colors" onClick={() => setMobileMenuOpen(false)}>من نحن</a>
      <a href="/pricing" className="text-sm text-[var(--text-muted)] hover:text-[var(--text)] transition-colors" onClick={() => setMobileMenuOpen(false)}>الباقات</a>
      <a href="/download" className="text-sm text-[var(--text-muted)] hover:text-[var(--text)] transition-colors" onClick={() => setMobileMenuOpen(false)}>التطبيقات</a>
      <a href="/faq" className="text-sm text-[var(--text-muted)] hover:text-[var(--text)] transition-colors" onClick={() => setMobileMenuOpen(false)}>الأسئلة الشائعة</a>
      {loggedIn ? (
        <motion.button className="btn btn-primary btn-sm w-full sm:w-auto" onClick={() => router.push('/dashboard')} whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>لوحة التحكم</motion.button>
      ) : (
        <>
          <motion.button className="btn btn-ghost btn-sm w-full sm:w-auto" onClick={() => router.push('/login')} whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>دخول</motion.button>
          <motion.button className="btn btn-primary btn-sm w-full sm:w-auto" onClick={() => router.push('/register')} whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>ابدأ مجاناً</motion.button>
        </>
      )}
    </>
  )

  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'var(--bg)' }}>
      <motion.header
        className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-4 md:px-10 py-4"
        style={{ background: 'var(--header-bg)', backdropFilter: 'blur(12px)', borderBottom: '1px solid var(--card-border)' }}
        initial={{ y: -20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className="flex items-center gap-2">
          <span className="text-lg text-[var(--accent)]">◈</span>
          <span className="font-bold tracking-widest text-sm" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</span>
        </div>
        <nav className="hidden md:flex items-center gap-4 md:gap-6">
          {navLinks}
        </nav>
        <button
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          className="md:hidden p-2 text-[var(--text-muted)] hover:text-[var(--text)]"
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
          exit={{ opacity: 0, y: -10 }}
          className="fixed top-16 left-0 right-0 z-40 flex flex-col items-center gap-4 p-6"
          style={{ background: 'var(--bg-secondary)', borderBottom: '1px solid var(--card-border)' }}
        >
          {navLinks}
        </motion.div>
      )}

      <main className="flex-1">
        {/* ─── Hero ─── */}
        <section className="relative min-h-[70vh] md:min-h-[85vh] flex items-center overflow-hidden">
          <motion.div
            className="absolute inset-0"
            style={{ backgroundImage: 'linear-gradient(rgba(0,0,0,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(0,0,0,0.02) 1px, transparent 1px)', backgroundSize: '60px 60px' }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6 }}
          />
          <div className="absolute top-20 left-10 w-80 h-80 rounded-full opacity-[0.04]" style={{ background: 'var(--accent)' }} />
          <div className="absolute bottom-10 right-20 w-96 h-96 rounded-full opacity-[0.03]" style={{ background: 'var(--accent-2)' }} />

            <div className="relative z-10 w-full max-w-6xl mx-auto px-4 md:px-6 pt-24 md:pt-28 pb-16">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-center">

              {/* Text side */}
              <motion.div className="order-2 lg:order-2" initial={{ opacity: 0, x: -30 }} animate={{ opacity: 1, x: 0 }} transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}>
                <motion.span
                  className="inline-block px-3 py-1 text-xs tracking-widest mb-5 border"
                  style={{ borderColor: 'var(--accent)', color: 'var(--accent)', fontFamily: "'JetBrains Mono', monospace" }}
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.15, duration: 0.4 }}
                >AI-POWERED</motion.span>
                <h1 className="mb-4">
                  <motion.div
                    className="text-4xl md:text-5xl lg:text-6xl font-black text-[var(--text)] leading-tight"
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.2, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                  >منصة إدارة السناتر</motion.div>
                  <motion.div
                    className="text-2xl md:text-3xl lg:text-4xl font-bold tracking-[0.2em] mt-2"
                    style={{ fontFamily: "'JetBrains Mono', monospace", background: 'linear-gradient(135deg, #dc2626, #ef4444)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.3, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                  >DARSAK AI</motion.div>
                </h1>
                <motion.p
                  className="text-base md:text-lg text-[var(--text-secondary)] leading-relaxed max-w-lg mb-8"
                  initial={{ opacity: 0, y: 15 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.4, duration: 0.5 }}
                >
                  أول منصة متكاملة في مصر لإدارة السناتر التعليمية — طلاب، حضور، درجات، مصاريف، وتحليلات بالذكاء الاصطناعي.
                </motion.p>
                <motion.div
                  className="flex gap-3 flex-wrap mb-12"
                  initial={{ opacity: 0, y: 15 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.5, duration: 0.5 }}
                >
                  {loggedIn ? (
                    <motion.button className="btn btn-primary btn-lg" onClick={() => router.push('/dashboard')} whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.96 }}>← لوحة التحكم</motion.button>
                  ) : (
                    <>
                      <motion.button className="btn btn-primary btn-lg" onClick={() => router.push('/register')} whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.96 }}>← ابدأ مجاناً</motion.button>
                      <motion.button className="btn btn-outline btn-lg" onClick={() => router.push('/login')} whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.96 }}>تسجيل الدخول</motion.button>
                    </>
                  )}
                </motion.div>

                {/* Trust bar */}
                <motion.div
                  className="grid grid-cols-2 sm:grid-cols-4 gap-4"
                  initial="initial"
                  animate="animate"
                  variants={{ initial: {}, animate: { transition: { staggerChildren: 0.07, delayChildren: 0.6 } } }}
                >
                  {[
                    { num: '١٥٠٠٠+', label: 'مستخدم نشط' },
                    { num: '٢٠٠٠٠٠+', label: 'طالب مسجل' },
                    { num: '٩٨%', label: 'رضا العملاء' },
                    { num: '٤.٨/٥', label: 'تقييم المنصة' },
                  ].map((s) => (
                    <motion.div key={s.label} variants={{ initial: { opacity: 0, y: 12 }, animate: { opacity: 1, y: 0 } }}>
                      <div className="text-lg font-black text-[var(--accent)]">{s.num}</div>
                      <div className="text-xs text-[var(--text-muted)] mt-0.5">{s.label}</div>
                    </motion.div>
                  ))}
                </motion.div>
              </motion.div>

              {/* Image side */}
              <motion.div
                className="order-1 lg:order-1 relative"
                initial={{ opacity: 0, x: 40, scale: 0.95 }}
                animate={{ opacity: 1, x: 0, scale: 1 }}
                transition={{ duration: 0.8, delay: 0.25, ease: [0.16, 1, 0.3, 1] }}
              >
                <div className="relative">
                  <motion.div
                    className="absolute -inset-4 bg-gradient-to-br from-[var(--accent)]/10 to-transparent opacity-60"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 0.6 }}
                    transition={{ delay: 0.5, duration: 0.6 }}
                  />
                  <Image
                    src="/hero.png"
                    alt="DARSAK AI platform"
                    width={768}
                    height={512}
                    className="w-full h-auto relative"
                    style={{ objectFit: 'cover' }}
                    priority
                  />
                </div>
              </motion.div>

            </div>
          </div>
        </section>

        {/* ─── Features ─── */}
        <section className="py-20 px-6" style={{ background: 'var(--bg-secondary)' }}>
          <div className="max-w-5xl mx-auto">
            <motion.div className="text-center mb-14" {...fadeUp()}>
              <span className="text-xs tracking-[0.2em] text-[var(--accent)]" style={{ fontFamily: "'JetBrains Mono', monospace" }}>FEATURES</span>
              <h2 className="text-3xl font-bold text-[var(--text)] mt-3">كل اللي تحتاجه لإدارة سنترك</h2>
              <p className="text-[var(--text-muted)] mt-2 max-w-lg mx-auto">من الطالب الأول لباقي الشهر — كل حاجة في مكان واحد</p>
            </motion.div>
            <motion.div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" variants={stagger} initial="initial" whileInView="whileInView" viewport={{ once: true }}>
              {features.map((f) => (
                <motion.div
                  key={f.title}
                  className="card card-hover p-6"
                  variants={{ initial: { opacity: 0, y: 20 }, whileInView: { opacity: 1, y: 0 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <span className="text-xs font-bold tracking-wider text-[var(--accent)]" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{f.num}</span>
                  <h3 className="text-lg font-bold text-[var(--text)] mt-3 mb-2">{f.title}</h3>
                  <p className="text-sm text-[var(--text-secondary)] leading-relaxed">{f.desc}</p>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── How It Works ─── */}
        <section className="py-20 px-6">
          <div className="max-w-4xl mx-auto">
            <motion.div className="text-center mb-14" {...fadeUp()}>
              <span className="text-xs tracking-[0.2em] text-[var(--accent)]" style={{ fontFamily: "'JetBrains Mono', monospace" }}>HOW IT WORKS</span>
              <h2 className="text-3xl font-bold text-[var(--text)] mt-3">ابدأ في ٤ خطوات بس</h2>
              <p className="text-[var(--text-muted)] mt-2">من التسجيل لأول يوم دراسة — النظام جاهز في ١٠ دقائق</p>
            </motion.div>
            <motion.div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5" variants={{ ...stagger, whileInView: { transition: { staggerChildren: 0.1 } } }} initial="initial" whileInView="whileInView" viewport={{ once: true }}>
              {howItWorks.map((item) => (
                <motion.div
                  key={item.step}
                  className="text-center"
                  variants={{ initial: { opacity: 0, y: 20, scale: 0.95 }, whileInView: { opacity: 1, y: 0, scale: 1 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <motion.div
                    className="w-12 h-12 flex items-center justify-center mx-auto mb-4 text-lg font-black text-white"
                    style={{ background: 'var(--accent)' }}
                    whileHover={{ scale: 1.1, rotate: -5 }}
                  >{item.step}</motion.div>
                  <h3 className="font-bold mb-2">{item.title}</h3>
                  <p className="text-sm text-[var(--text-secondary)] leading-relaxed">{item.desc}</p>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── Stats ─── */}
        <section className="py-16 px-6" style={{ background: 'var(--bg-secondary)' }}>
          <div className="max-w-4xl mx-auto">
            <motion.div className="grid grid-cols-2 md:grid-cols-4 gap-8" variants={{ ...stagger, whileInView: { transition: { staggerChildren: 0.08 } } }} initial="initial" whileInView="whileInView" viewport={{ once: true }}>
              {[
                { num: '١٥,٠٠٠+', label: 'مستخدم نشط' },
                { num: '٢٠٠,٠٠٠+', label: 'طالب مسجل' },
                { num: '٩٨%', label: 'رضا العملاء' },
                { num: '٤.٨/٥', label: 'تقييم المنصة' },
              ].map((s) => (
                <motion.div
                  key={s.label}
                  className="text-center card p-6"
                  variants={{ initial: { opacity: 0, y: 15, scale: 0.9 }, whileInView: { opacity: 1, y: 0, scale: 1 } }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                >
                  <div className="text-2xl font-black text-[var(--accent)]">{s.num}</div>
                  <div className="text-xs text-[var(--text-muted)] mt-1">{s.label}</div>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ─── CTA ─── */}
        <section className="py-24 px-6 text-center" style={{ background: 'var(--bg)' }}>
          <motion.div className="max-w-xl mx-auto" initial={{ opacity: 0, y: 20, scale: 0.98 }} whileInView={{ opacity: 1, y: 0, scale: 1 }} viewport={{ once: true }} transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}>
            <h2 className="text-3xl font-bold text-[var(--text)] mb-3">جهز سنترك للموسم الجديد</h2>
            <p className="text-[var(--text-secondary)] mb-3">أول ٣٠ يوم مجاناً — بدون بطاقة ائتمان — إلغاء في أي وقت</p>
            <div className="flex flex-wrap items-center justify-center gap-x-3 gap-y-1 text-sm text-[var(--text-muted)] mb-8">
              <motion.span initial={{ opacity: 0, x: -10 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true }} transition={{ delay: 0.2 }}>✓ لا تحتاج بطاقة بنكية</motion.span>
              <motion.span className="w-1 h-1 rounded-full" style={{ background: 'var(--text-muted)' }} initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} transition={{ delay: 0.3 }} />
              <motion.span initial={{ opacity: 0, x: -10 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true }} transition={{ delay: 0.4 }}>✓ دعم فني مجاني</motion.span>
              <motion.span className="w-1 h-1 rounded-full" style={{ background: 'var(--text-muted)' }} initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} transition={{ delay: 0.5 }} />
              <motion.span initial={{ opacity: 0, x: -10 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true }} transition={{ delay: 0.6 }}>✓ إلغاء في أي وقت</motion.span>
            </div>
            <motion.button
              className="btn btn-primary btn-lg"
              onClick={() => router.push('/register')}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
            >← ابدأ مجاناً — أول ٣٠ يوم</motion.button>
          </motion.div>
        </section>
      </main>

      {/* ─── Footer ─── */}
      <motion.footer
        className="border-t py-8 px-6"
        style={{ borderColor: 'var(--card-border)' }}
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      >
        <div className="max-w-5xl mx-auto">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-8 mb-8">
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.1 }}>
              <div className="flex items-center gap-2 mb-3">
                <span className="text-lg text-[var(--accent)]">◈</span>
                <span className="font-bold tracking-widest text-sm" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</span>
              </div>
              <p className="text-xs text-[var(--text-muted)] leading-relaxed">أول منصة مصرية متكاملة لإدارة السناتر التعليمية بالذكاء الاصطناعي.</p>
            </motion.div>
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.2 }}>
              <h4 className="font-bold text-sm mb-3">الروابط</h4>
              <div className="flex flex-col gap-2 text-sm text-[var(--text-muted)]">
                <a href="/about" className="hover:text-[var(--text)] transition-colors">من نحن</a>
                <a href="/pricing" className="hover:text-[var(--text)] transition-colors">الباقات</a>
                <a href="/download" className="hover:text-[var(--text)] transition-colors">التطبيقات</a>
                <a href="/faq" className="hover:text-[var(--text)] transition-colors">الأسئلة الشائعة</a>
              </div>
            </motion.div>
            <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: 0.3 }}>
              <h4 className="font-bold text-sm mb-3">القانوني</h4>
              <div className="flex flex-col gap-2 text-sm text-[var(--text-muted)]">
                <a href="/privacy" className="hover:text-[var(--text)] transition-colors">سياسة الخصوصية</a>
                <a href="/terms" className="hover:text-[var(--text)] transition-colors">شروط الخدمة</a>
                <a href="/contact" className="hover:text-[var(--text)] transition-colors">اتصل بنا</a>
              </div>
            </motion.div>
          </div>
          <motion.div
            className="border-t text-center pt-6 text-xs text-[var(--text-muted)]"
            style={{ borderColor: 'var(--card-border)' }}
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
