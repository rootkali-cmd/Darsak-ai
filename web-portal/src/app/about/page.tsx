'use client'

import Image from 'next/image'
import Link from 'next/link'

export default function AboutPage() {
  return (
    <div className="min-h-screen bg-black text-white/70">
      <div className="max-w-3xl mx-auto px-4 py-20">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/40 hover:text-white/70 transition-colors mb-10">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
          الرئيسية
        </Link>

        <div className="flex items-center gap-3 mb-8">
          <Image src="/icon.png" alt="DarsakAI" width={40} height={40} className="rounded-xl" style={{ width: 40, height: 40 }} />
          <h1 className="text-3xl font-black text-white">من نحن</h1>
        </div>

        <div className="space-y-8 text-sm leading-relaxed">
          <section>
            <h2 className="text-lg font-bold text-white mb-3">قصتنا</h2>
            <p>DarsakAI بدأت من فكرة بسيطة: المدارس والسنترات في مصر بتعاني من إدارتها يدوياً — سجلات الحضور الورقية، الامتحانات المطبوعة، التصحيح بالأيدي، والفواتير المبعثرة.</p>
            <p className="mt-3">قرّرنا نبني منصة تعليمية ذكية بالذكاء الاصطناعي تجمع كل حاجة في مكان واحد — من إدارة الطلاب لحد تصحيح الامتحانات وتحليل الأداء.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">رؤيتنا</h2>
            <p>أن نكون المنصة التعليمية الأولى في مصر والعالم العربي — منصة تجعل إدارة أي سنتر أو مدرسة سهلة وسريعة وذكية.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">مهمتنا</h2>
            <ul className="list-disc list-inside space-y-2 text-white/60">
              <li>تبسيط إدارة المدارس والسنترات بأدوات ذكية.</li>
              <li>توفير الوقت والجهد على المدرسين والإداريين.</li>
              <li>تحسين نتائج الطلاب بالتحليلات والتقارير الذكية.</li>
              <li>تقديم تجربة مستخدم سلسة وعربية بالكامل.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">ليه DarsakAI؟</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-4">
              {[
                { n: '+50', l: 'مدرس نشط' },
                { n: '+500', l: 'طالب مسجل' },
                { n: '98%', l: 'نسبة الرضا' },
                { n: '24/7', l: 'دعم فني' },
              ].map((s) => (
                <div key={s.l} className="p-4 rounded-xl border border-white/[0.06] bg-white/[0.02] text-center">
                  <div className="text-2xl font-black text-white" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{s.n}</div>
                  <div className="text-xs text-white/40 mt-1">{s.l}</div>
                </div>
              ))}
            </div>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">فريق العمل</h2>
            <p>فريق صغير لكن شغوف بالتعليم والتقنية. نعمل كل يوم عشان نقدّم أفضل تجربة ممكنة للمدرس والطالب.</p>
          </section>

          <section>
            <h2 className="text-lg font-bold text-white mb-3">تواصل معنا</h2>
            <p>عندك سؤال أو اقتراح؟ تواصل معنا:</p>
            <div className="mt-3 space-y-1">
              <p className="text-white/50">support@darsakai.com</p>
              <p className="text-white/50">واتساب: 01055359719</p>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}
