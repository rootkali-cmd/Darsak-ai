'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ChevronDown, HelpCircle, Search, Mail } from 'lucide-react'
import { useRouter } from 'next/navigation'

const faqs = [
  {
    q: 'ما هي منصة درسك AI؟',
    a: 'درسك AI هي منصة متكاملة لإدارة السناتر التعليمية. تساعد أصحاب السناتر والمدرسين على إدارة الطلاب، تسجيل الحضور، تتبع الدرجات، تحصيل المصاريف، وتحليلات ذكية بالذكاء الاصطناعي.',
  },
  {
    q: 'هل المنصة مجانية؟',
    a: 'نقدم باقة مجانية محدودة الميزات للبدء. للاستخدام الكامل، تتوفر باقات مدفوعة تبدأ من 200 ج.م شهرياً. يمكنك تجربة المنصة مجاناً بدون بطاقة ائتمان.',
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
  const router = useRouter()
  const [openIndex, setOpenIndex] = useState<number | null>(null)
  const [search, setSearch] = useState('')

  const filtered = faqs.filter(f => f.q.includes(search) || f.a.includes(search))

  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(180deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)' }}>
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-indigo-500/5 rounded-full blur-3xl" />
      </div>

      <div className="relative max-w-5xl mx-auto px-4 py-20">
        <button
          onClick={() => router.push('/')}
          className="inline-flex items-center gap-2 text-sm text-slate-400 hover:text-white transition-colors mb-16"
        >
          ← العودة للرئيسية
        </button>

        <div className="max-w-3xl mx-auto">
          <motion.div
            className="text-center mb-10"
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          >
            <HelpCircle size={40} className="mx-auto mb-4 text-indigo-400" />
            <h1 className="text-3xl md:text-4xl font-extrabold text-white mb-2">الأسئلة الشائعة</h1>
            <p className="text-slate-400">أجوبة على أكثر الأسئلة تكراراً</p>
          </motion.div>

          <motion.div
            className="relative mb-8"
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          >
            <Search size={18} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-500" />
            <input
              className="w-full pr-12 pl-4 py-3.5 rounded-xl bg-white/[0.03] border border-white/[0.08] text-white placeholder:text-slate-500 focus:outline-none focus:border-indigo-500/50 focus:bg-white/[0.05] transition-all duration-300 text-sm"
              placeholder="ابحث في الأسئلة..."
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </motion.div>

          <motion.div
            className="space-y-3"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.2, duration: 0.5 }}
          >
            {filtered.map((faq, i) => (
              <div
                key={i}
                className="rounded-xl bg-white/[0.03] border border-white/[0.08] overflow-hidden hover:border-white/[0.12] transition-colors duration-300"
              >
                <button
                  onClick={() => setOpenIndex(openIndex === i ? null : i)}
                  className="w-full flex items-center justify-between gap-4 p-5 text-right"
                >
                  <span className="font-medium text-sm text-white leading-relaxed">{faq.q}</span>
                  <motion.div
                    animate={{ rotate: openIndex === i ? 180 : 0 }}
                    transition={{ duration: 0.2 }}
                    className="flex-shrink-0 text-indigo-400"
                  >
                    <ChevronDown size={18} />
                  </motion.div>
                </button>
                <AnimatePresence>
                  {openIndex === i && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
                      className="overflow-hidden"
                    >
                      <div className="px-5 pb-5">
                        <div className="border-t border-white/[0.08] pt-4">
                          <p className="text-sm text-slate-400 leading-relaxed">{faq.a}</p>
                        </div>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            ))}
            {filtered.length === 0 && (
              <div className="text-center py-12">
                <p className="text-slate-500">لا توجد نتائج للبحث</p>
              </div>
            )}
          </motion.div>

          <motion.div
            className="mt-12 text-center rounded-2xl p-8 bg-white/[0.03] border border-white/[0.08]"
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          >
            <Mail size={24} className="mx-auto mb-3 text-indigo-400" />
            <p className="font-bold text-white mb-1">لم تجد إجابة لسؤالك؟</p>
            <p className="text-sm text-slate-400 mb-5">فريق الدعم الفني جاهز لمساعدتك</p>
            <a
              href="/contact"
              className="inline-flex items-center gap-2 px-6 py-3 text-sm font-bold text-white rounded-xl transition-all duration-300"
              style={{ background: 'linear-gradient(135deg, #6366F1, #818CF8)' }}
            >
              اتصل بنا
            </a>
          </motion.div>
        </div>

        <div className="mt-20 pt-8 border-t border-white/[0.08] flex flex-col md:flex-row justify-between items-center gap-4 text-sm text-slate-500">
          <span>© 2026 DARSAK AI. جميع الحقوق محفوظة.</span>
          <div className="flex gap-4">
            <a href="/about" className="hover:text-slate-300 transition-colors">من نحن</a>
            <a href="/privacy" className="hover:text-slate-300 transition-colors">سياسة الخصوصية</a>
            <a href="/terms" className="hover:text-slate-300 transition-colors">شروط الخدمة</a>
            <a href="/contact" className="hover:text-slate-300 transition-colors">اتصل بنا</a>
            <a href="/faq" className="hover:text-slate-300 transition-colors">الأسئلة الشائعة</a>
          </div>
        </div>
      </div>
    </div>
  )
}
