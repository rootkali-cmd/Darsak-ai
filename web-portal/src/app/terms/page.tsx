'use client'

import Image from 'next/image'
import Link from 'next/link'

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-black text-white/70">
      <div className="max-w-3xl mx-auto px-4 py-20">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/40 hover:text-white/70 transition-colors mb-10">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
          الرئيسية
        </Link>

        <div className="flex items-center gap-3 mb-8">
          <Image src="/logo.png" alt="DARSAK AI" width={32} height={32} className="rounded-lg" style={{ width: 32, height: 32 }} />
          <h1 className="text-3xl font-black text-white">الشروط والأحكام</h1>
        </div>
        <p className="text-sm text-white/30 mb-10">آخر تحديث: يوليو 2026</p>

        <div className="space-y-8 text-sm leading-relaxed">
          <section>
            <h2 className="text-lg font-bold text-white mb-3">1. قبول الشروط</h2>
            <p>باستخدامك لمنصة DarsakAI ("المنصة")، أنت توافق على الالتزام بهذه الشروط والأحكام بالكامل. إذا لا توافق على أي شرط، يُرجى عدم استخدام المنصة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">2. وصف الخدمة</h2>
            <p>DarsakAI منصة تعليمية إلكترونية توفر أدوات لإدارة المدارس والسنترات تشمل: إدارة الطلاب، الامتحانات والتصحيح بالذكاء الاصطناعي، الحضور والغياب، الكورسات التعليمية، الفواتير والمصاريف، وتحليلات الأداء بالذكاء الاصطناعي.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">3. التسجيل والحسابات</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>يجب أن يكون عمرك 18 سنة على الأقل لتسجيل حساب كمدرس.</li>
              <li>أنت مسؤول عن الحفاظ على سرية بيانات حسابك.</li>
              <li>يُحظر استخدام المنصة لأغراض غير قانونية أو احتيالية.</li>
              <li>يحق لنا تعليق أو حذف الحسابات التي تنتهك الشروط.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">4. الاشتراكات والدفع</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>الباقات والأسعار معروضة على الموقع وقد تتغير مع إشعار مسبق.</li>
              <li>الاشتراكات تُجدد تلقائياً ما لم يتم الإلغاء قبل انتهاء الفترة الحالية.</li>
              <li>الدفع يتم عبر فودافون كاش أو انستاباي أو نقدي كما هو محدد في التطبيق.</li>
              <li>يجب دفع جميع المستحقات قبل تفعيل الخدمة أو تجديدها.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">5. سياسة الاسترجاع</h2>
            <p>يرجى الرجوع إلى صفحة <Link href="/refund" className="text-white underline hover:text-white/80">سياسة استرجاع الأموال</Link> للتفاصيل الكاملة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">6. المحتوى والملكية الفكرية</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>جميع محتويات المنصة (تصميم، كود، شعارات، نصوص) هي ملك لـ DarsakAI ومحمية بقوانين حقوق الملكية الفكرية.</li>
              <li>المحتوى الذي ترفعه (فيديوهات، ملفات، امتحانات) يبقى ملكاً لك، لكنك تمنحنا ترخيصاً لعرضه داخل المنصة.</li>
              <li>يُحظر نسخ أو توزيع أو إعادة بيع محتوى المنصة بدون إذن كتابي مسبق.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">7. المسؤولية والضمانات</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>المنصة تُقدم "كما هي" و"حسب التوفر" بدون ضمانات صريحة أو ضمنية.</li>
              <li>لا نضمن عدم انقطاع الخدمة أو خلوها من الأخطاء.</li>
              <li>لا نتحمل المسؤولية عن أي أضرار غير مباشرة أو تبعية ناتجة عن استخدام المنصة.</li>
              <li>أنت المسؤول الوحيد عن محتوى數據 الذي تدخله في المنصة.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">8. حدود المسؤولية المالية</h2>
            <p>في أي حالة، لا تتجاوز إجمالي مسؤوليتنا تجاهك المبلغ الذي دفعته خلال الاثني عشر (12) شهراً السابقة للحادثة المسببة للمسؤولية.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">9. التعديلات</h2>
            <p>نحتفظ بالحق في تعديل هذه الشروط في أي وقت. الاستمرار في استخدام المنصة بعد التعديلات يُعتبر قبولاً للشروط المحدثة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">10. القانون الحاكم</h2>
            <p>هذه الشروط محكومة بقوانين جمهورية مصر العربية. أي نزاع ينشأ عنها يختص بالمحاكم المصرية المختصة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">11. التواصل</h2>
            <p>لأي استفسارات حول الشروط والأحكام:</p>
            <p className="mt-2 text-white/50">support@darsakai.com</p>
            <p className="text-white/50">واتساب: 01055359719</p>
          </section>
        </div>
      </div>
    </div>
  )
}
