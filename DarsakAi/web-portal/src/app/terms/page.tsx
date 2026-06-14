'use client'

import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Scale } from 'lucide-react'

export default function TermsPage() {
  const router = useRouter()

  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(180deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)' }}>
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl" />
      </div>
      <div className="relative max-w-3xl mx-auto px-4 py-20">
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-8">
          <motion.div className="text-center mb-10" initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }}>
            <Scale size={36} className="mx-auto mb-4 text-indigo-400" />
            <h1 className="text-3xl font-black mb-2 text-white">شروط الخدمة</h1>
            <p className="text-sm text-white/50">آخر تحديث: 15 مايو 2026</p>
          </motion.div>

          <motion.div className="space-y-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.2 }}>
            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">1. قبول الشروط</h2>
            <p className="text-white/60 leading-relaxed">
              باستخدامك لمنصة <strong className="text-white/80">درسك AI</strong> (&ldquo;المنصة&rdquo;)، فإنك توافق على الالتزام بشروط الخدمة هذه (&ldquo;الشروط&rdquo;). 
              إذا كنت لا توافق على هذه الشروط، يرجى عدم استخدام المنصة. تحتفظ المنصة بالحق في تحديث هذه الشروط 
              في أي وقت، وتصبح التحديثات سارية بعد 30 يوماً من الإشعار.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">2. تعريفات</h2>
            <ul className="list-disc pl-6 space-y-2 text-white/60">
              <li><strong className="text-white/80">المنصة:</strong> موقع درسك AI الإلكتروني وتطبيقات الهاتف والحاسوب وجميع الخدمات المرتبطة بها.</li>
              <li><strong className="text-white/80">المستخدم / المعلم:</strong> الشخص الطبيعي أو الاعتباري المسجل في المنصة لإدارة العملية التعليمية.</li>
              <li><strong className="text-white/80">الطالب:</strong> الشخص الذي تتم إدارة بياناته التعليمية عبر المنصة بواسطة المعلم.</li>
              <li><strong className="text-white/80">الخدمات:</strong> جميع الميزات والأدوات المتاحة عبر المنصة، بما في ذلك على سبيل المثال لا الحصر: إدارة الطلاب، الحضور، الدرجات، الفواتير، التحليلات، الذكاء الاصطناعي.</li>
              <li><strong className="text-white/80">المحتوى:</strong> جميع البيانات والمعلومات والملفات والصور التي يرفعها المستخدم إلى المنصة.</li>
            </ul>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">3. التسجيل والحسابات</h2>
            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">3.1 إنشاء الحساب</h3>
            <p className="text-white/60 leading-relaxed">
              يجب أن تكون معلمًا أو مسؤولاً تعليمياً معتمداً لإنشاء حساب. يقر المستخدم بأن جميع المعلومات المقدمة 
              أثناء التسجيل صحيحة وكاملة، ويتعهد بتحديثها عند الضرورة.
            </p>

            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">3.2 أمان الحساب</h3>
            <p className="text-white/60 leading-relaxed">
              أنت المسؤول الوحيد عن الحفاظ على سرية كلمة المرور وحسابك. أي نشاط يحدث عبر حسابك هو مسؤوليتك. 
              يجب إبلاغنا فوراً عن أي استخدام غير مصرح به لحسابك.
            </p>

            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">3.3 حساب واحد لكل معلم</h3>
            <p className="text-white/60 leading-relaxed">
              لا يسمح بإنشاء حسابات متعددة. الحسابات الجماعية (مدرسة كاملة بحساب واحد) تتطلب باقة مؤسسية منفصلة.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">4. الاشتراكات والدفع</h2>
            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">4.1 الباقات</h3>
            <p className="text-white/60 leading-relaxed">
              تتوفر الباقات كما هو موضح في صفحة التسعير. جميع الأسعار شاملة للضرائب ما لم يذكر خلاف ذلك.
            </p>

            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">4.2 الدفع</h3>
            <p className="text-white/60 leading-relaxed">
              يتم الدفع مقدماً عبر الوسائل المتاحة (فودافون كاش، بطاقات ائتمان، إلخ). الاشتراك يتجدد تلقائياً 
              ما لم يتم إلغاؤه قبل 24 ساعة من تاريخ التجديد.
            </p>

            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">4.3 الإلغاء والاسترداد</h3>
            <p className="text-white/60 leading-relaxed">
              يمكنك إلغاء اشتراكك في أي وقت. لا نقدم استرداداً للفترة المتبقية من الاشتراك الشهري، 
              ما لم يكن هناك خطأ من جانبنا. للاشتراكات السنوية، يتم الاسترداد بشكل تناسبي.
            </p>

            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">4.4 أكواد التفعيل</h3>
            <p className="text-white/60 leading-relaxed">
              أكواد التفعيل المشتراة عبر فودافون كاش صالحة للاستخدام مرة واحدة. يستخدم الكود لتفعيل اشتراك 
              لمدة شهر واحد. الأكواد غير قابلة للاسترداد بعد إرسالها.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">5. استخدام الذكاء الاصطناعي</h2>
            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">5.1 حدود الاستخدام</h3>
            <p className="text-white/60 leading-relaxed">
              تشمل كل باقة عدداً محدوداً من طلبات الذكاء الاصطناعي شهرياً. يتم إعادة تعيين العداد في بداية 
              كل شهر. الطلبات غير المستخدمة لا تتراكم للشهر التالي.
            </p>

            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">5.2 جودة المخرجات</h3>
            <p className="text-white/60 leading-relaxed">
              مخرجات الذكاء الاصطناعي هي لأغراض مساعدة فقط. يتحمل المعلم المسؤولية الكاملة عن مراجعة 
              وتدقيق أي محتوى يتم إنشاؤه بواسطة AI قبل استخدامه مع الطلاب.
            </p>

            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">5.3 الشفافية</h3>
            <p className="text-white/60 leading-relaxed">
              نستخدم مزيجاً من نماذج الذكاء الاصطناعي المتعددة. لا نشارك بيانات طلابك مع مزودي AI 
              لأغراض تدريب النماذج.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">6. التزامات المستخدم</h2>
            <p className="text-white/60 leading-relaxed">باستخدام المنصة، تتعهد بما يلي:</p>
            <ul className="list-disc pl-6 space-y-2 text-white/60">
              <li>عدم استخدام المنصة لأي غرض غير قانوني.</li>
              <li>عدم محاولة اختراق أمن المنصة أو تجاوز إجراءات الحماية.</li>
              <li>عدم رفع محتوى مسيء أو مخالف للقانون.</li>
              <li>احترام حقوق الملكية الفكرية للآخرين.</li>
              <li>عدم مشاركة حسابك مع أشخاص آخرين.</li>
              <li>عدم استخدام المنصة بطريقة قد تضر بسمعتها أو أدائها.</li>
            </ul>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">7. الملكية الفكرية</h2>
            <p className="text-white/60 leading-relaxed">
              جميع الحقوق والملكية الفكرية للمنصة (الكود، التصميم، العلامات التجارية، المحتوى التسويقي) 
              مملوكة لشركة درسك AI. يمنحك استخدام المنصة ترخيصاً شخصياً غير حصري لاستخدام الخدمات.
            </p>
            <p className="text-white/60 leading-relaxed">
              البيانات التي تدخلها (بيانات طلابك، درجاتهم، محتوى الامتحانات) مملوكة لك. نحن لا نمتلك 
              هذه البيانات ولا نستخدمها لأغراضنا الخاصة.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">8. إخلاء المسؤولية</h2>
            <p className="text-white/60 leading-relaxed">
              يتم تقديم المنصة &ldquo;كما هي&rdquo; دون أي ضمانات، صريحة أو ضمنية. لا نضمن أن المنصة ستكون خالية 
              من الأخطاء أو متاحة بدون انقطاع. نحن لسنا مسؤولين عن أي أضرار غير مباشرة ناتجة عن استخدام المنصة.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">9. تحديد المسؤولية</h2>
            <p className="text-white/60 leading-relaxed">
              في أي حالة، لن تتجاوز مسؤولية درسك AI إجمالي المبلغ المدفوع من قبلك خلال الـ 12 شهراً الماضية. 
              لا تشمل القيود المسؤولية الناتجة عن الإهمال الجسيم أو الاحتيال.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">10. إنهاء الخدمة</h2>
            <p className="text-white/60 leading-relaxed">
              يحق لنا تعليق أو إنهاء حسابك في حالة انتهاكك لشروط الخدمة. في حالة الإنهاء بسبب الانتهاك، 
              لا يتم استرداد أي رسوم.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">11. تعديل الشروط</h2>
            <p className="text-white/60 leading-relaxed">
              قد نقوم بتعديل هذه الشروط من وقت لآخر. سنخطر المستخدمين المسجلين بالتغييرات الجوهرية 
              عبر البريد الإلكتروني قبل 30 يوماً.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">12. القانون الحاكم</h2>
            <p className="text-white/60 leading-relaxed">
              تخضع هذه الشروط للقوانين المصرية. يتم حل النزاعات المتعلقة بهذه الشروط عن طريق التحكيم 
              في القاهرة، مصر.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">13. اتصل بنا</h2>
            <p className="text-white/60 leading-relaxed">
              لأي استفسارات حول شروط الخدمة:<br />
              البريد الإلكتروني: <a href="mailto:legal@darsak.ai" className="text-indigo-400 hover:text-indigo-300 underline">legal@darsak.ai</a><br />
              أو من خلال صفحة <a href="/contact" className="text-indigo-400 hover:text-indigo-300 underline">اتصل بنا</a>.
            </p>
          </motion.div>
        </div>
      </div>
    </div>
  )
}
