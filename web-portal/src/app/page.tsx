'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { auth } from '@/lib/auth'

const features = [
  { icon: '◈', title: 'إدارة الطلاب', desc: 'إضافة وتنظيم ومتابعة الطلاب مع باركود وبينات كاملة' },
  { icon: '◈', title: 'تحليل الأداء', desc: 'تحليل درجات الطلاب مع رسوم بيانية وتقارير ذكية' },
  { icon: '◈', title: 'الحضور', desc: 'تسجيل الحضور بالباركود وإنشاء تقارير يومية' },
  { icon: '◈', title: 'الاختبارات', desc: 'إنشاء اختبارات إلكترونية وتصحيح آلي وتحليل النتائج' },
  { icon: '◈', title: 'المجموعات', desc: 'تقسيم الطلاب لمجموعات حسب المرحلة والمادة' },
  { icon: '◈', title: 'PDF ذكي', desc: 'استخراج أسئلة من ملفات PDF باستخدام AI' },
]

export default function LandingPage() {
  const router = useRouter()
  const [loggedIn, setLoggedIn] = useState(false)

  useEffect(() => {
    setLoggedIn(auth.isAuthenticated())
  }, [])

  return (
    <div className="landing">
      <header className="landing-header">
        <div className="landing-logo">
          <span className="landing-logo-icon">◈</span>
          <span className="landing-logo-text">DARSAK AI</span>
        </div>
        <nav className="landing-nav">
          <a href="/pricing">الباقات</a>
          <a href="/download">التطبيقات</a>
          {loggedIn ? (
            <button className="landing-btn" onClick={() => router.push('/dashboard')}>
              لوحة التحكم
            </button>
          ) : (
            <>
              <button className="landing-btn-outline" onClick={() => router.push('/login')}>
                دخول
              </button>
              <button className="landing-btn" onClick={() => router.push('/register')}>
                ابدأ مجاناً
              </button>
            </>
          )}
        </nav>
      </header>

      <main>
        <section className="landing-hero">
          <div className="landing-hero-grid" />
          <motion.div
            className="landing-hero-content"
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
          >
            <span className="landing-badge">AI-POWERED</span>
            <h1>
              <span className="landing-title-ar">منصة إدارة التعليم</span>
              <span className="landing-title-en">DARSAK AI</span>
            </h1>
            <p className="landing-subtitle">
              نظام متكامل لإدارة الفصول الدراسية، متابعة الطلاب، وتحليل الأداء باستخدام الذكاء الاصطناعي
            </p>
            <div className="landing-cta">
              {loggedIn ? (
                <button className="landing-btn landing-btn-lg" onClick={() => router.push('/dashboard')}>
                  → لوحة التحكم
                </button>
              ) : (
                <>
                  <button className="landing-btn landing-btn-lg" onClick={() => router.push('/register')}>
                    → ابدأ مجاناً
                  </button>
                  <button className="landing-btn-outline landing-btn-lg" onClick={() => router.push('/login')}>
                    تسجيل الدخول
                  </button>
                </>
              )}
            </div>
          </motion.div>
        </section>

        <section className="landing-features">
          <motion.div
            className="landing-section-header"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <span className="landing-section-tag">FEATURES</span>
            <h2>كل ما تحتاجه في منصة واحدة</h2>
          </motion.div>
          <div className="landing-features-grid">
            {features.map((f, i) => (
              <motion.div
                key={f.title}
                className="landing-feature-card"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.08, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
              >
                <span className="landing-feature-icon">{f.icon}</span>
                <h3>{f.title}</h3>
                <p>{f.desc}</p>
              </motion.div>
            ))}
          </div>
        </section>

        <section className="landing-cta-section">
          <motion.div
            className="landing-cta-content"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
          >
            <h2>استعد لتطوير أداء طلابك</h2>
            <p>انضم إلى المدرسين الذين يستخدمون DARSAK AI لتحسين تجربة التعليم</p>
            <button className="landing-btn landing-btn-lg" onClick={() => router.push('/register')}>
              ← ابدأ مجاناً
            </button>
          </motion.div>
        </section>
      </main>

      <footer className="landing-footer">
        <div className="landing-footer-inner">
          <span>© 2026 DARSAK AI</span>
          <div className="landing-footer-links">
            <a href="/pricing">الباقات</a>
            <a href="/download">التطبيقات</a>
            <a href="/login">دخول</a>
          </div>
        </div>
      </footer>

      <style dangerouslySetInnerHTML={{__html: `
.landing {
  min-height: 100vh;
  background: var(--bg, #030303);
  color: #e0e0e0;
  font-family: 'Tajawal', system-ui, sans-serif;
  display: flex;
  flex-direction: column;
}

/* ── Header ── */
.landing-header {
  position: fixed;
  top: 0; left: 0; right: 0;
  z-index: 50;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 2rem;
  background: rgba(3,3,3,0.8);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid rgba(255,255,255,0.06);
}
.landing-logo {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.landing-logo-icon {
  font-size: 1.3rem;
  color: #ff003c;
}
.landing-logo-text {
  font-family: 'JetBrains Mono', monospace;
  font-size: 1rem;
  font-weight: 700;
  letter-spacing: 0.15em;
  color: #fff;
}
.landing-nav {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}
.landing-nav a {
  color: rgba(255,255,255,0.6);
  text-decoration: none;
  font-size: 0.85rem;
  transition: color 0.2s;
}
.landing-nav a:hover { color: #fff; }

/* ── Buttons ── */
.landing-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4em;
  padding: 0.6rem 1.2rem;
  background: #ff003c;
  color: #fff;
  font-weight: 700;
  font-size: 0.8rem;
  letter-spacing: 0.05em;
  border: 1px solid #ff003c;
  cursor: pointer;
  transition: background 0.2s;
  font-family: 'Tajawal', system-ui, sans-serif;
}
.landing-btn:hover { background: #cc0030; }
.landing-btn-outline {
  display: inline-flex;
  align-items: center;
  gap: 0.4em;
  padding: 0.6rem 1.2rem;
  border: 1px solid rgba(255,255,255,0.2);
  color: rgba(255,255,255,0.8);
  font-weight: 600;
  font-size: 0.8rem;
  background: transparent;
  cursor: pointer;
  transition: all 0.2s;
  font-family: 'Tajawal', system-ui, sans-serif;
}
.landing-btn-outline:hover {
  border-color: #ff003c;
  color: #ff003c;
}
.landing-btn-lg {
  padding: 0.9rem 2rem;
  font-size: 0.95rem;
}

/* ── Hero ── */
.landing-hero {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  padding: 6rem 2rem 4rem;
  overflow: hidden;
}
.landing-hero-grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px);
  background-size: 60px 60px;
  z-index: 0;
}
.landing-hero-content {
  position: relative;
  z-index: 1;
  text-align: center;
  max-width: 720px;
}
.landing-badge {
  display: inline-block;
  padding: 0.3rem 0.8rem;
  border: 1px solid rgba(255,0,60,0.3);
  color: #ff003c;
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.7rem;
  letter-spacing: 0.15em;
  margin-bottom: 1.5rem;
}
.landing-hero h1 {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-bottom: 1.5rem;
}
.landing-title-ar {
  font-size: clamp(2.5rem, 6vw, 4.5rem);
  font-weight: 800;
  color: #fff;
  line-height: 1.1;
}
.landing-title-en {
  font-family: 'JetBrains Mono', monospace;
  font-size: clamp(1.8rem, 4vw, 3rem);
  font-weight: 700;
  background: linear-gradient(135deg, #ff003c, #ff6b6b);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  letter-spacing: 0.2em;
}
.landing-subtitle {
  font-size: clamp(1rem, 2vw, 1.2rem);
  color: rgba(255,255,255,0.5);
  line-height: 1.8;
  max-width: 560px;
  margin: 0 auto 2rem;
}
.landing-cta {
  display: flex;
  gap: 1rem;
  justify-content: center;
  flex-wrap: wrap;
}

/* ── Features ── */
.landing-features {
  padding: 6rem 2rem;
  max-width: 1100px;
  margin: 0 auto;
  width: 100%;
}
.landing-section-header {
  text-align: center;
  margin-bottom: 3rem;
}
.landing-section-tag {
  display: inline-block;
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.7rem;
  letter-spacing: 0.2em;
  color: #ff003c;
  margin-bottom: 0.75rem;
}
.landing-section-header h2 {
  font-size: clamp(1.6rem, 3.5vw, 2.4rem);
  font-weight: 800;
  color: #fff;
}
.landing-features-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}
.landing-feature-card {
  padding: 1.5rem;
  border: 1px solid rgba(255,255,255,0.08);
  background: rgba(255,255,255,0.02);
  transition: all 0.3s;
}
.landing-feature-card:hover {
  border-color: rgba(255,0,60,0.3);
  background: rgba(255,0,60,0.03);
}
.landing-feature-icon {
  font-size: 1.5rem;
  color: #ff003c;
  display: block;
  margin-bottom: 0.75rem;
}
.landing-feature-card h3 {
  font-size: 1.1rem;
  font-weight: 700;
  color: #fff;
  margin-bottom: 0.5rem;
}
.landing-feature-card p {
  font-size: 0.85rem;
  color: rgba(255,255,255,0.5);
  line-height: 1.7;
}

/* ── CTA Section ── */
.landing-cta-section {
  padding: 6rem 2rem;
  text-align: center;
}
.landing-cta-content {
  max-width: 500px;
  margin: 0 auto;
}
.landing-cta-content h2 {
  font-size: clamp(1.5rem, 3vw, 2.2rem);
  font-weight: 800;
  color: #fff;
  margin-bottom: 1rem;
}
.landing-cta-content p {
  color: rgba(255,255,255,0.5);
  margin-bottom: 2rem;
  line-height: 1.7;
}

/* ── Footer ── */
.landing-footer {
  margin-top: auto;
  border-top: 1px solid rgba(255,255,255,0.06);
  padding: 1.5rem 2rem;
}
.landing-footer-inner {
  max-width: 1100px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.8rem;
  color: rgba(255,255,255,0.4);
}
.landing-footer-links {
  display: flex;
  gap: 1.5rem;
}
.landing-footer-links a {
  color: rgba(255,255,255,0.4);
  text-decoration: none;
  transition: color 0.2s;
}
.landing-footer-links a:hover { color: #fff; }

/* ── Mobile ── */
@media (max-width: 640px) {
  .landing-header { padding: 0.75rem 1rem; }
  .landing-nav { gap: 0.75rem; }
  .landing-nav a { font-size: 0.75rem; }
  .landing-btn, .landing-btn-outline { padding: 0.5rem 0.8rem; font-size: 0.7rem; }
  .landing-hero { padding: 5rem 1rem 3rem; }
  .landing-features { padding: 4rem 1rem; }
  .landing-features-grid { grid-template-columns: 1fr; }
  .landing-cta-section { padding: 4rem 1rem; }
  .landing-footer { padding: 1rem; }
  .landing-footer-inner { flex-direction: column; gap: 0.5rem; text-align: center; }
}
      `}} />
    </div>
  )
}
