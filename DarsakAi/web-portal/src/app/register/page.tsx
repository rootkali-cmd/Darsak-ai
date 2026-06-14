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
      await authApi.register({
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
    <div className="min-h-screen relative overflow-hidden bg-[#0a0a1a]">
      {/* Animated background */}
      <div className="absolute inset-0">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-gradient-to-b from-indigo-600/20 via-purple-600/10 to-transparent rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-0 w-[600px] h-[600px] bg-gradient-to-tl from-blue-600/10 to-transparent rounded-full blur-3xl" />
        <div className="absolute top-1/3 left-0 w-[400px] h-[400px] bg-gradient-to-tr from-violet-600/10 to-transparent rounded-full blur-3xl" />
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
              انضم لآلاف<br />
              <span className="bg-gradient-to-l from-indigo-400 to-purple-400 bg-clip-text text-transparent">المعلمين المتميزين</span>
            </h2>
            <p className="text-slate-400 text-lg leading-relaxed max-w-md">
              أنشئ حسابك مجاناً وابدأ في إدارة طلابك بشكل ذكي مع تحليلات متقدمة وأدوات متكاملة
            </p>
            <div className="mt-8 space-y-4">
              {[
                'إدارة الطلاب والحضور في مكان واحد',
                'تحليلات ذكية مدعومة بالـ AI',
                'تطبيق موبايل للطلاب والمعلمين',
              ].map((feature, i) => (
                <div key={i} className="flex items-center gap-3">
                  <div className="w-6 h-6 bg-indigo-500/20 rounded-full flex items-center justify-center">
                    <div className="w-2 h-2 bg-indigo-400 rounded-full" />
                  </div>
                  <span className="text-slate-300 text-sm">{feature}</span>
                </div>
              ))}
            </div>
          </motion.div>

          {/* Right side - Register form */}
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
                <h3 className="text-xl font-bold text-white mb-1">إنشاء حساب جديد</h3>
                <p className="text-sm text-slate-400">ابدأ رحلتك التعليمية مجاناً</p>
              </div>

              <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                <div>
                  <label className="block text-xs text-slate-400 mb-2 font-medium">الاسم الكامل</label>
                  <input
                    type="text"
                    {...register('full_name')}
                    className={`w-full bg-white/[0.06] border ${errors.full_name ? 'border-red-500/60' : 'border-white/[0.1]'} rounded-xl text-white placeholder:text-slate-600 px-4 py-3 outline-none focus:border-indigo-500 focus:bg-white/[0.08] transition-all text-sm`}
                    placeholder="أحمد محمد"
                  />
                  {errors.full_name && <p className="text-red-400 text-xs mt-1.5">{errors.full_name.message}</p>}
                </div>

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

                <div>
                  <label className="block text-xs text-slate-400 mb-2 font-medium">تأكيد كلمة المرور</label>
                  <input
                    type={showPassword ? 'text' : 'password'}
                    dir="ltr"
                    {...register('confirmPassword')}
                    className={`w-full bg-white/[0.06] border ${errors.confirmPassword ? 'border-red-500/60' : 'border-white/[0.1]'} rounded-xl text-white placeholder:text-slate-600 px-4 py-3 outline-none focus:border-indigo-500 focus:bg-white/[0.08] transition-all text-sm`}
                    placeholder="••••••••"
                  />
                  {errors.confirmPassword && <p className="text-red-400 text-xs mt-1.5">{errors.confirmPassword.message}</p>}
                </div>

                <button
                  type="submit"
                  disabled={isLoading}
                  className="w-full py-3.5 rounded-xl font-medium text-white bg-gradient-to-l from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 disabled:opacity-60 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2 shadow-lg shadow-indigo-500/25 hover:shadow-indigo-500/40 mt-6"
                >
                  {isLoading ? (
                    <><Loader2 size={18} className="animate-spin" /> جاري إنشاء الحساب...</>
                  ) : (
                    <><Sparkles size={18} /> إنشاء حساب مجاني</>
                  )}
                </button>
              </form>

              <div className="mt-6 text-center">
                <p className="text-sm text-slate-400">
                  لديك حساب بالفعل؟{' '}
                  <button onClick={() => router.push('/login')} className="text-indigo-400 hover:text-indigo-300 font-medium transition-colors">
                    تسجيل الدخول
                  </button>
                </p>
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  )
}
