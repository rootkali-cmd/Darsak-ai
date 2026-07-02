'use client'

import Image from 'next/image'
import Link from 'next/link'

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-black text-white/70">
      <div className="max-w-3xl mx-auto px-4 py-20">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/40 hover:text-white/70 transition-colors mb-10">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
          الرئيسية
        </Link>

        <div className="flex items-center gap-3 mb-8">
          <Image src="/logo.png" alt="DARSAK AI" width={32} height={32} className="rounded-lg" style={{ width: 32, height: 32 }} />
          <h1 className="text-3xl font-black text-white">سياسة الخصوصية</h1>
        </div>
        <p className="text-sm text-white/30 mb-10">آخر تحديث: يوليو 2026</p>

        <div className="space-y-8 text-sm leading-relaxed">
          <section>
            <h2 className="text-lg font-bold text-white mb-3">1. مقدمة</h2>
            <p>مرحباً بك في منصة DarsakAI (&quot;المنصة&quot;). نحن نلتزم بحماية خصوصيتك وبياناتك الشخصية. تصف هذه السياسة كيف نجمع的信息 ونستخدمها ونحميها عند استخدامك لخدماتنا.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">2. البيانات التي نجمعها</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li><strong className="text-white/80">بيانات الحساب:</strong> الاسم الكامل، البريد الإلكتروني، رقم الهاتف، كلمة المرور المشفرة.</li>
              <li><strong className="text-white/80">بيانات الطلاب:</strong> أسماء الطلاب وأكوادهم ودرجاتهم وسجل حضورهم وغيابهم — التي يدخلها المدرسون.</li>
              <li><strong className="text-white/80">بيانات الدفع:</strong> سجل المعاملات المالية والمبالغ المدفوعة (بدون بيانات البطاقة البنكية).</li>
              <li><strong className="text-white/80">بيانات الاستخدام:</strong> نوع الجهاز، عنوان IP، سجل النشاط داخل المنصة.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">3. كيف نستخدم البيانات</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>تقديم وتحسين خدمات المنصة.</li>
              <li>إدارة حسابات المدرسين والطلاب.</li>
              <li>معالجة المدفوعات وتحصيل الاشتراكات.</li>
              <li>إرسال إشعارات مهمة تتعلق بالخدمة.</li>
              <li>تحليل استخدام المنصة لتحسين تجربة المستخدم.</li>
              <li>منع الاحتيال وإساءة الاستخدام.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">4. مشاركة البيانات</h2>
            <p>لا نبيع بياناتك الشخصية لأي طرف ثالث. قد نشارك بياناتك فقط في الحالات التالية:</p>
            <ul className="list-disc list-inside space-y-2 text-white/60 mt-2">
              <li>بموجب طلب قانوني أو أمر قضائي.</li>
              <li>مع مزودي الخدمات الأساسيين (استضافة السحابية، معالجة الدفع) وفقاً لاتفاقيات السرية.</li>
              <li>لحماية حقوقنا القانونية أو سلامة المستخدمين.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">5. أمان البيانات</h2>
            <p>نتخذ إجراءات أمنية صارمة لحماية بياناتك، بما في ذلك تشفير كلمات المرور، والاتصالات المشفرة (SSL)، والوصول المحدود للبيانات الحساسة. مع ذلك، لا توجد طريقة نقل إلكتروني آمنة بنسبة 100%.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">6. حقوق المستخدم</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li> حق الوصول إلى بياناتك الشخصية وتصديرها.</li>
              <li> حق طلب تعديل بياناتك أو حذفها نهائياً من منصتنا.</li>
              <li>حق الاعتراض على معالجة بياناتك لأغراض تسويقية.</li>
              <li>حق سحب موافقتك على معالجة البيانات في أي وقت.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">7. الاحتفاظ بالبيانات</h2>
            <p>نحتفظ ببياناتك طالما أن حسابك نشط أو según необходимости لتقديم الخدمات. عند حذف الحساب، نحذف بياناتك خلال 30 يوماً باستثناء البيانات المطلوب الاحتفاظ بها قانونياً.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">8. ملفات تعريف الارتباط</h2>
            <p>نستخدم ملفات تعريف الارتباط الضرورية لتشغيل المنصة وتحسين تجربتك. يمكنك التحكم في إعدادات المتصفح لرفض ملفات تعريف الارتباط، لكن قد يؤثر ذلك على وظائف المنصة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">9. الأطفال</h2>
            <p>المنصة مخصصة للمدرسين والإداريين. إذا كان المستخدم طالباً قاصراً، يجب الحصول على موافقة ولي الأمر أو الأخصائي الاجتماعي قبل استخدام الخدمة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">10. التعديلات على السياسة</h2>
            <p>نحتفظ بالحق في تعديل هذه السياسة في أي وقت. سيتم إشعارك بالتغييرات الجوهرية عبر البريد الإلكتروني أو من خلال المنصة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">11. التواصل</h2>
            <p>لأي استفسارات متعلقة بهذه السياسة، تواصل معنا على:</p>
            <p className="mt-2 text-white/50">support@darsakai.com</p>
            <p className="text-white/50">واتساب: 01055359719</p>
          </section>
        </div>
      </div>
    </div>
  )
}
