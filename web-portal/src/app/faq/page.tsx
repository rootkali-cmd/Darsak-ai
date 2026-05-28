'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { ChevronDown, HelpCircle, Search, Mail } from 'lucide-react'

const faqs = [
  {
    q: 'ما هي منصة درسك AI؟',
    a: 'درسك AI هي منصة متكاملة لإدارة السناتر التعليمية. تساعد أصحاب السناتر والمدرسين على إدارة الطلاب، تسجيل الحضور، تتبع الدرجات، تحصيل المصاريف، وتحليلات ذكية بالذكاء الاصطناعي.',
  },
  {
    q: 'هل المنصة مجانية؟',
    a: 'نقدم باقة مجانية محدودة الميزات للبدء. للاستخدام الكامل، تتوفر باقات مدفوعة تبدأ من 199 ج.م شهرياً. يمكنك تجربة المنصة مجاناً بدون بطاقة ائتمان.',
  },
  {
    q: 'كيف يمكنني إنشاء حساب؟',
    a: 'يمكنك إنشاء حساب مجاني من صفحة التسجيل. كل ما تحتاجه هو بريد إلكتروني صالح وكلمة مرور. بعد التسجيل، يمكنك البدء فوراً في إضافة الطلاب والمجموعات.',
  },
  {
    q: 'ما هي متطلبات تشغيل المنصة؟',
    a: 'الموقع الإلكتروني: يعمل على أي متصفح حديث (Chrome, Firefox, Edge, Safari). تطبيق الموبايل: Android 8.0 أو أحدث. تطبيق الديسكتوب: Windows 10 أو أحدث.',
  },
  {
    q: 'هل بيانات طلابي آمنة؟',
    a: 'نعم، جميع البيانات مشفرة أثناء النقل (TLS 1.3) والتخزين (AES-256). لدينا سياسة خصوصية صارمة ولا نشارك بياناتك مع أي طرف ثالث. أنت المالك الوحيد لبيانات طلابك.',
  },
  {
    q: 'كيف يعمل الذكاء الاصطناعي في المنصة؟',
    a: 'يستخدم AI في تحليل أداء الطلاب، إنشاء تقارير ذكية، اقتراح تمارين مخصصة، واستخراج أسئلة من ملفات PDF. كل باقة لها عدد محدد من طلبات AI شهرياً (5/day للباقة المجانية).',
  },
  {
    q: 'هل يمكنني استخدام المنصة على أكثر من جهاز؟',
    a: 'نعم، يمكنك تسجيل الدخول إلى حسابك من أي جهاز. جميع بياناتك متزامنة تلقائياً عبر السحابة. يمكنك التبديل بين الويب والموبايل والديسكتوب بسلاسة.',
  },
  {
    q: 'ماذا يحدث إذا انتهت صلاحية اشتراكي؟',
    a: 'يتم تحويل حسابك تلقائياً إلى الباقة المجانية مع الاحتفاظ بجميع بياناتك. يمكنك تجديد الاشتراك في أي وقت لاستعادة الميزات المدفوعة.',
  },
  {
    q: 'كيف يمكنني إلغاء اشتراكي؟',
    a: 'يمكنك إلغاء الاشتراك من صفحة الإعدادات في لوحة التحكم. الاشتراك الملغي يستمر حتى نهاية الفترة المدفوعة. لا يتم استرداد الرسوم للفترة المتبقية من الاشتراك الشهري.',
  },
  {
    q: 'هل يمكنني إضافة مساعدين لحسابي؟',
    a: 'نعم، ميزة المساعدين تسمح لك بإضافة مدرسين آخرين لمساعدتك في إدارة الفصول. قيد التطوير حالياً ومتاحة قريباً.',
  },
  {
    q: 'كيف يمكنني شراء كود اشتراك عبر فودافون كاش؟',
    a: 'تواصل معنا عبر صفحة "اتصل بنا" أو أرسل المبلغ المطلوب على رقم فودافون كاش المخصص. بعد التأكيد، نرسل لك كود التفعيل عبر واتساب أو تليجرام خلال 30 دقيقة.',
  },
  {
    q: 'هل تدعمون الدفع عبر البطاقات الائتمانية؟',
    a: 'حالياً، طرق الدفع المتاحة هي فودافون كاش (مصر) وأكواد التفعيل عبر تليجرام. نعمل على إضافة بطاقات الائتمان والدفع عبر المحافظ الإلكترونية قريباً.',
  },
  {
    q: 'ماذا أفعل إذا نسيت كلمة المرور؟',
    a: 'استخدم خاصية "نسيت كلمة المرور" في صفحة تسجيل الدخول. سيتم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني المسجل.',
  },
  {
    q: 'هل يمكنني تصدير بيانات طلابي؟',
    a: 'نعم، يمكنك تصدير بيانات الطلاب والدرجات والتقارير بصيغ CSV و PDF من لوحة التحكم. هذه الميزة متاحة في الباقة المتقدمة وما فوق.',
  },
  {
    q: 'كيف أتصل بفريق الدعم؟',
    a: 'يمكنك مراسلتنا عبر البريد الإلكتروني support@darsak.ai، أو من خلال صفحة "اتصل بنا"، أو عبر واتساب على الرقم +20 100 123 4567. نرد خلال 24 ساعة.',
  },
]

