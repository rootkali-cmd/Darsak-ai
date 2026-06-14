'use client'

import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Shield } from 'lucide-react'

export default function PrivacyPage() {
  const router = useRouter()

  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(180deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)' }}>
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl" />
      </div>
      <div className="relative max-w-3xl mx-auto px-4 py-20">
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-8">
          <motion.div className="text-center mb-10" initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }}>
            <Shield size={36} className="mx-auto mb-4 text-indigo-400" />
            <h1 className="text-3xl font-black mb-2 text-white">سياسة الخصوصية</h1>
            <p className="text-sm text-white/50">آخر تحديث: 15 مايو 2026</p>
          </motion.div>

          <motion.div className="space-y-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.2 }}>
            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">مقدمة</h2>
            <p className="text-white/60 leading-relaxed">
              نحن في <strong className="text-white/80">درسك AI</strong> (&ldquo;نحن&rdquo; أو &ldquo;المنصة&rdquo;) نلتزم بحماية خصوصية المستخدمين (&ldquo;المستخدم&rdquo; أو &ldquo;المعلم&rdquo; أو &ldquo;الطالب&rdquo; أو &ldquo;أنت&rdquo;). 
              توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية المعلومات الشخصية التي تقدمها عند استخدام منصتنا.
            </p>
            <p className="text-white/60 leading-relaxed">
              باستخدامك للمنصة، فإنك توافق على جمع واستخدام المعلومات وفقاً لهذه السياسة. إذا كنت لا توافق، يرجى عدم استخدام المنصة.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">المعلومات التي نجمعها</h2>
            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">1. المعلومات التي تقدمها طواعية</h3>
            <ul className="list-disc pl-6 space-y-2 text-white/60">
              <li><strong className="text-white/80">معلومات الحساب:</strong> الاسم الكامل، البريد الإلكتروني، رقم الهاتف، كلمة المرور (مشفرة).</li>
              <li><strong className="text-white/80">معلومات الطلاب:</strong> الأسماء، الأكواد، أرقام الهواتف، بيانات أولياء الأمور، الصفوف الدراسية.</li>
              <li><strong className="text-white/80">معلومات المجموعات:</strong> أسماء المجموعات، المواد، المواعيد، مستويات الطلاب.</li>
              <li><strong className="text-white/80">بيانات الأداء:</strong> درجات الامتحانات، الحضور والغياب، الملاحظات، التقارير.</li>
              <li><strong className="text-white/80">معلومات الدفع:</strong> بيانات الفواتير، سجل المدفوعات (يتم معالجتها عبر مزود دفع آمن، ولا نخزن معلومات البطاقة).</li>
            </ul>

            <h3 className="text-white/90 text-lg font-semibold mt-6 mb-3">2. المعلومات التي نجمعها تلقائياً</h3>
            <ul className="list-disc pl-6 space-y-2 text-white/60">
              <li><strong className="text-white/80">بيانات الاستخدام:</strong> الصفحات التي تزورها، الميزات التي تستخدمها، مدة الجلسة.</li>
              <li><strong className="text-white/80">معلومات الجهاز:</strong> نوع الجهاز، نظام التشغيل، إصدار التطبيق، المعرفات الفريدة.</li>
              <li><strong className="text-white/80">بيانات الأعطال:</strong> تقارير الأعطال الفنية لتحسين أداء التطبيق.</li>
              <li><strong className="text-white/80">بيانات التحديثات:</strong> إصدار التطبيق الحالي، حالة التحديثات، قناة التحديث.</li>
            </ul>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">كيف نستخدم معلوماتك</h2>
            <p className="text-white/60 leading-relaxed">نستخدم المعلومات التي نجمعها للأغراض التالية:</p>
            <ul className="list-disc pl-6 space-y-2 text-white/60">
              <li>تشغيل وصيانة المنصة وتقديم الخدمات المطلوبة.</li>
              <li>تحسين وتطوير الميزات بناءً على أنماط الاستخدام.</li>
              <li>إرسال الإشعارات المهمة (تحديثات، تغييرات في السياسة).</li>
              <li>معالجة المدفوعات وإدارة الاشتراكات.</li>
              <li>تحليل الأداء التربوي للطلاب وتقديم التقارير.</li>
              <li>الكشف عن الأنشطة غير القانونية ومنع إساءة الاستخدام.</li>
            </ul>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">حماية البيانات</h2>
            <p className="text-white/60 leading-relaxed">نتخذ إجراءات أمنية مشددة لحماية بياناتك:</p>
            <ul className="list-disc pl-6 space-y-2 text-white/60">
              <li>تشفير جميع البيانات أثناء النقل (TLS 1.3) وعند التخزين (AES-256).</li>
              <li>النسخ الاحتياطي اليومي للبيانات مع تخزينها في مراكز بيانات آمنة.</li>
              <li>صلاحيات صارمة للوصول إلى البيانات — فقط الموظفون المصرح لهم.</li>
              <li>مراجعات أمنية دورية واختبارات اختراق.</li>
            </ul>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">مشاركة البيانات مع أطراف ثالثة</h2>
            <p className="text-white/60 leading-relaxed">نحن لا نبيع معلوماتك الشخصية. قد نشارك بياناتك في الحالات التالية:</p>
            <ul className="list-disc pl-6 space-y-2 text-white/60">
              <li><strong className="text-white/80">مزودو الخدمة:</strong> شركات استضافة آمنة، مزودو الدفع، خدمات التحليلات (كلها ملزمة باتفاقيات سرية).</li>
              <li><strong className="text-white/80">الامتثال القانوني:</strong> إذا طلب القانون ذلك أو لحماية حقوقنا القانونية.</li>
              <li><strong className="text-white/80">بموافقتك:</strong> في أي حالة أخرى نطلب فيها موافقتك الصريحة.</li>
            </ul>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">الاحتفاظ بالبيانات</h2>
            <p className="text-white/60 leading-relaxed">
              نحتفظ ببيانات حسابك طالما كان حسابك نشطاً. عند حذف حسابك، نحذف جميع بياناتك الشخصية 
              خلال 30 يوماً، مع الاحتفاظ بنسخ احتياطية لمدة 90 يوماً إضافية قبل المحو النهائي.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">حقوقك</h2>
            <p className="text-white/60 leading-relaxed">لديك الحق في:</p>
            <ul className="list-disc pl-6 space-y-2 text-white/60">
              <li>الوصول إلى بياناتك الشخصية التي نحتفظ بها.</li>
              <li>تصحيح أي بيانات غير دقيقة.</li>
              <li>حذف حسابك وبياناتك (من خلال الإعدادات أو بالتواصل معنا).</li>
              <li>تصدير بياناتك بصيغة قابلة للقراءة.</li>
              <li>الاعتراض على معالجة بياناتك لأغراض التسويق.</li>
            </ul>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">ملفات تعريف الارتباط (Cookies)</h2>
            <p className="text-white/60 leading-relaxed">
              نستخدم ملفات تعريف الارتباط الضرورية لتشغيل المنصة (مثل الحفاظ على حالة تسجيل الدخول). 
              لا نستخدم ملفات تعريف الارتباط للتتبع الإعلاني. يمكنك ضبط إعدادات المتصفح لرفض cookies، 
              ولكن قد تؤثر بعض الميزات الأساسية.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">أمن المعلومات</h2>
            <p className="text-white/60 leading-relaxed">
              بينما نسعى لحماية معلوماتك الشخصية، لا توجد طريقة نقل عبر الإنترنت آمنة 100%. 
              نتخذ إجراءات معقولة تجارياً لحماية بياناتك، ولكن لا يمكننا ضمان الأمن المطلق.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">تغييرات سياسة الخصوصية</h2>
            <p className="text-white/60 leading-relaxed">
              قد نقوم بتحديث هذه السياسة من وقت لآخر. سنبلغك بالتغييرات الجوهرية عبر البريد الإلكتروني 
              أو من خلال إشعار على المنصة قبل 30 يوماً من التغيير.
            </p>

            <h2 className="text-indigo-300 text-xl font-bold mt-8 mb-4">اتصل بنا</h2>
            <p className="text-white/60 leading-relaxed">
              إذا كانت لديك أي أسئلة أو استفسارات حول سياسة الخصوصية، يرجى التواصل معنا على:
            </p>
            <p className="text-white/60 leading-relaxed">
              البريد الإلكتروني: <a href="mailto:privacy@darsak.ai" className="text-indigo-400 hover:text-indigo-300 underline">privacy@darsak.ai</a><br />
              أو من خلال صفحة <a href="/contact" className="text-indigo-400 hover:text-indigo-300 underline">اتصل بنا</a>.
            </p>
          </motion.div>
        </div>
      </div>
    </div>
  )
}
