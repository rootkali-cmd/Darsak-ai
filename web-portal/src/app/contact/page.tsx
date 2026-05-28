'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Send, Mail, Phone, MapPin, Clock, Loader2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function ContactPage() {
  const [form, setForm] = useState({ name: '', email: '', subject: '', message: '' })
  const [sending, setSending] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSending(true)
    // Simulate send
    await new Promise(r => setTimeout(r, 1000))
    toast.success('تم إرسال رسالتك بنجاح! سنتواصل معك قريباً.')
    setForm({ name: '', email: '', subject: '', message: '' })
    setSending(false)
  }

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
        <div className="max-w-5xl mx-auto">
          <motion.div className="text-center mb-12" initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }}>
            <h1 className="text-3xl font-black mb-2">اتصل بنا</h1>
            <p className="text-[var(--text-muted)]">نحن هنا لمساعدتك. اختر الطريقة الأنسب لك.</p>
          </motion.div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-12">
            {[
              { icon: Mail, title: 'البريد الإلكتروني', desc: 'support@darsak.ai', sub: 'نرد خلال 24 ساعة' },
              { icon: Phone, title: 'الهاتف', desc: '+20 100 123 4567', sub: 'من 9 صباحاً إلى 6 مساءً' },
              { icon: MapPin, title: 'الموقع', desc: 'القاهرة، مصر', sub: 'مكتبنا الرئيسي' },
            ].map((item, i) => {
              const Icon = item.icon
              return (
                <motion.div key={item.title} className="card card-hover p-6 text-center" initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.1 }}>
                  <Icon size={28} className="mx-auto mb-3 text-[var(--accent)]" />
                  <h3 className="font-bold mb-1">{item.title}</h3>
                  <p className="text-sm text-[var(--text-secondary)]">{item.desc}</p>
                  <p className="text-xs text-[var(--text-muted)] mt-1">{item.sub}</p>
                </motion.div>
              )
            })}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <motion.div className="card p-8" initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.2 }}>
              <h2 className="text-xl font-bold mb-6">أرسل لنا رسالة</h2>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs text-[var(--text-muted)] mb-1.5">الاسم الكامل *</label>
                    <input className="input" required value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="أحمد محمد" />
                  </div>
                  <div>
                    <label className="block text-xs text-[var(--text-muted)] mb-1.5">البريد الإلكتروني *</label>
                    <input className="input" type="email" required dir="ltr" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} placeholder="teacher@darsak.ai" />
                  </div>
                </div>
                <div>
                  <label className="block text-xs text-[var(--text-muted)] mb-1.5">الموضوع</label>
                  <input className="input" value={form.subject} onChange={e => setForm({ ...form, subject: e.target.value })} placeholder="استفسار عن الباقات" />
                </div>
                <div>
                  <label className="block text-xs text-[var(--text-muted)] mb-1.5">الرسالة *</label>
                  <textarea className="input min-h-[120px] resize-y" required value={form.message} onChange={e => setForm({ ...form, message: e.target.value })} placeholder="اكتب رسالتك هنا..." />
                </div>
                <button type="submit" disabled={sending} className="btn btn-primary w-full justify-center py-3">
                  {sending ? <><Loader2 size={16} className="animate-spin" /> جاري الإرسال...</> : <><Send size={16} /> إرسال الرسالة</>}
                </button>
              </form>
            </motion.div>

            <motion.div className="card p-8" initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.3 }}>
              <h2 className="text-xl font-bold mb-6">معلومات الاتصال</h2>
              <div className="space-y-5">
                {[
                  { icon: Mail, label: 'دعم فني', val: 'support@darsak.ai' },
                  { icon: Mail, label: 'مبيعات', val: 'sales@darsak.ai' },
                  { icon: Mail, label: 'شؤون قانونية', val: 'legal@darsak.ai' },
                  { icon: Clock, label: 'أوقات العمل', val: 'السبت - الخميس، 9:00 ص - 6:00 م' },
                ].map((item, i) => {
                  const Icon = item.icon
                  return (
                    <div key={item.label} className="flex items-center gap-3">
                      <Icon size={18} className="text-[var(--accent)] flex-shrink-0" />
                      <div>
                        <p className="text-xs text-[var(--text-muted)]">{item.label}</p>
                        <p className="text-sm font-medium">{item.val}</p>
                      </div>
                    </div>
                  )
                })}
              </div>
              <div className="divider" />
              <p className="text-sm text-[var(--text-secondary)] leading-relaxed">
                نرد على جميع الاستفسارات خلال 24 ساعة عمل. للاستفسارات العاجلة، 
                يرجى استخدام البريد الإلكتروني للدعم الفني مع وضع كلمة "عاجل" في الموضوع.
              </p>
            </motion.div>
          </div>
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
