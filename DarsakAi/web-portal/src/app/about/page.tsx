'use client'

import { motion } from 'framer-motion'
import { Shield, Target, Lightbulb, HeartHandshake, ArrowRight } from 'lucide-react'
import { useRouter } from 'next/navigation'

const values = [
  { icon: Target, title: 'رسالتنا', desc: 'بناء أداة بسيطة وعملية تخلّص أصحاب السناتر من الفوضى الورقية وتديها وقت تركز على التدريس.' },
  { icon: Lightbulb, title: 'قصة البداية', desc: 'اتولدت الفكرة من معاناة حقيقية في إدارة سنتر — ورق، متابعة، مصاريف، حضور. قلنا لازم يبقى فيه حل وما ينفعش نستنى.' },
  { icon: HeartHandshake, title: 'الوضع دلوقتي', desc: 'لسه في البداية. بنشتغل حاجة بحاجة، بنسمع للمدرسين اللي بيستخدموا المنصة، وبنطور على قد الإمكانيات.' },
  { icon: Shield, title: 'الشفافية', desc: 'مش بنحط أرقام وهمية عشان نظهر كبار. احنا ناس صغيرة لسة بنحاول نبنى حاجة مفيدة. لو عايز تعرف حقيقة المنصة، جربها بنفسك.' },
]

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 24 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true },
  transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1], delay },
})

export default function AboutPage() {
  const router = useRouter()

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

        <motion.div className="text-center mb-16" {...fadeUp()}>
          <span className="inline-block px-3 py-1 text-xs font-bold tracking-widest mb-4 border border-indigo-500/40 text-indigo-400 rounded-full">
            من نحن
          </span>
          <h1 className="text-3xl md:text-4xl font-extrabold text-white mb-4">منصة لسة في أول الطريق</h1>
          <p className="text-slate-400 max-w-2xl mx-auto leading-relaxed">
            درسك AI مش شركة ضخمة ولا عندها ملايين المستخدمين. احنا مشروع صغير بنحاول نقدم أداة مفيدة لمدرسين السناتر.
            مبنكترش أرقام وهمية — اللي تشوفه هو اللي موجود.
          </p>
        </motion.div>

        <motion.div className="max-w-3xl mx-auto mb-20" {...fadeUp(0.1)}>
          <h2 className="text-2xl font-bold text-white mb-6">إحنا مين فعلاً؟</h2>
          <div className="space-y-4 text-slate-400 leading-relaxed">
            <p>
              درسك AI منصة إلكترونية لإدارة السناتر التعليمية. حالياً في مرحلة البيتا — بنختبر المنتج مع مجموعة صغيرة من المعلمين
              عشان نضبط الأمور قبل الإطلاق الرسمي.
            </p>
            <p>
              <strong className="text-white">دي حقيقة المنصة النهارده:</strong>
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

        <motion.div className="max-w-3xl mx-auto mb-20" {...fadeUp(0.2)}>
          <h2 className="text-2xl font-bold text-white mb-6">إيه اللي موجود فعلاً؟</h2>
          <div className="space-y-4 text-slate-400 leading-relaxed">
            <p>المنصة فيها دلوقتي:</p>
            <ul className="list-disc pr-6 space-y-3">
              <li><strong className="text-white">إدارة الطلاب:</strong> تضيف طلاب، تعدل، تحذف. كل طالب ليه كود QR.</li>
              <li><strong className="text-white">الحضور والغياب:</strong> تسجيل حضور يدوي أو بالباركود.</li>
              <li><strong className="text-white">الدرجات والامتحانات:</strong> تسجيل درجات ومتابعة الأداء.</li>
              <li><strong className="text-white">المجموعات:</strong> تقسيم الطلاب حسب المستوى والمادة.</li>
              <li><strong className="text-white">الفواتير:</strong> تحصيل المصاريف ومتابعة المدفوع.</li>
              <li><strong className="text-white">تحليلات AI:</strong> تحليل أداء الطالب واقتراح نقاط الضعف والقوة.</li>
            </ul>
            <p>
              كل الميزات دي شغالة فعلاً — مش promises. تقدر تجربها كلها مجاناً 30 يوماً.
            </p>
          </div>
        </motion.div>

        <motion.div className="mb-20" {...fadeUp(0.3)}>
          <h2 className="text-2xl font-bold text-white mb-10 text-center">اللي بنؤمن بيه</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {values.map((v, i) => {
              const Icon = v.icon
              return (
                <motion.div
                  key={v.title}
                  className="p-6 rounded-2xl bg-white/[0.03] border border-white/[0.08] hover:bg-white/[0.05] hover:border-indigo-500/30 transition-all duration-300"
                  {...fadeUp(i * 0.08)}
                >
                  <Icon size={24} className="text-indigo-400 mb-4" />
                  <h3 className="font-bold text-white mb-2">{v.title}</h3>
                  <p className="text-sm text-slate-400 leading-relaxed">{v.desc}</p>
                </motion.div>
              )
            })}
          </div>
        </motion.div>

        <motion.div
          className="text-center rounded-2xl p-10 bg-white/[0.03] border border-white/[0.08]"
          {...fadeUp(0.4)}
        >
          <h2 className="text-2xl font-bold text-white mb-3">جرب بنفسك — مجاناً</h2>
          <p className="text-slate-400 mb-6">مفيش حاجة تخسرها. أول 30 يوم مجاناً، وفي أي وقت تقدر تسحب.</p>
          <a
            href="/register"
            className="inline-flex items-center gap-2 px-6 py-3 text-sm font-bold text-white rounded-xl transition-all duration-300"
            style={{ background: 'linear-gradient(135deg, #6366F1, #818CF8)' }}
          >
            ابدأ مجاناً
            <ArrowRight size={16} />
          </a>
        </motion.div>

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
