'use client'

import { motion } from 'framer-motion'
import { Shield, Target, Lightbulb, HeartHandshake } from 'lucide-react'

const values = [
  { icon: Target, title: 'رسالتنا', desc: 'بناء أداة بسيطة وعملية تخلّص أصحاب السناتر من الفوضى الورقية وتديها وقت تركز على التدريس.' },
  { icon: Lightbulb, title: 'قصة البداية', desc: 'اتولدت الفكرة من معاناة حقيقية في إدارة سنتر — ورق، متابعة، مصاريف، حضور. قلنا لازم يبقى فيه حل وما ينفعش نستنى.' },
  { icon: HeartHandshake, title: 'الوضع دلوقتي', desc: 'لسه في البداية. بنشتغل حاجة بحاجة، بنسمع للمدرسين اللي بيستخدموا المنصة، وبنطور على قد الإمكانيات.' },
  { icon: Shield, title: 'الشفافية', desc: 'مش بنحط أرقام وهمية عشان نظهر كبار. احنا ناس صغيرة لسة بنحاول نبنى حاجة مفيدة. لو عايز تعرف حقيقة المنصة، جربها بنفسك.' },
]

export default function AboutPage() {
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
        <section className="pt-32 pb-16 px-6 text-center" style={{ background: 'linear-gradient(180deg, var(--bg-secondary) 0%, var(--bg) 100%)' }}>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
            <span className="inline-block px-3 py-1 text-xs font-bold tracking-widest mb-4 border" style={{ borderColor: 'var(--accent)', color: 'var(--accent)' }}>من نحن</span>
            <h1 className="text-3xl md:text-4xl font-black mb-4">منصة لسة في أول الطريق</h1>
            <p className="text-base text-[var(--text-muted)] max-w-2xl mx-auto leading-relaxed">
              درسك AI مش شركة ضخمة ولا عندها ملايين المستخدمين. احنا مشروع صغير بنحاول نقدم أداة مفيدة لمدرسين السناتر.
              مبنكترش أرقام وهمية — اللي تشوفه هو اللي موجود.
            </p>
          </motion.div>
        </section>

        {/* What we actually are */}
        <section className="page-section">
          <motion.div className="max-w-3xl mx-auto" initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }}>
            <h2 className="text-2xl font-bold mb-6">إحنا مين فعلاً؟</h2>
            <div className="space-y-4 text-[var(--text-secondary)] leading-relaxed">
              <p>
                درسك AI منصة إلكترونية لإدارة السناتر التعليمية. حالياً في مرحلة البيتا — بنختبر المنتج مع مجموعة صغيرة من المعلمين
                عشان نضبط الأمور قبل الإطلاق الرسمي.
              </p>
              <p>
                <strong>دي حقيقة المنصة النهارده:</strong>
              </p>
              <ul className="list-disc pr-6 space-y-2">
                <li>عدد المستخدمين النشطين: أقل من 50 معلم — لسة في البداية.</li>
                <li>عدد الطلاب المسجلين على المنصة: أقل من 100 طالب — كلهم في مرحلة الاختبار.</li>
                <li>التقييم والتغذية الراجعة: بنجمعها من المستخدمين الأوائل وبنشتغل عليها.</li>
                <li>المنصة لسة بتتطور — بنضيف ميزات جديدة كل أسبوع.</li>
              </ul>
              <p>
                إحنا مش بنحاول نبان أكبر من واقعنا. المنصة لسه صغيرة، بس بنشتغل بجد عشان نقدم حاجة مفيدة.
                لو عايز تجرب بنفسك، سجل مجاناً وادينا رأيك — هنسمع لك.
              </p>
            </div>
          </motion.div>
        </section>

        {/* What we offer */}
        <section className="page-section" style={{ background: 'var(--bg-secondary)' }}>
          <motion.div className="max-w-3xl mx-auto" initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }}>
            <h2 className="text-2xl font-bold mb-6">إيه اللي موجود فعلاً؟</h2>
            <div className="space-y-4 text-[var(--text-secondary)] leading-relaxed">
              <p>المنصة فيها دلوقتي:</p>
              <ul className="list-disc pr-6 space-y-2">
                <li><strong>إدارة الطلاب:</strong> تضيف طلاب، تعدل، تحذف. كل طالب ليه كود QR.</li>
                <li><strong>الحضور والغياب:</strong> تسجيل حضور يدوي أو بالباركود.</li>
                <li><strong>الدرجات والامتحانات:</strong> تسجيل درجات ومتابعة الأداء.</li>
                <li><strong>المجموعات:</strong> تقسيم الطلاب حسب المستوى والمادة.</li>
                <li><strong>الفواتير:</strong> تحصيل المصاريف ومتابعة المدفوع.</li>
                <li><strong>تحليلات AI:</strong> تحليل أداء الطالب واقتراح نقاط الضعف والقوة.</li>
              </ul>
              <p>
                كل الميزات دي شغالة فعلاً — مش promises. تقدر تجربها كلها مجاناً 30 يوماً.
              </p>
            </div>
          </motion.div>
        </section>

        {/* Values */}
        <section className="page-section">
          <h2 className="text-2xl font-bold mb-10 text-center">اللي بنؤمن بيه</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
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

        {/* CTA */}
        <section className="page-section text-center" style={{ background: 'var(--bg-secondary)' }}>
          <motion.div initial={{ opacity: 0, y: 15 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}>
            <h2 className="text-2xl font-bold mb-3">جرب بنفسك — مجاناً</h2>
            <p className="text-[var(--text-muted)] mb-6">مفيش حاجة تخسرها. أول 30 يوم مجاناً، وفي أي وقت تقدر تسحب.</p>
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
