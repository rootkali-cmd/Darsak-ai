'use client'

import Image from 'next/image'
import Link from 'next/link'

export default function ContactPage() {
  return (
    <div className="min-h-screen bg-black text-white/70">
      <div className="max-w-3xl mx-auto px-4 py-20">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/40 hover:text-white/70 transition-colors mb-10">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
          الرئيسية
        </Link>

        <div className="flex items-center gap-3 mb-8">
          <Image src="/icon.png" alt="DarsakAI" width={40} height={40} className="rounded-xl" style={{ width: 40, height: 40 }} />
          <h1 className="text-3xl font-black text-white">تواصل معنا</h1>
        </div>
        <p className="text-sm text-white/40 mb-12">يسعدنا تواصلك معنا — اختار الطريقة اللي تناسبك</p>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
          <a href="https://wa.me/201055359719" target="_blank" rel="noopener noreferrer" className="group p-6 rounded-2xl border border-white/[0.06] hover:border-[#25D366]/40 hover:bg-[#25D366]/[0.04] transition-all duration-300">
            <div className="w-12 h-12 rounded-xl bg-[#25D366]/10 flex items-center justify-center mb-4">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="#25D366"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
            </div>
            <h3 className="text-base font-bold text-white mb-1">واتساب</h3>
            <p className="text-sm text-white/40">01055359719</p>
            <p className="text-xs text-[#25D366] mt-2 opacity-0 group-hover:opacity-100 transition-opacity">ارسال رسالة ←</p>
          </a>

          <a href="mailto:support@darsakai.com" className="group p-6 rounded-2xl border border-white/[0.06] hover:border-blue-400/40 hover:bg-blue-400/[0.04] transition-all duration-300">
            <div className="w-12 h-12 rounded-xl bg-blue-400/10 flex items-center justify-center mb-4">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#60A5FA" strokeWidth="1.5"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
            </div>
            <h3 className="text-base font-bold text-white mb-1">البريد الإلكتروني</h3>
            <p className="text-sm text-white/40">support@darsakai.com</p>
            <p className="text-xs text-blue-400 mt-2 opacity-0 group-hover:opacity-100 transition-opacity">إرسال إيميل ←</p>
          </a>

          <div className="p-6 rounded-2xl border border-white/[0.06]">
            <div className="w-12 h-12 rounded-xl bg-white/[0.04] flex items-center justify-center mb-4">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.4)" strokeWidth="1.5"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
            </div>
            <h3 className="text-base font-bold text-white mb-1">الموقع</h3>
            <p className="text-sm text-white/40">مصر — القاهرة</p>
          </div>

          <div className="p-6 rounded-2xl border border-white/[0.06]">
            <div className="w-12 h-12 rounded-xl bg-white/[0.04] flex items-center justify-center mb-4">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.4)" strokeWidth="1.5"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
            </div>
            <h3 className="text-base font-bold text-white mb-1">ساعات العمل</h3>
            <p className="text-sm text-white/40">من السبت للخميس — 9 صباحاً حتى 10 مساءً</p>
          </div>
        </div>

        <div className="mt-12 p-6 rounded-2xl border border-white/[0.06] bg-white/[0.02]">
          <h3 className="text-base font-bold text-white mb-2">للشراكات والتعاون</h3>
          <p className="text-sm text-white/40">لو مهتم بالشراكة مع DarsakAI أو عندك اقتراح للتعاون، تواصل معنا عبر البريد الإلكتروني أو الواتساب وهرد عليك خلال 24 ساعة.</p>
        </div>
      </div>
    </div>
  )
}
