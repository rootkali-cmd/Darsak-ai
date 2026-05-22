'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { Eye, EyeOff, Loader2, Mail, Lock, User, Sparkles, ArrowLeft } from 'lucide-react'
import { authApi } from '@/lib/api'
import { auth } from '@/lib/auth'

const registerSchema = z.object({
  full_name: z.string().min(2, 'الاسم يجب أن يكون 2 أحرف على الأقل'),
  email: z.string().email('البريد الإلكتروني غير صحيح'),
  password: z.string().min(6, 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
  confirmPassword: z.string().min(6, 'تأكيد كلمة المرور'),
}).refine((data) => data.password === data.confirmPassword, {
  message: 'كلمة المرور غير متطابقة',
  path: ['confirmPassword'],
})

type RegisterForm = z.infer<typeof registerSchema>

export default function RegisterPage() {
  const router = useRouter()
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<RegisterForm>({
    resolver: zodResolver(registerSchema),
  })

  const onSubmit = async (data: RegisterForm) => {
    setIsLoading(true)
    try {
      const res = await authApi.register({
        email: data.email,
        full_name: data.full_name,
        password: data.password,
        role: 'teacher',
      })
      toast.success('تم إنشاء الحساب بنجاح!')
      const loginRes = await authApi.login(data.email, data.password)
      auth.setTokens(loginRes.data.access_token, loginRes.data.refresh_token)
      router.push('/dashboard')
    } catch (err: any) {
      const msg = err?.response?.data?.detail || 'فشل إنشاء الحساب'
      toast.error(msg)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden" style={{ background: 'var(--bg)' }}>
      <div className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage: 'radial-gradient(circle at 1px 1px, var(--accent) 1px, transparent 0)',
          backgroundSize: '40px 40px',
        }}
      />

      <button
        onClick={() => router.push('/')}
        className="fixed top-4 ltr:left-4 rtl:right-4 z-50 px-4 py-2 border border-[var(--border)] hover:border-[var(--accent-2)] text-xs hud-text transition-colors"
        style={{ background: 'var(--card-bg)' }}
      >
        ← BACK
      </button>

      <motion.div
        initial={{ opacity: 0, y: 50 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        className="relative z-10 w-full max-w-sm"
      >
        <div className="brutal-card p-8" style={{ background: 'var(--card-bg)', position: 'relative' }}>
          <div className="absolute top-0 left-0 w-4 h-4 border-t border-l border-[var(--accent)]" />
          <div className="absolute top-0 right-0 w-4 h-4 border-t border-r border-[var(--accent-2)]" />
          <div className="absolute bottom-0 left-0 w-4 h-4 border-b border-l border-[var(--accent-2)]" />
          <div className="absolute bottom-0 right-0 w-4 h-4 border-b border-r border-[var(--accent)]" />

          <div className="text-center mb-8">
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: 0.2, type: 'spring', stiffness: 200 }}
              className="inline-flex items-center justify-center w-16 h-16 border border-[var(--accent)] mb-4"
            >
              <Sparkles className="w-8 h-8 text-[var(--accent)]" />
            </motion.div>

            <h1 className="text-2xl font-bold mb-1" style={{ fontFamily: 'var(--font-display)' }}>
              DARSAK AI
            </h1>
            <p className="text-xs hud-text">CREATE ACCOUNT</p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
            <div>
              <label className="block text-xs hud-text mb-2 text-[var(--text-muted)]">
                FULL NAME
              </label>
              <div className="relative">
                <User className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--text-muted)]" />
                <input
                  type="text"
                  {...register('full_name')}
                  className={`brutal-input w-full pr-10 pl-3 py-3 text-sm ${errors.full_name ? 'border-[var(--accent)]' : ''}`}
                  placeholder="أحمد محمد"
                />
              </div>
              {errors.full_name && (
                <p className="text-[var(--accent)] text-[10px] hud-text mt-1">
                  {errors.full_name.message}
                </p>
              )}
            </div>

            <div>
              <label className="block text-xs hud-text mb-2 text-[var(--text-muted)]">
                EMAIL
              </label>
              <div className="relative">
                <Mail className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--text-muted)]" />
                <input
                  type="email"
                  {...register('email')}
                  className={`brutal-input w-full pr-10 pl-3 py-3 text-sm ${errors.email ? 'border-[var(--accent)]' : ''}`}
                  placeholder="teacher@darsak.ai"
                  dir="ltr"
                />
              </div>
              {errors.email && (
                <p className="text-[var(--accent)] text-[10px] hud-text mt-1">
                  {errors.email.message}
                </p>
              )}
            </div>

            <div>
              <label className="block text-xs hud-text mb-2 text-[var(--text-muted)]">
                PASSWORD
              </label>
              <div className="relative">
                <Lock className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--text-muted)]" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  {...register('password')}
                  className={`brutal-input w-full pr-10 pl-10 py-3 text-sm ${errors.password ? 'border-[var(--accent)]' : ''}`}
                  placeholder="••••••••"
                  dir="ltr"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute ltr:left-3 rtl:right-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)] hover:text-[var(--accent)] transition-colors"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {errors.password && (
                <p className="text-[var(--accent)] text-[10px] hud-text mt-1">
                  {errors.password.message}
                </p>
              )}
            </div>

            <div>
              <label className="block text-xs hud-text mb-2 text-[var(--text-muted)]">
                CONFIRM PASSWORD
              </label>
              <div className="relative">
                <Lock className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--text-muted)]" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  {...register('confirmPassword')}
                  className={`brutal-input w-full pr-10 pl-3 py-3 text-sm ${errors.confirmPassword ? 'border-[var(--accent)]' : ''}`}
                  placeholder="••••••••"
                  dir="ltr"
                />
              </div>
              {errors.confirmPassword && (
                <p className="text-[var(--accent)] text-[10px] hud-text mt-1">
                  {errors.confirmPassword.message}
                </p>
              )}
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="brutal-btn w-full flex items-center justify-center gap-2 py-3"
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  CREATING...
                </>
              ) : (
                'CREATE ACCOUNT'
              )}
            </button>
          </form>

          <div className="mt-6 text-center">
            <p className="text-[10px] hud-text text-[var(--text-muted)]">
              لديك حساب بالفعل؟{' '}
              <button
                onClick={() => router.push('/login')}
                className="text-[var(--accent)] hover:underline"
              >
                تسجيل الدخول
              </button>
            </p>
          </div>
        </div>
      </motion.div>
    </div>
  )
}
