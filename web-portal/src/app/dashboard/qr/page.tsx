'use client'

import { motion } from 'framer-motion'
import { useQuery } from '@tanstack/react-query'
import { useState, useEffect, useRef } from 'react'
import { QrCode, Download, Loader2, Sparkles } from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section } from '@/components/ui'
import { qrApi, authApi } from '@/lib/api'

export default function QRPage() {
  const [qrData, setQrData] = useState<any>(null)
  const [isLoading, setIsLoading] = useState(true)
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    authApi.getMe()
      .then((res) => qrApi.generate(res.data.id))
      .then((res) => setQrData(res.data))
      .catch((err) => {
        const msg = err?.response?.data?.detail
        if (msg) toast.error(msg)
        else toast.error('فشل تحميل QR Code')
      })
      .finally(() => setIsLoading(false))
  }, [])

  useEffect(() => {
    if (qrData?.qr_base64 && canvasRef.current) {
      const img = new Image()
      img.onload = () => { const canvas = canvasRef.current!; const ctx = canvas.getContext('2d')!; canvas.width = img.width; canvas.height = img.height; ctx.drawImage(img, 0, 0) }
      img.src = `data:image/png;base64,${qrData.qr_base64}`
    }
  }, [qrData])

  const handleDownload = () => {
    if (canvasRef.current) {
      const link = document.createElement('a')
      link.download = `qr_${qrData?.teacher_code}.png`
      link.href = canvasRef.current.toDataURL()
      link.click()
      toast.success('تم تحميل QR Code ')
    }
  }

  return (
    <div className="space-y-6">
      <Section>
        <h1 className="text-3xl font-bold">QR Code</h1>
        <p className="text-text-secondary mt-1">كود QR الخاص بك لتسجيل حضور الطلاب</p>
      </Section>

      {isLoading ? (
        <div className="flex justify-center py-24"><Loader2 className="w-12 h-12 animate-spin text-primary" /></div>
      ) : qrData ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Section>
            <GlassCard className="flex flex-col items-center">
              <div className="relative">
                <div className="bg-white p-6 rounded-2xl shadow-[0_0_40px_rgba(139,92,246,0.3)]">
                  <canvas ref={canvasRef} className="w-64 h-64" />
                </div>
              </div>
              <div className="mt-6 text-center">
                <p className="text-lg font-bold">{qrData.teacher_code}</p>
                <p className="text-text-muted text-sm">شارك هذا الكود مع طلابك</p>
              </div>
              <NeonButton onClick={handleDownload} className="mt-4">
                <Download className="w-5 h-5" />
                تحميل QR Code
              </NeonButton>
            </GlassCard>
          </Section>

          <Section delay={0.2}>
            <GlassCard>
              <h2 className="text-xl font-bold mb-4 flex items-center gap-2">
                <QrCode className="w-6 h-6 text-primary" />
                كيفية الاستخدام
              </h2>
              <div className="space-y-4">
                {[
                  { step: '1', title: 'شارك الكود', desc: 'أعرض QR Code للطلاب أو اطبعه' },
                  { step: '2', title: 'مسح الكود', desc: 'الطلاب يمسحون الكود من تطبيق الموبايل' },
                  { step: '3', title: 'تسجيل تلقائي', desc: 'يتم تسجيل الحضور تلقائياً في النظام' },
                ].map((item, index) => (
                  <motion.div key={item.step} initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.3 + index * 0.1 }} className="flex items-start gap-4 p-4 rounded-xl bg-bg-secondary/50 border border-white/5">
                    <div className="w-8 h-8 rounded-full bg-neon-gradient flex items-center justify-center flex-shrink-0">
                      <span className="text-white font-bold">{item.step}</span>
                    </div>
                    <div>
                      <h3 className="font-bold">{item.title}</h3>
                      <p className="text-sm text-text-muted">{item.desc}</p>
                    </div>
                  </motion.div>
                ))}
              </div>
            </GlassCard>
          </Section>
        </div>
      ) : (
        <Section><GlassCard className="text-center py-12"><p className="text-text-muted">فشل تحميل QR Code</p></GlassCard></Section>
      )}
    </div>
  )
}
