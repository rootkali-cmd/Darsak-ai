'use client'

import Image from 'next/image'
import Link from 'next/link'

export default function RefundPage() {
  return (
    <div className="min-h-screen bg-black text-white/70">
      <div className="max-w-3xl mx-auto px-4 py-20">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/40 hover:text-white/70 transition-colors mb-10">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
          الرئيسية
        </Link>

        <div className="flex items-center gap-3 mb-8">
          <Image src="/logo.png" alt="DARSAK AI" width={32} height={32} className="rounded-lg" style={{ width: 32, height: 32 }} />
          <h1 className="text-3xl font-black text-white">سياسة استرجاع الأموال</h1>
        </div>
        <p className="text-sm text-white/30 mb-10">آخر تحديث: يوليو 2026</p>

        <div className="p-4 rounded-xl border border-white/10 bg-white/[0.02] mb-10">
          <p className="text-sm text-white/60 leading-relaxed">
            تنطبق هذه السياسة على جميع الاشتراكات والمنتجات الرقمية المقدمة من خلال منصة DarsakAI. يُرجى قراءة جميع البنود بعناية قبل طلب استرجاع المبلغ.
          </p>
        </div>

        <div className="space-y-8 text-sm leading-relaxed">
          <section>
            <h2 className="text-lg font-bold text-white mb-3">1. المبدأ العام</h2>
            <p className="font-semibold text-white/80 mb-2">جميع المدفوعات نهائية وغير قابلة للاسترجاع ما لم تتحقق الشروط المنصوص عليها أدناه.</p>
            <p>بشراء لاشتراك DarsakAI، أنت تقر بأنك قرأت هذه السياسة ووافقت على جميع بنودها.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">2. حالات عدم الاسترجاع (القاعدة العامة)</h2>
            <p className="mb-3">لا يحق استرجاع المبلغ في الحالات التالية:</p>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>بعد مرور 24 ساعة من تاريخ الدفع.</li>
              <li>بعد استخدام الخدمة (بما في ذلك تسجيل طلاب، إنشاء امتحانات، رفع محتوى، أو أي نشاط آخر).</li>
              <li>في حالة ترقية البقة من باقة أقل إلى باقة أعلى.</li>
              <li>في حالة عدم استخدام الخدمة ("لم أستخدمها" لا يُعتبر سبباً كافياً للاسترجاع).</li>
              <li>في حالة اشتراك المدرس في باقة مجانية أو تجريبية.</li>
              <li>في حالة الدفع النقدي أو عن طريق فودافون كاش أو انستاباي عبر شخص ثالث.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">3. حالات الاسترجاع الاستثنائية (المحدودة جداً)</h2>
            <p className="mb-3">يُسمح باسترجاع المبلغ فقط في الحالة التالية حصرياً:</p>
            <div className="p-4 rounded-xl border border-white/10 bg-white/[0.02]">
              <p className="font-semibold text-white/80 mb-2">الخدمة غير قابلة للاستخدام نهائياً بسبب عيب تقني من طرفنا:</p>
              <ul className="list-disc list-inside space-y-2 text-white/60">
                <li>عدم قدرة المدرس على تسجيل الدخول لمدة تزيد عن 48 ساعة متواصلة بسبب عيب في الخادم (وليس في اتصال الإنترنت أو الجهاز).</li>
                <li>عدم عمل جميع ميزات المنصة الأساسية (امتحانات + طلاب + درجات) لمدة تزيد عن 72 ساعة بسبب خلل في البنية التحتية.</li>
              </ul>
              <p className="mt-3 text-white/50">يجب إثبات الحالة bằng لقطات شاشة أو توثيق يؤكد أن العيب من طرفنا وليس من جهاز المدرس أو اتصاله.</p>
            </div>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">4. إجراءات طلب الاسترجاع</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>يجب إرسال طلب الاسترجاع عبر البريد الإلكتروني إلى support@darsakai.com أو عبر الواتساب 01055359719.</li>
              <li>يجب ذكر سبب الطلب بشكل واضح ومرفق جميع التوثيق المطلوب.</li>
              <li>يجب أن يكون الطلب خلال 24 ساعة من تاريخ الدفع فقط.</li>
              <li>نحتفظ بحق رفض أي طلب لا يستوفي الشروط المنصوص عليها.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">5. مدة معالجة طلب الاسترجاع</h2>
            <p>في حالة الموافقة على طلب الاسترجاع (الحالات الاستثنائية فقط)، يتم تحويل المبلغ خلال 7-14 يوم عمل إلى طريقة الدفع الأصلية.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">6. الإلغاء قبل التجديد</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>يمكنك إلغاء تجديد الاشتراك في أي وقت قبل موعد التجديد.</li>
              <li>لا يحق استرجاع المبلغ المدفوع عن الفترة الحالية في حالة الإلغاء.</li>
              <li>الإلغاء يسري من بداية الفترة التالية فقط.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">7. التغييرات في الباقات والأسعار</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>نحتفظ بالحق في تعديل الأسعار والباقات في أي وقت مع إشعار مسبق لا يقل عن 30 يوماً.</li>
              <li>الاشتراكات الحالية تبقى سارية بالسعر الأصلي حتى تاريخ التجديد التالي.</li>
              <li>لا يحق استرجاع الفرق في حالة خفض الأسعار.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">8. الاحتيال وإساءة الاستخدام</h2>
            <p>في حالة اكتشاف محاولة احتياد في طلب الاسترجاع (مثل استخدام الخدمة ثم طلب استرجاع المبلغ)، نحتفظ بحق تعليق الحساب نهائياً واتخاذ الإجراءات القانونية المناسبة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">9. قوة القضاء</h2>
            <p>لا نتحمل المسؤولية عن عدم تقديم الخدمة أو تأخرها بسبب ظروف خارجة عن إرادتنا، بما في ذلك لكن لا يقتصر على: الكوارث الطبيعية، الانقطاعات الكهربائية، مشاكل مزودي الخدمة السحابية، أو أعمال الحكومة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">10. القانون الحاكم</h2>
            <p>تخضع هذه السياسة لقوانين جمهورية مصر العربية. أي نزاع ينشأ عنها يختص بالمحاكم المصرية المختصة بالقاهرة.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">11. التواصل</h2>
            <p>لأي استفسارات متعلقة بهذه السياسة:</p>
            <p className="mt-2 text-white/50">support@darsakai.com</p>
            <p className="text-white/50">واتساب: 01055359719</p>
          </section>
        </div>
      </div>
    </div>
  )
}
