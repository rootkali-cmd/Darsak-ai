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
import { GlassCard, NeonButton, Section, ProgressRing } from '@/components/ui'
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
      <div className="flex justify-center py-24">
        <Loader2 className="w-12 h-12 animate-spin text-[var(--accent)]" />
      </div>
    )
  }

  const averageGrade = grades?.length
    ? Math.round(grades.reduce((acc: number, g: any) => acc + (g.max_score > 0 ? (g.score / g.max_score) * 100 : 0), 0) / grades.length)
    : 0

  return (
    <div className="space-y-6">
      {/* Back Button & Header */}
      <Section>
        <div className="flex items-center gap-4">
          <motion.button
            whileHover={{ scale: 1.1, x: -5 }}
            whileTap={{ scale: 0.9 }}
            onClick={() => router.back()}
            className="p-3 rounded-xl glass text-[var(--text-muted)] hover:text-[var(--text)] transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </motion.button>
          <div className="flex items-center gap-4">
            <motion.div
              whileHover={{ scale: 1.1, rotate: 10 }}
              className="w-14 h-14 rounded-xl bg-[var(--accent)] flex items-center justify-center "
            >
              <span className="text-[var(--text)] font-bold text-xl">{student?.full_name?.charAt(0)}</span>
            </motion.div>
            <div>
              <h1 className="text-2xl font-bold">{student?.full_name}</h1>
              <p className="text-[var(--text-muted)]">
                كود الطالب: <span className="font-mono text-[var(--accent)]">{student?.code}</span>
              </p>
            </div>
          </div>
        </div>
      </Section>

      {/* AI Analysis Button */}
      <Section delay={0.1}>
        <GlassCard className="relative overflow-hidden">
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-4">
              <motion.div
                animate={isAnalyzing ? { rotate: 360 } : {}}
                transition={{ duration: 2, repeat: isAnalyzing ? Infinity : 0, ease: 'linear' }}
                className="p-4 rounded-2xl bg-[rgba(255,0,60,0.1)]"
              >
                <Brain className="w-10 h-10 text-[var(--accent)]" />
              </motion.div>
              <div>
                <h2 className="text-xl font-bold">تحليل الذكاء الاصطناعي</h2>
                <p className="text-[var(--text-muted)]">
                  {!grades || grades.length === 0
                    ? 'يجب إضافة درجات أولاً للتحليل'
                    : 'تحليل شامل لأداء الطالب مع توصيات مخصصة'}
                </p>
              </div>
            </div>
            <NeonButton onClick={handleAnalyze} disabled={isAnalyzing || !grades || grades.length === 0}>
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
            </NeonButton>
          </div>

        </GlassCard>
      </Section>

      {/* Loading State */}
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
              className="w-20 h-20 rounded-full border-4 border-primary/20 border-t-primary mb-4"
            />
            <p className="text-[var(--text-muted)]">جاري تحليل بيانات الطالب...</p>
            <p className="text-[var(--text-muted)] text-sm mt-1">قد يستغرق هذا بضع ثوانٍ</p>
          </motion.div>
        )}
      </AnimatePresence>

      {/* AI Report Results */}
      <AnimatePresence>
        {aiReport && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="space-y-6"
          >
            {/* Average Grade Ring */}
            <Section>
              <div className="flex justify-center mb-8">
                <ProgressRing
                  progress={averageGrade}
                  size={160}
                  strokeWidth={12}
                  color={averageGrade >= 85 ? '#10B981' : averageGrade >= 50 ? '#F59E0B' : '#EF4444'}
                  label="المتوسط العام"
                />
              </div>
            </Section>

            {/* Strengths & Weaknesses */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <Section delay={0.1} direction="left">
                <GlassCard className="border-green-500/20 h-full">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 rounded-lg bg-green-500/10">
                      <TrendingUp className="w-5 h-5 text-green-500" />
                    </div>
                    <h3 className="text-lg font-bold text-green-500">نقاط القوة</h3>
                  </div>
                  <ul className="space-y-3">
                    {(aiReport.strengths || []).map((item: string, i: number) => (
                      <motion.li
                        key={i}
                        initial={{ opacity: 0, x: -30 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: 0.2 + i * 0.1 }}
                        className="flex items-start gap-3 p-3 rounded-lg bg-accent-green/5"
                      >
                        <CheckCircle2 className="w-5 h-5 text-green-500 flex-shrink-0 mt-0.5" />
                        <span className="text-sm">{item}</span>
                      </motion.li>
                    ))}
                  </ul>
                </GlassCard>
              </Section>

              <Section delay={0.2} direction="right">
                <GlassCard className="border-red-500/20 h-full">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 rounded-lg bg-red-500/10">
                      <TrendingDown className="w-5 h-5 text-red-500" />
                    </div>
                    <h3 className="text-lg font-bold text-red-500">نقاط الضعف</h3>
                  </div>
                  <ul className="space-y-3">
                    {(aiReport.weaknesses || []).map((item: string, i: number) => (
                      <motion.li
                        key={i}
                        initial={{ opacity: 0, x: 30 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: 0.3 + i * 0.1 }}
                        className="flex items-start gap-3 p-3 rounded-lg bg-danger/5"
                      >
                        <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
                        <span className="text-sm">{item}</span>
                      </motion.li>
                    ))}
                  </ul>
                </GlassCard>
              </Section>
            </div>

            {/* Recommendations & Exercise */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <Section delay={0.3}>
                <GlassCard className="border-yellow-500/20">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 rounded-lg bg-warning/10">
                      <Target className="w-5 h-5 text-yellow-500" />
                    </div>
                    <h3 className="text-lg font-bold text-yellow-500">التركيز المطلوب</h3>
                  </div>
                  <ul className="space-y-3">
                    {(aiReport.recommended_focus || []).map((item: string, i: number) => (
                      <motion.li
                        key={i}
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.4 + i * 0.1 }}
                        className="flex items-start gap-3 p-3 rounded-lg bg-warning/5"
                      >
                        <span className="text-yellow-500 mt-1">→</span>
                        <span className="text-sm">{item}</span>
                      </motion.li>
                    ))}
                  </ul>
                </GlassCard>
              </Section>

              <Section delay={0.4}>
                <GlassCard className="border-primary/20">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 rounded-lg bg-[rgba(255,0,60,0.1)]">
                      <Sparkles className="w-5 h-5 text-[var(--accent)]" />
                    </div>
                    <h3 className="text-lg font-bold text-[var(--accent)]">التمرين المقترح</h3>
                  </div>
                  <motion.p
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.5 }}
                    className="text-sm leading-relaxed p-4 rounded-lg bg-primary/5"
                  >
                    {aiReport.next_exercise_suggestion || ''}
                  </motion.p>
                </GlassCard>
              </Section>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Grades History */}
      <Section delay={0.3}>
        <GlassCard>
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold">سجل الدرجات</h2>
            <NeonButton variant="outline" size="sm" onClick={handleExportPdf}>
              <Download className="w-4 h-4" />
              تصدير PDF
            </NeonButton>
          </div>

          {gradesLoading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="w-6 h-6 animate-spin text-[var(--accent)]" />
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-black/5">
                    <th className="text-right py-3 px-4 text-[var(--text-muted)] font-medium">الامتحان</th>
                    <th className="text-right py-3 px-4 text-[var(--text-muted)] font-medium">المادة</th>
                    <th className="text-center py-3 px-4 text-[var(--text-muted)] font-medium">الدرجة</th>
                    <th className="text-center py-3 px-4 text-[var(--text-muted)] font-medium">النسبة</th>
                  </tr>
                </thead>
                <tbody>
                  {grades?.map((grade: any, index: number) => {
                    const percentage = grade.max_score > 0 ? (grade.score / grade.max_score) * 100 : 0
                    const color = percentage >= 85 ? 'text-green-500' : percentage >= 50 ? 'text-yellow-500' : 'text-red-500'
                    return (
                      <motion.tr
                        key={grade.id}
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: index * 0.05 }}
                        className="border-b border-black/5 hover:bg-[rgba(0,0,0,0.02)] transition-colors"
                      >
                        <td className="py-3 px-4">{grade.exam_name}</td>
                        <td className="py-3 px-4 text-[var(--text-muted)]">{grade.subject}</td>
                        <td className="py-3 px-4 text-center font-mono">{grade.score}/{grade.max_score}</td>
                        <td className={`py-3 px-4 text-center font-bold ${color}`}>{percentage.toFixed(1)}%</td>
                      </motion.tr>
                    )
                  })}
                </tbody>
              </table>
              {(!grades || grades.length === 0) && (
                <div className="text-center py-8 text-[var(--text-muted)]">
                  لا توجد درجات مسجلة
                </div>
              )}
            </div>
          )}
        </GlassCard>
      </Section>
    </div>
  )
}
