'use client'

import { motion } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Check, X, Minus, Loader2, Users } from 'lucide-react'
import toast from 'react-hot-toast'
import { Section } from '@/components/ui'
import { attendanceApi, studentsApi, groupsApi } from '@/lib/api'

export default function AttendancePage() {
  const [selectedGroup, setSelectedGroup] = useState('')
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0])
  const [attendanceRecords, setAttendanceRecords] = useState<Record<string, string>>({})
  const queryClient = useQueryClient()

  const { data: students } = useQuery({
    queryKey: ['students'],
    queryFn: () => studentsApi.list().then((r) => r.data),
    select: (data: any[]) => {
      const seen = new Set<string>()
      return data.filter((s: any) => { const k = s.code || s.id; if (seen.has(k)) return false; seen.add(k); return true })
    },
  })
  const { data: groups } = useQuery({
    queryKey: ['groups'],
    queryFn: () => groupsApi.list().then((r) => r.data),
    select: (data: any[]) => {
      const seen = new Set<string>()
      return data.filter((g: any) => { const k = g.id || g.name; if (seen.has(k)) return false; seen.add(k); return true })
    },
  })
  const { data: attendanceStats } = useQuery({ queryKey: ['attendance-stats', selectedDate], queryFn: () => attendanceApi.stats({ date: selectedDate }).then((r) => r.data) })

  const markMutation = useMutation({
    mutationFn: (data: { student_id: string; status: string; group_id?: string; date?: string }) => attendanceApi.mark(data),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['attendance-stats'] }); toast.success('تم تسجيل الحضور ') },
    onError: () => toast.error('فشل تسجيل الحضور'),
  })

  const handleMarkAttendance = (studentId: string, status: string) => {
    setAttendanceRecords((prev) => ({ ...prev, [studentId]: status }))
    markMutation.mutate({ student_id: studentId, status, group_id: selectedGroup || undefined, date: selectedDate })
  }

  const filteredStudents = students?.filter((s: any) => !selectedGroup || s.group_id === selectedGroup)

  const statusConfig = {
    present: { icon: Check, color: 'bg-green-500/20 text-green-500 border-green-500/30', label: 'حاضر' },
    absent: { icon: X, color: 'bg-red-500/20 text-red-500 border-red-500/30', label: 'غائب' },
    cancelled: { icon: Minus, color: 'bg-yellow-500/20 text-yellow-500 border-yellow-500/30', label: 'ملغي' },
  }

  return (
    <div className="space-y-6">
      <Section>
        <h1 className="text-2xl md:text-3xl font-bold">الحضور والغياب</h1>
        <p className="text-[var(--text-muted)] mt-1">تسجيل ومتابعة حضور الطلاب</p>
      </Section>

      <Section delay={0.1}>
        <div className="card p-5">
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <label className="block text-xs text-[var(--text-muted)] mb-1.5">المجموعة</label>
              <select value={selectedGroup} onChange={(e) => setSelectedGroup(e.target.value)} className="input">
                <option value="">جميع المجموعات</option>
                {groups?.map((g: any) => <option key={g.id} value={g.id}>{g.name}</option>)}
              </select>
            </div>
            <div className="flex-1">
              <label className="block text-xs text-[var(--text-muted)] mb-1.5">التاريخ</label>
              <input type="date" value={selectedDate} onChange={(e) => setSelectedDate(e.target.value)} className="input" />
            </div>
          </div>
        </div>
      </Section>

      {attendanceStats && (
        <div className="grid grid-cols-3 gap-2 md:gap-4">
          <Section delay={0.2}><div className="card p-5 text-center" style={{ borderColor: 'rgba(34,197,94,0.2)' }}><div className="text-2xl font-bold text-green-500">{attendanceStats.present}</div><p className="text-xs text-[var(--text-muted)] mt-1">حاضر</p></div></Section>
          <Section delay={0.3}><div className="card p-5 text-center" style={{ borderColor: 'rgba(239,68,68,0.2)' }}><div className="text-2xl font-bold text-red-500">{attendanceStats.absent}</div><p className="text-xs text-[var(--text-muted)] mt-1">غائب</p></div></Section>
          <Section delay={0.4}><div className="card p-5 text-center" style={{ borderColor: 'rgba(234,179,8,0.2)' }}><div className="text-2xl font-bold text-yellow-500">{attendanceStats.cancelled}</div><p className="text-xs text-[var(--text-muted)] mt-1">ملغي</p></div></Section>
        </div>
      )}

      <Section delay={0.3}>
        <div className="card p-5">
          <h2 className="text-sm font-bold text-[var(--text-muted)] mb-4">قائمة الطلاب</h2>
          <div className="space-y-2">
            {filteredStudents?.map((student: any, index: number) => {
              const currentStatus = attendanceRecords[student.id]
              return (
                <div key={student.id} className="flex items-center justify-between p-3 border" style={{ borderColor: 'var(--card-border)' }}>
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-[rgba(255,0,60,0.1)] flex items-center justify-center">
                      <span className="text-[var(--accent)] font-bold text-sm">{student.full_name.charAt(0)}</span>
                    </div>
                    <div>
                      <p className="text-sm font-medium">{student.full_name}</p>
                      <p className="text-xs text-[var(--text-muted)]" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{student.code}</p>
                    </div>
                  </div>
                  <div className="flex gap-1.5">
                    {Object.entries(statusConfig).map(([status, config]) => {
                      const Icon = config.icon
                      const isActive = currentStatus === status
                      return (
                        <button key={status} onClick={() => handleMarkAttendance(student.id, status)} className={`flex items-center gap-1 px-2.5 py-1.5 text-xs border transition-colors ${isActive ? config.color : 'text-[var(--text-muted)] border-[var(--card-border)] hover:border-[var(--accent)]'}`}>
                          <Icon size={14} />
                          <span className="hidden sm:inline">{config.label}</span>
                        </button>
                      )
                    })}
                  </div>
                </div>
              )
            })}
          </div>
          {(!filteredStudents || filteredStudents.length === 0) && <div className="text-center py-8 text-[var(--text-muted)]">لا يوجد طلاب</div>}
        </div>
      </Section>
    </div>
  )
}