export default function FAQPage() {
  const [openIndex, setOpenIndex] = useState<number | null>(null)
  const [search, setSearch] = useState('')

  const filtered = faqs.filter(f => f.q.includes(search) || f.a.includes(search))

  return (
    <div>
      <header className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 md:px-10 py-4" style={{ background: 'var(--header-bg)', backdropFilter: 'blur(12px)', borderBottom: '1px solid var(--card-border)' }}>
        <div className="flex items-center gap-2">
          <span className="text-lg text-[var(--accent)]">◈</span>
          <span className="font-bold tracking-widest text-sm" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</span>
        </div>
        <nav className="flex items-center gap-4 md:gap-6">
          <a href="/" className="text-sm text-[var(--text-muted)] hover:text-[var(--text)] transition-colors">الرئيسية</a>
        </nav>
      </header>

      <main className="pt-24 pb-16 px-6">
        <div className="max-w-3xl mx-auto">
          <motion.div className="text-center mb-8" initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }}>
            <HelpCircle size={36} className="mx-auto mb-4 text-[var(--accent)]" />
            <h1 className="text-3xl font-black mb-2">الأسئلة الشائعة</h1>
            <p className="text-[var(--text-muted)]">أجوبة على أكثر الأسئلة تكراراً</p>
          </motion.div>

          <div className="relative mb-8">
            <Search size={18} className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" />
            <input
              className="input pr-10"
              placeholder="ابحث في الأسئلة..."
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </div>

          <motion.div className="space-y-2" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.1 }}>
            {filtered.map((faq, i) => (
              <div key={i} className="card overflow-hidden">
                <button
                  onClick={() => setOpenIndex(openIndex === i ? null : i)}
                  className="w-full flex items-center justify-between gap-4 p-4 text-right hover:bg-[rgba(0,0,0,0.01)] transition-colors"
                >
                  <span className="font-medium text-sm leading-relaxed">{faq.q}</span>
                  <ChevronDown size={16} className={`flex-shrink-0 transition-transform duration-200 ${openIndex === i ? 'rotate-180' : ''}`} style={{ color: 'var(--text-muted)' }} />
                </button>
                {openIndex === i && (
                  <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} className="px-4 pb-4">
                    <p className="text-sm text-[var(--text-secondary)] leading-relaxed border-t pt-3" style={{ borderColor: 'var(--card-border)' }}>{faq.a}</p>
                  </motion.div>
                )}
              </div>
            ))}
            {filtered.length === 0 && (
              <div className="text-center py-12">
                <p className="text-[var(--text-muted)]">لا توجد نتائج للبحث</p>
              </div>
            )}
          </motion.div>

          <motion.div className="mt-12 text-center card p-6" initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }}>
            <Mail size={24} className="mx-auto mb-3 text-[var(--accent)]" />
            <p className="font-bold mb-1">لم تجد إجابة لسؤالك؟</p>
            <p className="text-sm text-[var(--text-muted)] mb-4">فريق الدعم الفني جاهز لمساعدتك</p>
            <a href="/contact" className="btn btn-primary">اتصل بنا</a>
          </motion.div>
        </div>
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
