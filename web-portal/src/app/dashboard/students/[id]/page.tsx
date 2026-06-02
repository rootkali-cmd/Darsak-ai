'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import {
  ArrowLeft,
  Brain,
  TrendingUp,
  TrendingDown,
  Target,
  Download,
  Loader2,
  Sparkles,
  CheckCircle2,
  AlertCircle,
} from 'lucide-react'
import toast from 'react-hot-toast'
import { Section, ProgressRing } from '@/components/ui'
import { studentsApi, gradesApi } from '@/lib/api'

export default function StudentReportPage() {
  const params = useParams()
  const router = useRouter()
  const studentId = params.id as string
  const [isAnalyzing, setIsAnalyzing] = useState(false)
  const [aiReport, setAiReport] = useState<any>(null)
  const queryClient = useQueryClient()

  const { data: student, isLoading: studentLoading } = useQuery({
    queryKey: ['student', studentId],
    queryFn: () => studentsApi.get(studentId).then((r) => r.data),
  })

  const { data: grades, isLoading: gradesLoading } = useQuery({
    queryKey: ['grades', studentId],
    queryFn: () => gradesApi.list({ student_id: studentId }).then((r) => r.data),
  })

  const analyzeMutation = useMutation({
    mutationFn: async () => {
      if (!grades || grades.length === 0) throw new Error('لا توجد درجات للتحليل')
      const subject = grades[0]?.subject || 'math'
      const gradesData = grades.map((g: any) => ({
        exam: g.exam_name,
        score: g.score,
        max_score: g.max_score,
        wrong_questions: g.wrong_questions || [],
      }))
      return studentsApi.analyze({
        student_id: studentId,
        subject,
        grades: gradesData,
      }).then((r) => r.data)
    },
    onSuccess: (data) => {
      setAiReport(data)
      toast.success('تم تحليل البيانات بنجاح! 🎉')
    },
    onError: (error: any) => {
      toast.error(error?.response?.data?.detail || error.message || 'فشل التحليل')
    },
  })

  const handleAnalyze = async () => {
    setIsAnalyzing(true)
    try {
      await analyzeMutation.mutateAsync()
    } finally {
      setIsAnalyzing(false)
    }
  }

  const handleExportPdf = async () => {
    try {
      const response = await studentsApi.exportPdf(studentId)
      const blob = new Blob([response.data], { type: 'application/pdf' })
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `report_${student?.code}.pdf`
      a.click()
      window.URL.revokeObjectURL(url)
      toast.success('تم تحميل التقرير')
    } catch {
      toast.error('فشل تحميل التقرير')
    }
  }

  if (studentLoading) {
    return (
      <div className="relative">
        <div className="fixed inset-0 bg-gradient-to-b from-[#0F172A] via-[#1E293B] to-[#0F172A] -z-10 pointer-events-none" />
        <div className="flex justify-center py-24">
          <Loader2 className="w-12 h-12 animate-spin text-indigo-400" />
        </div>
      </div>
    )
  }

  const averageGrade = grades?.length
    ? Math.round(grades.reduce((acc: number, g: any) => acc + (g.max_score > 0 ? (g.score / g.max_score) * 100 : 0), 0) / grades.length)
    : 0

  return (
    <div className="relative space-y-6">
      <div className="fixed inset-0 bg-gradient-to-b from-[#0F172A] via-[#1E293B] to-[#0F172A] -z-10 pointer-events-none" />
      <div className="fixed inset-0 -z-10 pointer-events-none overflow-hidden">
        <div className="absolute -top-40 -right-40 w-[500px] h-[500px] bg-indigo-500/20 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-[500px] h-[500px] bg-indigo-600/10 rounded-full blur-3xl" />
        <div className="absolute top-1/3 left-1/4 w-[300px] h-[300px] bg-purple-500/10 rounded-full blur-3xl" />
      </div>

      <Section>
        <div className="flex items-center gap-4">
          <motion.button
            whileHover={{ scale: 1.1, x: -5 }}
            whileTap={{ scale: 0.9 }}
            onClick={() => router.back()}
            className="p-3 rounded-xl bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] text-slate-400 hover:text-white transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </motion.button>
          <div className="flex items-center gap-4">
            <motion.div
              whileHover={{ scale: 1.1, rotate: 10 }}
              className="w-14 h-14 rounded-xl bg-gradient-to-br from-indigo-500 to-indigo-400 flex items-center justify-center"
            >
              <span className="text-white font-bold text-xl">{student?.full_name?.charAt(0)}</span>
            </motion.div>
            <div>
              <h1 className="text-2xl font-bold text-white">{student?.full_name}</h1>
              <p className="text-slate-400">
                كود الطالب: <span className="font-mono text-indigo-400">{student?.code}</span>
              </p>
            </div>
          </div>
        </div>
      </Section>

      <Section delay={0.1}>
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 relative overflow-hidden">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-4">
              <motion.div
                animate={isAnalyzing ? { rotate: 360 } : {}}
                transition={{ duration: 2, repeat: isAnalyzing ? Infinity : 0, ease: 'linear' }}
                className="p-4 rounded-2xl bg-indigo-500/10"
              >
                <Brain className="w-10 h-10 text-indigo-400" />
              </motion.div>
              <div>
                <h2 className="text-xl font-bold text-white">تحليل الذكاء الاصطناعي</h2>
                <p className="text-slate-400">
                  {!grades || grades.length === 0
                    ? 'يجب إضافة درجات أولاً للتحليل'
                    : 'تحليل شامل لأداء الطالب مع توصيات مخصصة'}
                </p>
              </div>
            </div>
            <button
              onClick={handleAnalyze}
              disabled={isAnalyzing || !grades || grades.length === 0}
              className="inline-flex items-center justify-center gap-2 px-5 py-3 bg-gradient-to-r from-indigo-500 to-indigo-400 text-white font-semibold rounded-xl hover:shadow-lg hover:shadow-indigo-500/25 transition-all duration-200 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed whitespace-nowrap"
            >
              {isAnalyzing ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin" />
                  جاري التحليل...
                </>
              ) : (
                <>
                  <Sparkles className="w-5 h-5" />
                  تحليل بالـ AI
                </>
              )}
            </button>
          </div>
        </div>
      </Section>

      <AnimatePresence>
        {isAnalyzing && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="flex flex-col items-center py-12"
          >
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 3, repeat: Infinity, ease: 'linear' }}
              className="w-20 h-20 rounded-full border-4 border-indigo-500/20 border-t-indigo-400 mb-4"
            />
            <p className="text-slate-400">جاري تحليل بيانات الطالب...</p>
            <p className="text-slate-500 text-sm mt-1">قد يستغرق هذا بضع ثوانٍ</p>
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {aiReport && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="space-y-6"
          >
            <Section>
              <div className="flex justify-center mb-8">
                <ProgressRing
                  progress={averageGrade}
                  size={160}
                  strokeWidth={12}
                  color={averageGrade >= 85 ? '#10B981' : averageGrade >= 50 ? '#F59E0B' : '#EF4444'}
                  bgColor="rgba(255,255,255,0.05)"
                  label="المتوسط العام"
                />
              </div>
            </Section>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <Section delay={0.1} direction="left">
                <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] border-l-4 border-l-emerald-500 rounded-2xl p-5 h-full">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 rounded-lg bg-emerald-500/10">
                      <TrendingUp className="w-5 h-5 text-emerald-400" />
                    </div>
                    <h3 className="text-lg font-bold text-emerald-400">نقاط القوة</h3>
                  </div>
                  <ul className="space-y-3">
                    {(aiReport.strengths || []).map((item: string, i: number) => (
                      <motion.li
                        key={i}
                        initial={{ opacity: 0, x: -30 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: 0.2 + i * 0.1 }}
                        className="flex items-start gap-3 p-3 rounded-lg bg-emerald-500/5"
                      >
                        <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
                        <span className="text-sm text-slate-300">{item}</span>
                      </motion.li>
                    ))}
                  </ul>
                </div>
              </Section>

              <Section delay={0.2} direction="right">
                <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] border-l-4 border-l-red-500 rounded-2xl p-5 h-full">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 rounded-lg bg-red-500/10">
                      <TrendingDown className="w-5 h-5 text-red-400" />
                    </div>
                    <h3 className="text-lg font-bold text-red-400">نقاط الضعف</h3>
                  </div>
                  <ul className="space-y-3">
                    {(aiReport.weaknesses || []).map((item: string, i: number) => (
                      <motion.li
                        key={i}
                        initial={{ opacity: 0, x: 30 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: 0.3 + i * 0.1 }}
                        className="flex items-start gap-3 p-3 rounded-lg bg-red-500/5"
                      >
                        <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                        <span className="text-sm text-slate-300">{item}</span>
                      </motion.li>
                    ))}
                  </ul>
                </div>
              </Section>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <Section delay={0.3}>
                <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] border-l-4 border-l-amber-500 rounded-2xl p-5">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 rounded-lg bg-amber-500/10">
                      <Target className="w-5 h-5 text-amber-400" />
                    </div>
                    <h3 className="text-lg font-bold text-amber-400">التركيز المطلوب</h3>
                  </div>
                  <ul className="space-y-3">
                    {(aiReport.recommended_focus || []).map((item: string, i: number) => (
                      <motion.li
                        key={i}
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.4 + i * 0.1 }}
                        className="flex items-start gap-3 p-3 rounded-lg bg-amber-500/5"
                      >
                        <span className="text-amber-400 mt-1">→</span>
                        <span className="text-sm text-slate-300">{item}</span>
                      </motion.li>
                    ))}
                  </ul>
                </div>
              </Section>

              <Section delay={0.4}>
                <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] border-l-4 border-l-violet-500 rounded-2xl p-5">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 rounded-lg bg-violet-500/10">
                      <Sparkles className="w-5 h-5 text-violet-400" />
                    </div>
                    <h3 className="text-lg font-bold text-violet-400">التمرين المقترح</h3>
                  </div>
                  <motion.p
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.5 }}
                    className="text-sm leading-relaxed text-slate-300 p-4 rounded-lg bg-violet-500/5"
                  >
                    {aiReport.next_exercise_suggestion || ''}
                  </motion.p>
                </div>
              </Section>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <Section delay={0.3}>
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-white">سجل الدرجات</h2>
            <button
              onClick={handleExportPdf}
              className="inline-flex items-center justify-center gap-2 px-4 py-2 bg-transparent border border-white/[0.08] rounded-xl text-slate-300 font-semibold text-sm hover:border-indigo-500/50 hover:text-indigo-400 transition-all duration-200 active:scale-95"
            >
              <Download className="w-4 h-4" />
              تصدير PDF
            </button>
          </div>

          {gradesLoading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="w-6 h-6 animate-spin text-indigo-400" />
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-white/[0.06]">
                    <th className="text-right py-3 px-4 text-slate-500 font-medium">الامتحان</th>
                    <th className="text-right py-3 px-4 text-slate-500 font-medium">المادة</th>
                    <th className="text-center py-3 px-4 text-slate-500 font-medium">الدرجة</th>
                    <th className="text-center py-3 px-4 text-slate-500 font-medium">النسبة</th>
                  </tr>
                </thead>
                <tbody>
                  {grades?.map((grade: any, index: number) => {
                    const percentage = grade.max_score > 0 ? (grade.score / grade.max_score) * 100 : 0
                    const color = percentage >= 85 ? 'text-emerald-400' : percentage >= 50 ? 'text-amber-400' : 'text-red-400'
                    return (
                      <motion.tr
                        key={grade.id}
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: index * 0.05 }}
                        className="border-b border-white/[0.06] hover:bg-white/[0.03] transition-colors"
                      >
                        <td className="py-3 px-4 text-white">{grade.exam_name}</td>
                        <td className="py-3 px-4 text-slate-400">{grade.subject}</td>
                        <td className="py-3 px-4 text-center font-mono text-white">{grade.score}/{grade.max_score}</td>
                        <td className={`py-3 px-4 text-center font-bold ${color}`}>{percentage.toFixed(1)}%</td>
                      </motion.tr>
                    )
                  })}
                </tbody>
              </table>
              {(!grades || grades.length === 0) && (
                <div className="text-center py-8 text-slate-500">
                  لا توجد درجات مسجلة
                </div>
              )}
            </div>
          )}
        </div>
      </Section>
    </div>
  )
}
