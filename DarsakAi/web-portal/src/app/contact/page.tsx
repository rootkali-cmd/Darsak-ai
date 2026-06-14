'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Send, Mail, Phone, Clock, Loader2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function ContactPage() {
  const [form, setForm] = useState({ name: '', email: '', subject: '', message: '' })
  const [sending, setSending] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSending(true)
    await new Promise(r => setTimeout(r, 1000))
    toast.success('تم إرسال رسالتك بنجاح! سنتواصل معك قريباً.')
    setForm({ name: '', email: '', subject: '', message: '' })
    setSending(false)
  }

  const inputClass =
    'w-full bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 px-4 py-2.5 outline-none focus:border-indigo-500 transition-colors'

  return (
    <div
      className="min-h-screen relative"
      style={{ background: 'linear-gradient(180deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)' }}
    >
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-indigo-500/5 rounded-full blur-3xl" />
      </div>

      <header
        className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 md:px-10 py-4"
        style={{ background: 'rgba(15, 23, 42, 0.8)', backdropFilter: 'blur(12px)', borderBottom: '1px solid rgba(255,255,255,0.08)' }}
      >
        <div className="flex items-center gap-2">
          <span className="text-lg text-indigo-400">◈</span>
          <span
            className="font-bold tracking-widest text-sm text-white"
            style={{ fontFamily: "'JetBrains Mono', monospace" }}
          >
            DARSAK AI
          </span>
        </div>
        <nav className="flex items-center gap-4 md:gap-6">
          <a href="/" className="text-sm text-slate-400 hover:text-white transition-colors">الرئيسية</a>
        </nav>
      </header>

      <main className="pt-24 pb-16 px-6 relative">
        <div className="max-w-5xl mx-auto">
          <motion.div
            className="text-center mb-12"
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
          >
            <h1 className="text-3xl font-black mb-2 text-white">اتصل بنا</h1>
            <p className="text-slate-400">نحن هنا لمساعدتك. اختر الطريقة الأنسب لك.</p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
            {[
              {
                icon: Mail,
                title: 'البريد الإلكتروني',
                desc: 'support@darsak.ai',
                sub: 'نرد خلال 24 ساعة',
              },
              {
                icon: Phone,
                title: 'الهاتف',
                desc: '+20 100 123 4567',
                sub: 'من 9 صباحاً إلى 6 مساءً',
              },
              {
                icon: 'whatsapp',
                title: 'واتساب',
                desc: '+20 100 123 4567',
                sub: 'دردشة سريعة',
              },
            ].map((item, i) => {
              const Icon = item.icon as any
              return (
                <motion.div
                  key={item.title}
                  className="bg-white/[0.03] border border-white/[0.08] rounded-2xl p-6 text-center backdrop-blur-sm hover:bg-white/[0.05] hover:border-indigo-500/30 transition-all duration-300"
                  initial={{ opacity: 0, y: 15 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.1 }}
                >
                  <div className="w-12 h-12 rounded-xl bg-indigo-500/10 flex items-center justify-center mx-auto mb-4">
                    {item.icon === 'whatsapp' ? (
                      <svg viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6 text-indigo-400">
                        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413z" />
                      </svg>
                    ) : (
                      <Icon size={24} className="text-indigo-400" />
                    )}
                  </div>
                  <h3 className="font-bold text-white mb-1">{item.title}</h3>
                  <p className="text-sm text-slate-300">{item.desc}</p>
                  <p className="text-xs text-slate-500 mt-1">{item.sub}</p>
                </motion.div>
              )
            })}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <motion.div
              className="bg-white/[0.03] border border-white/[0.08] rounded-2xl p-8 backdrop-blur-sm"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.2 }}
            >
              <h2 className="text-xl font-bold mb-6 text-white">أرسل لنا رسالة</h2>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs text-slate-400 mb-1.5">الاسم الكامل *</label>
                    <input
                      className={inputClass}
                      required
                      value={form.name}
                      onChange={e => setForm({ ...form, name: e.target.value })}
                      placeholder="أحمد محمد"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1.5">البريد الإلكتروني *</label>
                    <input
                      className={inputClass}
                      type="email"
                      required
                      dir="ltr"
                      value={form.email}
                      onChange={e => setForm({ ...form, email: e.target.value })}
                      placeholder="teacher@darsak.ai"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-xs text-slate-400 mb-1.5">الموضوع</label>
                  <input
                    className={inputClass}
                    value={form.subject}
                    onChange={e => setForm({ ...form, subject: e.target.value })}
                    placeholder="استفسار عن الباقات"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-400 mb-1.5">الرسالة *</label>
                  <textarea
                    className={`${inputClass} min-h-[120px] resize-y`}
                    required
                    value={form.message}
                    onChange={e => setForm({ ...form, message: e.target.value })}
                    placeholder="اكتب رسالتك هنا..."
                  />
                </div>
                <button
                  type="submit"
                  disabled={sending}
                  className="w-full py-3 rounded-xl font-medium text-white bg-indigo-500 hover:bg-indigo-400 disabled:opacity-60 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2"
                >
                  {sending ? <><Loader2 size={16} className="animate-spin" /> جاري الإرسال...</> : <><Send size={16} /> إرسال الرسالة</>}
                </button>
              </form>
            </motion.div>

            <motion.div
              className="bg-white/[0.03] border border-white/[0.08] rounded-2xl p-8 backdrop-blur-sm"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.3 }}
            >
              <h2 className="text-xl font-bold mb-6 text-white">معلومات الاتصال</h2>
              <div className="space-y-5">
                {[
                  { icon: Mail, label: 'دعم فني', val: 'support@darsak.ai' },
                  { icon: Mail, label: 'مبيعات', val: 'sales@darsak.ai' },
                  { icon: Mail, label: 'شؤون قانونية', val: 'legal@darsak.ai' },
                  { icon: Clock, label: 'أوقات العمل', val: 'السبت - الخميس، 9:00 ص - 6:00 م' },
                ].map((item) => {
                  const Icon = item.icon
                  return (
                    <div key={item.label} className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-lg bg-indigo-500/10 flex items-center justify-center flex-shrink-0">
                        <Icon size={16} className="text-indigo-400" />
                      </div>
                      <div>
                        <p className="text-xs text-slate-500">{item.label}</p>
                        <p className="text-sm font-medium text-slate-200">{item.val}</p>
                      </div>
                    </div>
                  )
                })}
              </div>
              <div className="my-6 border-t border-white/[0.08]" />
              <p className="text-sm text-slate-400 leading-relaxed">
                نرد على جميع الاستفسارات خلال 24 ساعة عمل. للاستفسارات العاجلة، 
                يرجى استخدام البريد الإلكتروني للدعم الفني مع وضع كلمة &ldquo;عاجل&rdquo; في الموضوع.
              </p>
            </motion.div>
          </div>
        </div>
      </main>

      <footer className="relative border-t py-6 px-6" style={{ borderColor: 'rgba(255,255,255,0.08)' }}>
        <div className="max-w-5xl mx-auto flex flex-col md:flex-row justify-between items-center gap-4 text-sm text-slate-500">
          <span>© 2026 DARSAK AI. جميع الحقوق محفوظة.</span>
          <div className="flex gap-4">
            <a href="/about" className="hover:text-slate-300 transition-colors">من نحن</a>
            <a href="/privacy" className="hover:text-slate-300 transition-colors">سياسة الخصوصية</a>
            <a href="/terms" className="hover:text-slate-300 transition-colors">شروط الخدمة</a>
            <a href="/contact" className="hover:text-slate-300 transition-colors">اتصل بنا</a>
            <a href="/faq" className="hover:text-slate-300 transition-colors">الأسئلة الشائعة</a>
          </div>
        </div>
      </footer>
    </div>
  )
}
