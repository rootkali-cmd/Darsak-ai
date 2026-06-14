'use client'

import { motion } from 'framer-motion'
import { useState, useEffect, useRef } from 'react'
import { QrCode, Download, Loader2, Share2 } from 'lucide-react'
import toast from 'react-hot-toast'
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

  const handleShare = () => {
    if (qrData?.teacher_code) {
      navigator.clipboard.writeText(qrData.teacher_code)
      toast.success('تم نسخ الكود')
    }
  }

  const glassCard = 'bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl'
  const btnGradient = { background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      className="space-y-6"
    >
      <div>
        <h1 className="text-3xl font-bold text-white">QR Code</h1>
        <p className="text-slate-400 mt-1">كود QR الخاص بك لتسجيل حضور الطلاب</p>
      </div>

      {isLoading ? (
        <div className="flex justify-center py-24">
          <Loader2 className="w-12 h-12 animate-spin text-indigo-400" />
        </div>
      ) : qrData ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
          >
            <div className={`${glassCard} p-8 flex flex-col items-center`}>
              <div className="relative">
                <div
                  className="p-6 rounded-2xl"
                  style={{ boxShadow: '0 0 60px rgba(99, 102, 241, 0.2)' }}
                >
                  <div className="bg-white p-4 rounded-xl">
                    <canvas ref={canvasRef} className="w-64 h-64" />
                  </div>
                </div>
                <div className="absolute inset-0 rounded-2xl opacity-20 pointer-events-none"
                  style={{ background: 'radial-gradient(circle at center, rgba(99,102,241,0.5) 0%, transparent 70%)', filter: 'blur(20px)' }}
                />
              </div>
              <div className="mt-6 text-center">
                <p className="text-lg font-bold text-white">{qrData.teacher_code}</p>
                <p className="text-slate-400 text-sm">شارك هذا الكود مع طلابك</p>
              </div>
              <div className="flex gap-3 mt-6">
                <button
                  onClick={handleDownload}
                  className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl text-white font-semibold text-sm transition-all hover:opacity-90 active:scale-[0.97]"
                  style={btnGradient}
                >
                  <Download className="w-5 h-5" />
                  تحميل QR
                </button>
                <button
                  onClick={handleShare}
                  className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl text-slate-300 font-semibold text-sm border border-white/10 transition-all hover:border-white/20 hover:text-white active:scale-[0.97]"
                >
                  <Share2 className="w-5 h-5" />
                  مشاركة
                </button>
              </div>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
          >
            <div className={`${glassCard} p-6`}>
              <h2 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                <QrCode className="w-6 h-6 text-indigo-400" />
                كيفية الاستخدام
              </h2>
              <div className="space-y-4">
                {[
                  { step: '1', title: 'شارك الكود', desc: 'أعرض QR Code للطلاب أو اطبعه' },
                  { step: '2', title: 'مسح الكود', desc: 'الطلاب يمسحون الكود من تطبيق الموبايل' },
                  { step: '3', title: 'تسجيل تلقائي', desc: 'يتم تسجيل الحضور تلقائياً في النظام' },
                ].map((item, index) => (
                  <motion.div
                    key={item.step}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.3 + index * 0.1 }}
                    className="flex items-start gap-4 p-4 rounded-xl bg-white/[0.02] border border-white/[0.06]"
                  >
                    <div
                      className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
                      style={btnGradient}
                    >
                      <span className="text-white font-bold text-sm">{item.step}</span>
                    </div>
                    <div>
                      <h3 className="font-bold text-white">{item.title}</h3>
                      <p className="text-sm text-slate-400">{item.desc}</p>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
          </motion.div>
        </div>
      ) : (
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
        >
          <div className={`${glassCard} text-center py-12`}>
            <p className="text-slate-500">فشل تحميل QR Code</p>
          </div>
        </motion.div>
      )}
    </motion.div>
  )
}
