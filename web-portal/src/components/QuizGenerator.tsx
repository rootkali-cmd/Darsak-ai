'use client'
import { useState } from 'react'
import { Sparkles, Loader2, AlertCircle, CheckCircle2 } from 'lucide-react'

export default function QuizGenerator({ lessonId }: { lessonId: string }) {
  const [loading, setLoading] = useState(false)
  const [questions, setQuestions] = useState<any[]>([])
  const [error, setError] = useState('')
  const [selected, setSelected] = useState<Record<number, number>>({})
  const [submitted, setSubmitted] = useState(false)
  const [score, setScore] = useState(0)

  const generateQuiz = async () => {
    setLoading(true); setError('')
    try {
      const res = await fetch('/api/quiz/generate', {
        method: 'POST', headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ lesson_id: lessonId })
      })
      if (!res.ok) {
        const d = await res.json()
        throw new Error(d.detail || 'Failed')
      }
      const data = await res.json()
      setQuestions(data.questions || [])
    } catch (e: any) {
      setError(e.message || 'فشل توليد الكويز')
    } finally { setLoading(false) }
  }

  const handleSubmit = () => {
    let correct = 0
    questions.forEach((q, i) => {
      if (selected[i] === q.correct) correct++
    })
    setScore(correct)
    setSubmitted(true)
  }

  return (
    <div className="mt-8 bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-bold text-white">توليد كويز</h3>
        {questions.length === 0 && (
          <button onClick={generateQuiz} disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-500 hover:bg-indigo-600 text-white text-sm font-semibold rounded-xl transition-all disabled:opacity-50">
            {loading ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
            {loading ? 'جاري التوليد...' : 'اصنع لي كويز'}
          </button>
        )}
      </div>

      {error && (
        <div className="flex items-center gap-2 text-red-400 text-sm mb-4 bg-red-500/10 p-3 rounded-xl">
          <AlertCircle size={16} /> {error}
        </div>
      )}

      {questions.length > 0 && !submitted && (
        <div className="space-y-6">
          {questions.map((q, i) => (
            <div key={i} className="bg-white/[0.02] rounded-xl p-4">
              <p className="text-white font-semibold mb-3">{i+1}. {q.question}</p>
              <div className="space-y-2">
                {q.options.map((opt: string, oi: number) => (
                  <label key={oi} className="flex items-center gap-3 cursor-pointer p-2 rounded-lg hover:bg-white/[0.04] transition-colors">
                    <input type="radio" name={`q${i}`} value={oi} checked={selected[i] === oi}
                      onChange={() => setSelected({...selected, [i]: oi})}
                      className="accent-indigo-500" />
                    <span className="text-slate-300 text-sm">{opt}</span>
                  </label>
                ))}
              </div>
            </div>
          ))}
          <button onClick={handleSubmit}
            className="w-full py-3 bg-gradient-to-r from-indigo-500 to-indigo-400 text-white font-bold rounded-xl hover:opacity-90 transition-all">
            تسليم الإجابات
          </button>
        </div>
      )}

      {submitted && (
        <div className="text-center py-8">
          <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-indigo-500/20 flex items-center justify-center">
            <CheckCircle2 size={36} className="text-indigo-400" />
          </div>
          <p className="text-2xl font-bold text-white mb-2">{score}/{questions.length}</p>
          <p className="text-slate-400">درجتك في الكويز</p>
          <button onClick={() => { setQuestions([]); setSubmitted(false); setSelected({}); setScore(0); }}
            className="mt-4 px-6 py-2 bg-white/[0.05] border border-white/[0.08] text-white text-sm rounded-xl hover:bg-white/[0.08] transition-all">
            إعادة
          </button>
        </div>
      )}
    </div>
  )
}
