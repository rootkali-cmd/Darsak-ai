'use client'

import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Shield, Target, Users, Lightbulb, Award, HeartHandshake } from 'lucide-react'

const values = [
  { icon: Target, title: 'رسالتنا', desc: 'تمكين أصحاب السناتر ومدرسيها بأدوات ذكية تجعل إدارة السناتر أكثر فعالية، وتوفر وقتهم ليركزوا على ما يجيدونه: التدريس والإلهام.' },
  { icon: Lightbulb, title: 'رؤيتنا', desc: 'الريادة في التحول الرقمي لإدارة السناتر التعليمية في العالم العربي، من خلال منصة ذكية تجمع بين أحدث تقنيات AI وأبسط واجهات الاستخدام.' },
  { icon: Users, title: 'المجتمع', desc: 'نبني مجتمعاً تعليمياً متفاعلاً يضم آلاف أصحاب السناتر والمدرسين الذين يشاركون الخبرات ويتطورون معاً.' },
  { icon: Award, title: 'الجودة', desc: 'نلتزم بأعلى معايير الجودة في كل ميزة نطلقها، مع اختبارات دقيقة وملاحظات مستمرة من المعلمين.' },
  { icon: Shield, title: 'الخصوصية', desc: 'بيانات طلابك آمنة ومشفرة. لا نشارك معلوماتك مع أي طرف ثالث. الخصوصية هي أساس ثقتنا.' },
  { icon: HeartHandshake, title: 'الدعم', desc: 'فريق دعم فني متكامل يجيب على استفساراتك خلال ساعات. لأن نجاحك هو نجاحنا.' },
]

const timeline = [
  { year: '2023', title: 'الفكرة', desc: 'انطلقت فكرة درسك AI من فصل دراسي حقيقي، حيث لاحظ مؤسسونا التحديات اليومية التي يواجهها المعلمون.' },
  { year: '2024', title: 'الإطلاق', desc: 'أطلقنا النسخة الأولى من المنصة وبدأنا مع 50 معلماً في المرحلة التجريبية، وتلقينا أكثر من 2000 اقتراح للتطوير.' },
  { year: '2025', title: 'النمو', desc: 'وصلنا إلى أكثر من 5000 معلم مسجل، وأضفنا ميزات AI المتقدمة: التحليل الذكي، التصحيح الآلي، والاختبارات الذكية.' },
  { year: '2026', title: 'التميز', desc: 'نخدم اليوم أكثر من 15,000 معلم عبر 3 تطبيقات (ويب، موبايل، ديسكتوب) مع تقييم 4.8/5 من المستخدمين.' },
]

