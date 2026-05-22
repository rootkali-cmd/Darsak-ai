'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { Eye, EyeOff, Loader2, Mail, Lock, Sparkles } from 'lucide-react'
import { authApi } from '@/lib/api'
import { auth } from '@/lib/auth'


const loginSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
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
      toast.success('ACCESS GRANTED')
      router.push('/dashboard')
    } catch (error: any) {
      toast.error(error.response?.data?.detail || 'ACCESS DENIED')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center relative px-4">
      {/* Corner decorations */}
      <div className="fixed top-4 left-4 z-50 hud-text flex items-center gap-2">
        <span className="text-[var(--accent)]">●</span>
        <span>DARSAK AI</span>
        <span className="text-[rgba(255,255,255,0.2)]">/</span>
        <span>AUTH</span>
      </div>

      {/* Exit button */}
      <button
        onClick={() => router.push('/')}
        className="fixed top-4 ltr:left-4 rtl:right-4 z-50 px-4 py-2 border border-[var(--border)] hover:border-[var(--accent-2)] text-xs hud-text transition-colors"
        style={{ background: 'var(--card-bg)' }}
      >
        ← BACK
      </button>



      {/* Login Card */}
      <motion.div
        initial={{ opacity: 0, y: 50 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        className="relative z-10 w-full max-w-sm"
      >
        {/* Card with brutal corners */}
        <div className="brutal-card p-8" style={{ background: 'var(--card-bg)', position: 'relative' }}>
          {/* Corner brackets */}
          <div className="absolute top-0 left-0 w-4 h-4 border-t border-l border-[var(--accent)]" />
          <div className="absolute top-0 right-0 w-4 h-4 border-t border-r border-[var(--accent-2)]" />
          <div className="absolute bottom-0 left-0 w-4 h-4 border-b border-l border-[var(--accent-2)]" />
          <div className="absolute bottom-0 right-0 w-4 h-4 border-b border-r border-[var(--accent)]" />

          {/* Logo & Title */}
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
            <p className="text-xs hud-text">AUTHENTICATION REQUIRED</p>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
            {/* Email */}
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

            {/* Password */}
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

            {/* Submit */}
            <button
              type="submit"
              disabled={isLoading}
              className="brutal-btn w-full flex items-center justify-center gap-2 py-3"
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  AUTHENTICATING...
                </>
              ) : (
                'ACCESS SYSTEM'
              )}
            </button>
          </form>

          {/* Register link */}
          <div className="mt-6 text-center">
            <p className="text-[10px] hud-text text-[var(--text-muted)]">
              ليس لديك حساب؟{' '}
              <button
                onClick={() => router.push('/register')}
                className="text-[var(--accent)] hover:underline"
              >
                إنشاء حساب
              </button>
            </p>
          </div>
        </div>
      </motion.div>
    </div>
  )
}
