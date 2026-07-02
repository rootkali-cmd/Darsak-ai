'use client'

import Image from 'next/image'
import Link from 'next/link'
import { useState } from 'react'

const faqs = [
  { q: 'ما هي DarsakAI؟', a: 'DarsakAI منصة تعليمية ذكية بالذكاء الاصطناعي مصممة لإدارة المدارس والسنترات في مصر. توفر أدوات لإدارة الطلاب، الامتحانات، الحضور، الكورسات، الفواتير، وتحليلات الأداء.' },
  { q: 'كيف أبدأ استخدام المنصة؟', a: 'حمّل تطبيق المعلمين من صفحة التحميل، أنشئ حسابك، أدخل بيانات طلابك، وابدأ في إنشاء الامتحانات وإدارة سنترك. العملية تستغرق دقائق قليلة.' },
  { q: 'هل يوجد تطبيق للطلاب؟', a: 'نعم، يوجد تطبيق منفصل للطلاب يمكنهم من خلاله متابعة درجاتهم، حضورهم، الاختبارات، الكورسات، والتواصل مع مدرسهم.' },
  { q: 'كم تكلفة الاشتراك؟', a: 'نقدم 3 بااقات: الأساسي (350 ج.م/شهر) لحد 100 طالب، المحترف (750 ج.م/شهر) لحد 400 طالب، والمتكاملة (1250 ج.م/شهر) لحد 1000 طالب. يوجد باقة تجريبية مجانية.' },
  { q: 'هل يمكنني تجربة المنصة قبل الدفع؟', a: 'نعم، نقدم فترة تجريبية مجانية لتعرف على جميع ميزات المنصة قبل الاشتراك.' },
  { q: 'كيف يعمل التصحيح بالذكاء الاصطناعي؟', a: 'عند إنشاء امتحان اختيار من متعدد، يقوم الذكاء الاصطناعي بالتصحيح تلقائياً وتحليل نتائج كل طالب — نقاط القوة والضعف والمستوى العام.' },
  { q: 'هل بيانات طلابي آمنة؟', a: 'نعم، نستخدم تشفير SSL ونخزن البيانات على خوادم Supabase آمنة. لا نشارك بياناتك مع أي طرف ثالث. راجع سياسة الخصوصية الكاملة.' },
  { q: 'كيف أتواصل مع الدعم الفني؟', a: 'يمكنك التواصل معنا عبر الواتساب على 01055359719 أو عبر البريد الإلكتروني support@darsakai.com. نرد خلال 24 ساعة.' },
  { q: 'هل يمكنني إلغاء الاشتراك؟', a: 'نعم، يمكنك إلغاء تجديد الاشتراك في أي وقت. يسري الإلغاء من الفترة التالية. راجع سياسة استرجاع الأموال للتفاصيل.' },
  { q: 'هل المنصة تعمل على الكمبيوتر والموبايل؟', a: 'نعم، لدينا تطبيق موبايل للمعلمين والطلاب (Android)، وتطبيق سطح مكتب للمعلمين (Windows)، والموقع يعمل من المتصفح مباشرة.' },
]

export default function FAQPage() {
  const [open, setOpen] = useState<number | null>(null)

  return (
    <div className="min-h-screen bg-black text-white/70">
      <div className="max-w-3xl mx-auto px-4 py-20">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/40 hover:text-white/70 transition-colors mb-10">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
          الرئيسية
        </Link>

        <div className="flex items-center gap-3 mb-4">
          <Image src="/icon.png" alt="DarsakAI" width={40} height={40} className="rounded-xl" style={{ width: 40, height: 40 }} />
          <h1 className="text-3xl font-black text-white">الأسئلة الشائعة</h1>
        </div>
        <p className="text-sm text-white/40 mb-12">إجابات على أكثر الاستفسارات شيوعاً</p>

        <div className="space-y-3">
          {faqs.map((faq, i) => (
            <div key={i} className="border border-white/[0.06] rounded-xl overflow-hidden">
              <button
                onClick={() => setOpen(open === i ? null : i)}
                className="w-full flex items-center justify-between p-5 text-right hover:bg-white/[0.02] transition-colors"
              >
                <span className="text-sm font-bold text-white">{faq.q}</span>
                <svg
                  width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
                  className={`text-white/30 transition-transform duration-300 flex-shrink-0 mr-4 ${open === i ? 'rotate-180' : ''}`}
                >
                  <path d="M6 9l6 6 6-6" />
                </svg>
              </button>
              <div className={`transition-all duration-300 overflow-hidden ${open === i ? 'max-h-[500px] opacity-100' : 'max-h-0 opacity-0'}`}>
                <p className="px-5 pb-5 text-sm text-white/50 leading-relaxed">{faq.a}</p>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-12 text-center">
          <p className="text-sm text-white/40 mb-4">لقيت إجابتك؟ لو عندك سؤال تاني، تواصل معنا</p>
          <Link href="/contact" className="inline-flex items-center gap-2 px-6 py-3 bg-white text-black font-bold rounded-full hover:bg-gray-200 transition-colors text-sm">
            تواصل معنا
          </Link>
        </div>
      </div>
    </div>
  )
}
