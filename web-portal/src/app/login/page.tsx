'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { Eye, EyeOff, Loader2, GraduationCap, Sparkles } from 'lucide-react'
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
    <div className="min-h-screen relative overflow-hidden bg-[#0a0a1a]">
      {/* Animated background */}
      <div className="absolute inset-0">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-gradient-to-b from-indigo-600/20 via-purple-600/10 to-transparent rounded-full blur-3xl" />
        <div className="absolute bottom-0 left-0 w-[600px] h-[600px] bg-gradient-to-tr from-blue-600/10 to-transparent rounded-full blur-3xl" />
        <div className="absolute top-1/4 right-0 w-[400px] h-[400px] bg-gradient-to-tl from-violet-600/10 to-transparent rounded-full blur-3xl" />
        {/* Grid pattern */}
        <div
          className="absolute inset-0 opacity-[0.03]"
          style={{
            backgroundImage: 'linear-gradient(rgba(255,255,255,.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.1) 1px, transparent 1px)',
            backgroundSize: '60px 60px',
          }}
        />
      </div>

      {/* Back button */}
      <button
        onClick={() => router.push('/')}
        className="fixed top-6 left-6 z-50 flex items-center gap-2 text-sm text-slate-400 hover:text-white transition-colors bg-white/5 hover:bg-white/10 px-4 py-2 rounded-full backdrop-blur-sm border border-white/10"
      >
        ← العودة
      </button>

      <div className="relative min-h-screen flex items-center justify-center px-4 py-12">
        <div className="w-full max-w-5xl flex items-center gap-12">
          {/* Left side - Branding */}
          <motion.div
            initial={{ opacity: 0, x: -40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8 }}
            className="hidden lg:flex flex-1 flex-col items-start"
          >
            <div className="flex items-center gap-3 mb-8">
              <div className="w-14 h-14 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-2xl flex items-center justify-center shadow-lg shadow-indigo-500/30">
                <GraduationCap size={28} className="text-white" />
              </div>
              <div>
                <h1 className="text-3xl font-bold text-white tracking-tight" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</h1>
                <p className="text-indigo-400 text-sm">نظام إدارة تعليمي ذكي</p>
              </div>
            </div>
            <h2 className="text-4xl font-bold text-white leading-tight mb-4">
              إدارة طلابك<br />
              <span className="bg-gradient-to-l from-indigo-400 to-purple-400 bg-clip-text text-transparent">بذكاء وسهولة</span>
            </h2>
            <p className="text-slate-400 text-lg leading-relaxed max-w-md">
              منصة متكاملة لإدارة الطلاب والحضور والدرجات مع تحليلات ذكية مدعومة بالذكاء الاصطناعي
            </p>
            <div className="flex items-center gap-6 mt-8">
              {[
                { num: '+2000', label: 'معلم' },
                { num: '+50K', label: 'طالب' },
                { num: '99%', label: 'رضا' },
              ].map((stat) => (
                <div key={stat.label} className="text-center">
                  <div className="text-2xl font-bold text-white" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{stat.num}</div>
                  <div className="text-xs text-slate-500">{stat.label}</div>
                </div>
              ))}
            </div>
          </motion.div>

          {/* Right side - Login form */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="w-full max-w-md"
          >
            <div className="bg-white/[0.04] border border-white/[0.08] rounded-3xl p-8 backdrop-blur-xl shadow-2xl shadow-black/20">
              {/* Mobile logo */}
              <div className="flex items-center justify-center gap-3 mb-8 lg:hidden">
                <div className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl flex items-center justify-center">
                  <GraduationCap size={20} className="text-white" />
                </div>
                <span className="text-xl font-bold text-white" style={{ fontFamily: "'JetBrains Mono', monospace" }}>DARSAK AI</span>
              </div>

              <div className="text-center mb-8">
                <h3 className="text-xl font-bold text-white mb-1">مرحباً بعودتك</h3>
                <p className="text-sm text-slate-400">سجل دخولك للوصول إلى لوحة التحكم</p>
              </div>

              <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
                <div>
                  <label className="block text-xs text-slate-400 mb-2 font-medium">البريد الإلكتروني</label>
                  <input
                    type="email"
                    dir="ltr"
                    {...register('email')}
                    className={`w-full bg-white/[0.06] border ${errors.email ? 'border-red-500/60' : 'border-white/[0.1]'} rounded-xl text-white placeholder:text-slate-600 px-4 py-3 outline-none focus:border-indigo-500 focus:bg-white/[0.08] transition-all text-sm`}
                    placeholder="teacher@darsak.ai"
                  />
                  {errors.email && <p className="text-red-400 text-xs mt-1.5">{errors.email.message}</p>}
                </div>

                <div>
                  <label className="block text-xs text-slate-400 mb-2 font-medium">كلمة المرور</label>
                  <div className="relative">
                    <input
                      type={showPassword ? 'text' : 'password'}
                      dir="ltr"
                      {...register('password')}
                      className={`w-full bg-white/[0.06] border ${errors.password ? 'border-red-500/60' : 'border-white/[0.1]'} rounded-xl text-white placeholder:text-slate-600 px-4 py-3 outline-none focus:border-indigo-500 focus:bg-white/[0.08] transition-all text-sm`}
                      placeholder="••••••••"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-indigo-400 transition-colors"
                    >
                      {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                  {errors.password && <p className="text-red-400 text-xs mt-1.5">{errors.password.message}</p>}
                </div>

                <button
                  type="submit"
                  disabled={isLoading}
                  className="w-full py-3.5 rounded-xl font-medium text-white bg-gradient-to-l from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 disabled:opacity-60 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2 shadow-lg shadow-indigo-500/25 hover:shadow-indigo-500/40"
                >
                  {isLoading ? (
                    <><Loader2 size={18} className="animate-spin" /> جاري تسجيل الدخول...</>
                  ) : (
                    <><Sparkles size={18} /> تسجيل الدخول</>
                  )}
                </button>
              </form>

              <div className="mt-6 text-center space-y-3">
                <p className="text-sm text-slate-400">
                  ليس لديك حساب؟{' '}
                  <button onClick={() => router.push('/register')} className="text-indigo-400 hover:text-indigo-300 font-medium transition-colors">
                    إنشاء حساب مجاني
                  </button>
                </p>
                <button
                  onClick={() => router.push('/download')}
                  className="text-xs text-slate-500 hover:text-indigo-400 transition-colors"
                >
                  تحميل تطبيقات الموبايل
                </button>
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  )
}