export default function AboutPage() {
  const router = useRouter()

  return (
    <div>
      <header className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 md:px-10 py-4" style={{ background: 'var(--header-bg)', backdropFilter: 'blur(12px)', borderBottom: '1px solid var(--card-border)' }}>
        <div className="flex items-center gap-2">
          <span className="text-lg text-[var(--accent)]">◈</span>
          <span className="font-bold tracking-widest text-sm" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</span>
        </div>
        <nav className="flex items-center gap-4 md:gap-6">
          <a href="/" className="text-sm text-[var(--text-muted)] hover:text-[var(--text)] transition-colors">الرئيسية</a>
          <a href="/pricing" className="text-sm text-[var(--text-muted)] hover:text-[var(--text)] transition-colors">الباقات</a>
          <a href="/login" className="btn btn-outline btn-sm">دخول</a>
          <a href="/register" className="btn btn-primary btn-sm">ابدأ مجاناً</a>
        </nav>
      </header>

      <main>
        {/* Hero */}
        <section className="pt-32 pb-20 px-6 text-center" style={{ background: 'linear-gradient(180deg, var(--bg-secondary) 0%, var(--bg) 100%)' }}>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
            <span className="inline-block px-3 py-1 text-xs font-bold tracking-widest mb-4 border" style={{ borderColor: 'var(--accent)', color: 'var(--accent)' }}>من نحن</span>
            <h1 className="text-4xl md:text-5xl font-black mb-4">نبني مستقبل السناتر</h1>
            <p className="text-lg text-[var(--text-muted)] max-w-2xl mx-auto leading-relaxed">
              درسك AI منصة ذكية لإدارة السناتر التعليمية، ولدت من رحم الفصول الدراسية الحقيقية. 
              هدفنا: تحويل طريقة إدارة السناتر باستخدام الذكاء الاصطناعي.
            </p>
          </motion.div>
        </section>

        {/* Story */}
        <section className="page-section">
          <motion.div className="max-w-3xl mx-auto" initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }}>
            <h2 className="text-2xl font-bold mb-6 text-center">قصتنا</h2>
            <div className="prose mx-auto">
              <p>
                في عام 2023، كان مؤسسو درسك AI يديرون سناتر تعليمية حقيقية. كل يوم، كانوا يواجهون تحديات: 
                متابعة حضور الطلاب في سناتر متعددة، تحصيل المصاريف، تصحيح الامتحانات، وإعداد التقارير لكل ولي أمر.
              </p>
              <p>
                أدركنا أن التكنولوجيا يمكن أن تكون الحل. ليس فقط لأتمتة المهام المتكررة، بل لتقديم رؤى وتحليلات 
                عميقة كان من المستحيل الحصول عليها يدوياً. هكذا ولدت درسك AI — أول منصة متكاملة لإدارة السناتر.
              </p>
              <p>
                اليوم، بعد 3 سنوات من التطوير المستمر، يثق بنا أكثر من 15,000 مستخدم في جميع أنحاء العالم العربي. 
                نحن لسنا مجرد منصة تقنية — نحن شريك في نجاح سنترك.
              </p>
            </div>
          </motion.div>
        </section>

        {/* Timeline */}
        <section className="page-section" style={{ background: 'var(--bg-secondary)' }}>
          <h2 className="text-2xl font-bold mb-10 text-center">رحلتنا</h2>
          <div className="max-w-3xl mx-auto space-y-8">
            {timeline.map((item, i) => (
              <motion.div key={item.year} className="flex gap-6 items-start" initial={{ opacity: 0, x: -20 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.1 }}>
                <div className="flex-shrink-0 w-16 text-center">
                  <span className="text-sm font-bold text-[var(--accent)]" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{item.year}</span>
                  <div className="w-px h-full mx-auto mt-2" style={{ background: 'var(--card-border)' }} />
                </div>
                <div className="card card-hover p-5 flex-1">
                  <h3 className="font-bold mb-1">{item.title}</h3>
                  <p className="text-sm text-[var(--text-secondary)] leading-relaxed">{item.desc}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </section>

        {/* Values */}
        <section className="page-section">
          <h2 className="text-2xl font-bold mb-10 text-center">قيمنا</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {values.map((v, i) => {
              const Icon = v.icon
              return (
                <motion.div key={v.title} className="card card-hover p-6" initial={{ opacity: 0, y: 15 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.06 }}>
                  <Icon size={24} className="text-[var(--accent)] mb-4" />
                  <h3 className="font-bold mb-2">{v.title}</h3>
                  <p className="text-sm text-[var(--text-secondary)] leading-relaxed">{v.desc}</p>
                </motion.div>
              )
            })}
          </div>
        </section>

        {/* Stats */}
        <section className="page-section text-center" style={{ background: 'var(--bg-secondary)' }}>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8 max-w-3xl mx-auto">
            {[
              { num: '15,000+', label: 'معلم يستخدمون المنصة' },
              { num: '200,000+', label: 'طالب مسجلين' },
              { num: '98%', label: 'رضا المستخدمين' },
              { num: '4.8/5', label: 'تقييم المتجر' },
            ].map((s, i) => (
              <motion.div key={s.label} initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.1 }}>
                <div className="text-3xl font-black text-[var(--accent)]">{s.num}</div>
                <p className="text-sm text-[var(--text-muted)] mt-1">{s.label}</p>
              </motion.div>
            ))}
          </div>
        </section>

        {/* CTA */}
        <section className="page-section text-center">
          <motion.div initial={{ opacity: 0, y: 15 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}>
            <h2 className="text-2xl font-bold mb-3">انضم إلى آلاف المعلمين</h2>
            <p className="text-[var(--text-muted)] mb-6">حوّل سنترك إلى نظام متكامل — ابدأ مجاناً</p>
            <a href="/register" className="btn btn-primary btn-lg">→ ابدأ مجاناً</a>
          </motion.div>
        </section>
      </main>

      <footer className="border-t py-6 px-6" style={{ borderColor: 'var(--card-border)' }}>
        <div className="max-w-5xl mx-auto flex flex-col md:flex-row justify-between items-center gap-4 text-sm text-[var(--text-muted)]">
          <span>© 2026 DARSAK AI. جميع الحقوق محفوظة.</span>
          <div className="flex gap-4">
            <a href="/about" className="hover:text-[var(--text)] transition-colors">من نحن</a>
            <a href="/privacy" className="hover:text-[var(--text)] transition-colors">سياسة الخصوصية</a>
            <a href="/terms" className="hover:text-[var(--text)] transition-colors">شروط الخدمة</a>
            <a href="/contact" className="hover:text-[var(--text)] transition-colors">اتصل بنا</a>
            <a href="/faq" className="hover:text-[var(--text)] transition-colors">الأسئلة الشائعة</a>
          </div>
        </div>
      </footer>
    </div>
  )
}
