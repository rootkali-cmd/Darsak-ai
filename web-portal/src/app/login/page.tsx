'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { Eye, EyeOff, Loader2 } from 'lucide-react'
import { authApi } from '@/lib/api'
import { auth } from '@/lib/auth'

const loginSchema = z.object({
  email: z.string().email('البريد الإلكتروني غير صحيح'),
  password: z.string().min(6, 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
})

type LoginForm = z.infer<typeof loginSchema>

const inputClass =
  'w-full bg-white/[0.05] border border-white/[0.08] rounded-xl text-white placeholder:text-slate-500 px-4 py-2.5 outline-none focus:border-indigo-500 transition-colors'
const errorInputClass =
  'w-full bg-white/[0.05] border border-red-500/60 rounded-xl text-white placeholder:text-slate-500 px-4 py-2.5 outline-none focus:border-red-500 transition-colors'

export default function LoginPage() {
  const router = useRouter()
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
  })

  const onSubmit = async (data: LoginForm) => {
    setIsLoading(true)
    try {
      const response = await authApi.login(data.email, data.password)
      const { access_token, refresh_token } = response.data
      auth.setTokens(access_token, refresh_token)
      toast.success('تم تسجيل الدخول بنجاح')
      router.push('/dashboard')
    } catch (error: any) {
      console.error('[Login Error]', error)
      if (error.response) {
        console.error('[Login Error] Status:', error.response.status)
        console.error('[Login Error] Data:', error.response.data)
        console.error('[Login Error] URL:', error.config?.url)
        console.error('[Login Error] BaseURL:', error.config?.baseURL)
      } else if (error.request) {
        console.error('[Login Error] No response received. Request:', error.request)
      } else {
        console.error('[Login Error] Message:', error.message)
      }
      toast.error(error.response?.data?.detail || 'فشل تسجيل الدخول')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div
      className="min-h-screen relative flex items-center justify-center"
      style={{ background: 'linear-gradient(180deg, #0F172A 0%, #1E293B 50%, #0F172A 100%)' }}
    >
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-indigo-500/5 rounded-full blur-3xl" />
      </div>

      <button
        onClick={() => router.push('/')}
        className="fixed top-4 left-4 z-50 text-sm text-slate-400 hover:text-indigo-400 transition-colors"
      >
        ← العودة
      </button>

      <div className="relative max-w-md mx-auto px-4 py-20 w-full">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="w-full max-w-sm mx-auto"
        >
          <div className="bg-white/[0.03] border border-white/[0.08] rounded-2xl p-8 backdrop-blur-sm">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.2 }}
              className="text-center mb-8"
            >
              <h1
                className="text-2xl font-bold mb-1 text-white"
                style={{ fontFamily: "'JetBrains Mono', monospace" }}
              >
                DARSAK AI
              </h1>
              <p className="text-sm text-slate-400">تسجيل الدخول إلى لوحة التحكم</p>
            </motion.div>

            <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
              <motion.div
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.3 }}
              >
                <label className="block text-xs text-slate-400 mb-1.5">البريد الإلكتروني</label>
                <input
                  type="email"
                  dir="ltr"
                  {...register('email')}
                  className={errors.email ? errorInputClass : inputClass}
                  placeholder="teacher@darsak.ai"
                />
                {errors.email && (
                  <p className="text-red-400 text-xs mt-1">{errors.email.message}</p>
                )}
              </motion.div>

              <motion.div
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.4 }}
              >
                <label className="block text-xs text-slate-400 mb-1.5">كلمة المرور</label>
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    dir="ltr"
                    {...register('password')}
                    className={errors.password ? errorInputClass : inputClass}
                    placeholder="••••••••"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-indigo-400 transition-colors"
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {errors.password && (
                  <p className="text-red-400 text-xs mt-1">{errors.password.message}</p>
                )}
              </motion.div>

              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.5 }}
              >
                <button
                  type="submit"
                  disabled={isLoading}
                  className="w-full py-3 rounded-xl font-medium text-white bg-indigo-500 hover:bg-indigo-400 disabled:opacity-60 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2"
                >
                  {isLoading ? (
                    <><Loader2 size={16} className="animate-spin" /> جاري تسجيل الدخول...</>
                  ) : (
                    'تسجيل الدخول'
                  )}
                </button>
              </motion.div>
            </form>

            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.6 }}
              className="mt-6 text-center space-y-2"
            >
              <p className="text-sm text-slate-400">
                ليس لديك حساب؟{' '}
                <button onClick={() => router.push('/register')} className="text-indigo-400 hover:text-indigo-300 transition-colors">
                  إنشاء حساب
                </button>
              </p>
              <button
                onClick={() => router.push('/download')}
                className="text-xs text-slate-500 hover:text-indigo-400 transition-colors"
              >
                تحميل التطبيقات
              </button>
            </motion.div>
          </div>
        </motion.div>
      </div>
    </div>
  )
}
