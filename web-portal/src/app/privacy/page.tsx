'use client'

import { motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import { Shield } from 'lucide-react'

export default function PrivacyPage() {
  const router = useRouter()

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
          <motion.div className="text-center mb-10" initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }}>
            <Shield size={36} className="mx-auto mb-4 text-[var(--accent)]" />
            <h1 className="text-3xl font-black mb-2">سياسة الخصوصية</h1>
            <p className="text-sm text-[var(--text-muted)]">آخر تحديث: 15 مايو 2026</p>
          </motion.div>

          <motion.div className="prose" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.2 }}>
            <h2>مقدمة</h2>
            <p>
              نحن في <strong>درسك AI</strong> ("نحن" أو "المنصة") نلتزم بحماية خصوصية المستخدمين ("المستخدم" أو "المعلم" أو "الطالب" أو "أنت"). 
              توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية المعلومات الشخصية التي تقدمها عند استخدام منصتنا.
            </p>
            <p>
              باستخدامك للمنصة، فإنك توافق على جمع واستخدام المعلومات وفقاً لهذه السياسة. إذا كنت لا توافق، يرجى عدم استخدام المنصة.
            </p>

            <h2>المعلومات التي نجمعها</h2>
            <h3>1. المعلومات التي تقدمها طواعية</h3>
            <ul>
              <li><strong>معلومات الحساب:</strong> الاسم الكامل، البريد الإلكتروني، رقم الهاتف، كلمة المرور (مشفرة).</li>
              <li><strong>معلومات الطلاب:</strong> الأسماء، الأكواد، أرقام الهواتف، بيانات أولياء الأمور، الصفوف الدراسية.</li>
              <li><strong>معلومات المجموعات:</strong> أسماء المجموعات، المواد، المواعيد، مستويات الطلاب.</li>
              <li><strong>بيانات الأداء:</strong> درجات الامتحانات، الحضور والغياب، الملاحظات، التقارير.</li>
              <li><strong>معلومات الدفع:</strong> بيانات الفواتير، سجل المدفوعات (يتم معالجتها عبر مزود دفع آمن، ولا نخزن معلومات البطاقة).</li>
            </ul>

            <h3>2. المعلومات التي نجمعها تلقائياً</h3>
            <ul>
              <li><strong>بيانات الاستخدام:</strong> الصفحات التي تزورها، الميزات التي تستخدمها، مدة الجلسة.</li>
              <li><strong>معلومات الجهاز:</strong> نوع الجهاز، نظام التشغيل، إصدار التطبيق، المعرفات الفريدة.</li>
              <li><strong>بيانات الأعطال:</strong> تقارير الأعطال الفنية لتحسين أداء التطبيق.</li>
              <li><strong>بيانات التحديثات:</strong> إصدار التطبيق الحالي، حالة التحديثات، قناة التحديث.</li>
            </ul>

            <h2>كيف نستخدم معلوماتك</h2>
            <p>نستخدم المعلومات التي نجمعها للأغراض التالية:</p>
            <ul>
              <li>تشغيل وصيانة المنصة وتقديم الخدمات المطلوبة.</li>
              <li>تحسين وتطوير الميزات بناءً على أنماط الاستخدام.</li>
              <li>إرسال الإشعارات المهمة (تحديثات، تغييرات في السياسة).</li>
              <li>معالجة المدفوعات وإدارة الاشتراكات.</li>
              <li>تحليل الأداء التربوي للطلاب وتقديم التقارير.</li>
              <li>الكشف عن الأنشطة غير القانونية ومنع إساءة الاستخدام.</li>
            </ul>

            <h2>حماية البيانات</h2>
            <p>نتخذ إجراءات أمنية مشددة لحماية بياناتك:</p>
            <ul>
              <li>تشفير جميع البيانات أثناء النقل (TLS 1.3) وعند التخزين (AES-256).</li>
              <li>النسخ الاحتياطي اليومي للبيانات مع تخزينها في مراكز بيانات آمنة.</li>
              <li>صلاحيات صارمة للوصول إلى البيانات — فقط الموظفون المصرح لهم.</li>
              <li>مراجعات أمنية دورية واختبارات اختراق.</li>
            </ul>

            <h2>مشاركة البيانات مع أطراف ثالثة</h2>
            <p>نحن لا نبيع معلوماتك الشخصية. قد نشارك بياناتك في الحالات التالية:</p>
            <ul>
              <li><strong>مزودو الخدمة:</strong> شركات استضافة آمنة، مزودو الدفع، خدمات التحليلات (كلها ملزمة باتفاقيات سرية).</li>
              <li><strong>الامتثال القانوني:</strong> إذا طلب القانون ذلك أو لحماية حقوقنا القانونية.</li>
              <li><strong>بموافقتك:</strong> في أي حالة أخرى نطلب فيها موافقتك الصريحة.</li>
            </ul>

            <h2>الاحتفاظ بالبيانات</h2>
            <p>
              نحتفظ ببيانات حسابك طالما كان حسابك نشطاً. عند حذف حسابك، نحذف جميع بياناتك الشخصية 
              خلال 30 يوماً، مع الاحتفاظ بنسخ احتياطية لمدة 90 يوماً إضافية قبل المحو النهائي.
            </p>

            <h2>حقوقك</h2>
            <p>لديك الحق في:</p>
            <ul>
              <li>الوصول إلى بياناتك الشخصية التي نحتفظ بها.</li>
              <li>تصحيح أي بيانات غير دقيقة.</li>
              <li>حذف حسابك وبياناتك (من خلال الإعدادات أو بالتواصل معنا).</li>
              <li>تصدير بياناتك بصيغة قابلة للقراءة.</li>
              <li>الاعتراض على معالجة بياناتك لأغراض التسويق.</li>
            </ul>

            <h2>ملفات تعريف الارتباط (Cookies)</h2>
            <p>
              نستخدم ملفات تعريف الارتباط الضرورية لتشغيل المنصة (مثل الحفاظ على حالة تسجيل الدخول). 
              لا نستخدم ملفات تعريف الارتباط للتتبع الإعلاني. يمكنك ضبط إعدادات المتصفح لرفض cookies، 
              ولكن قد تؤثر بعض الميزات الأساسية.
            </p>

            <h2>أمن المعلومات</h2>
            <p>
              بينما نسعى لحماية معلوماتك الشخصية، لا توجد طريقة نقل عبر الإنترنت آمنة 100%. 
              نتخذ إجراءات معقولة تجارياً لحماية بياناتك، ولكن لا يمكننا ضمان الأمن المطلق.
            </p>

            <h2>تغييرات سياسة الخصوصية</h2>
            <p>
              قد نقوم بتحديث هذه السياسة من وقت لآخر. سنبلغك بالتغييرات الجوهرية عبر البريد الإلكتروني 
              أو من خلال إشعار على المنصة قبل 30 يوماً من التغيير.
            </p>

            <h2>اتصل بنا</h2>
            <p>
              إذا كانت لديك أي أسئلة أو استفسارات حول سياسة الخصوصية، يرجى التواصل معنا على:
            </p>
            <p>
              البريد الإلكتروني: <a href="mailto:privacy@darsak.ai" className="link">privacy@darsak.ai</a><br />
              أو من خلال صفحة <a href="/contact" className="link">اتصل بنا</a>.
            </p>
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
