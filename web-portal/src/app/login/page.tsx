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
      toast.error(error.response?.data?.detail || 'فشل تسجيل الدخول')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center px-4">
      <button
        onClick={() => router.push('/')}
        className="fixed top-4 left-4 z-50 text-sm text-[var(--text-muted)] hover:text-[var(--accent)] transition-colors"
      >
        ← العودة
      </button>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="w-full max-w-sm"
      >
        <div className="card p-8">
          <div className="text-center mb-8">
            <h1 className="text-2xl font-bold mb-1" style={{ fontFamily: "'JetBrains Mono', monospace" }}>
              DARSAK AI
            </h1>
            <p className="text-sm text-[var(--text-muted)]">تسجيل الدخول إلى لوحة التحكم</p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1.5">البريد الإلكتروني</label>
              <input
                type="email"
                dir="ltr"
                {...register('email')}
                className={`input ${errors.email ? '!border-[var(--accent)]' : ''}`}
                placeholder="teacher@darsak.ai"
              />
              {errors.email && (
                <p className="text-[var(--accent)] text-xs mt-1">{errors.email.message}</p>
              )}
            </div>

            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1.5">كلمة المرور</label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  dir="ltr"
                  {...register('password')}
                  className={`input ${errors.password ? '!border-[var(--accent)]' : ''}`}
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)] hover:text-[var(--accent)] transition-colors"
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              {errors.password && (
                <p className="text-[var(--accent)] text-xs mt-1">{errors.password.message}</p>
              )}
            </div>

            <button type="submit" disabled={isLoading} className="btn btn-primary w-full py-3">
              {isLoading ? (
                <><Loader2 size={16} className="animate-spin" /> جاري تسجيل الدخول...</>
              ) : (
                'تسجيل الدخول'
              )}
            </button>
          </form>

          <div className="mt-6 text-center space-y-2">
            <p className="text-sm text-[var(--text-muted)]">
              ليس لديك حساب؟{' '}
              <button onClick={() => router.push('/register')} className="link">
                إنشاء حساب
              </button>
            </p>
            <button
              onClick={() => router.push('/download')}
              className="text-xs text-[var(--text-muted)] hover:text-[var(--accent-2)] transition-colors"
            >
              تحميل التطبيقات
            </button>
          </div>
        </div>
      </motion.div>
    </div>
  )
}
