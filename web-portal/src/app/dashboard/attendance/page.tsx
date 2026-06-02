'use client'

import { motion } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, useEffect } from 'react'
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
  const { data: existingAttendance } = useQuery({
    queryKey: ['attendance', selectedDate, selectedGroup],
    queryFn: () => attendanceApi.list({ group_id: selectedGroup || undefined, from_date: selectedDate, to_date: selectedDate }).then((r) => r.data),
    enabled: !!selectedDate,
  })
  const { data: attendanceStats } = useQuery({
    queryKey: ['attendance-stats', selectedDate, selectedGroup],
    queryFn: () => attendanceApi.stats({ date: selectedDate, group_id: selectedGroup || undefined }).then((r) => r.data),
  })

  useEffect(() => {
    setAttendanceRecords({})
  }, [selectedDate, selectedGroup])

  useEffect(() => {
    if (existingAttendance && existingAttendance.length > 0) {
      const records: Record<string, string> = {}
      for (const rec of existingAttendance) {
        records[rec.student_id] = rec.status
      }
      setAttendanceRecords(records)
    }
  }, [existingAttendance])

  const markMutation = useMutation({
    mutationFn: (data: { student_id: string; status: string; group_id?: string; date?: string }) => attendanceApi.mark(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['attendance-stats', selectedDate, selectedGroup] })
      queryClient.invalidateQueries({ queryKey: ['attendance', selectedDate, selectedGroup] })
      toast.success('تم تسجيل الحضور ')
    },
    onError: () => toast.error('فشل تسجيل الحضور'),
  })

  const handleMarkAttendance = (studentId: string, status: string) => {
    setAttendanceRecords((prev) => ({ ...prev, [studentId]: status }))
    markMutation.mutate({ student_id: studentId, status, group_id: selectedGroup || undefined, date: selectedDate })
  }

  const filteredStudents = students?.filter((s: any) => !selectedGroup || s.group_id === selectedGroup)

  const statusConfig = {
    present: { icon: Check, activeClass: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', label: 'حاضر' },
    absent: { icon: X, activeClass: 'bg-red-500/20 text-red-400 border-red-500/30', label: 'غائب' },
    cancelled: { icon: Minus, activeClass: 'bg-amber-500/20 text-amber-400 border-amber-500/30', label: 'ملغي' },
  }

  return (
    <div className="relative space-y-6">
      <div className="fixed inset-0 bg-gradient-to-b from-[#0F172A] via-[#1E293B] to-[#0F172A] -z-10 pointer-events-none" />
      <div className="fixed inset-0 -z-10 pointer-events-none overflow-hidden">
        <div className="absolute -top-40 -right-40 w-[500px] h-[500px] bg-indigo-500/20 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-[500px] h-[500px] bg-indigo-600/10 rounded-full blur-3xl" />
        <div className="absolute top-1/3 left-1/4 w-[300px] h-[300px] bg-purple-500/10 rounded-full blur-3xl" />
      </div>

      <Section>
        <h1 className="text-2xl md:text-3xl font-bold text-white">الحضور والغياب</h1>
        <p className="text-slate-400 mt-1">تسجيل ومتابعة حضور الطلاب</p>
      </Section>

      <Section delay={0.1}>
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5">
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <label className="block text-xs text-slate-500 mb-1.5">المجموعة</label>
              <select value={selectedGroup} onChange={(e) => setSelectedGroup(e.target.value)} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white outline-none focus:border-indigo-500/50 transition-colors">
                <option value="" className="bg-[#1E293B]">جميع المجموعات</option>
                {groups?.map((g: any) => <option key={g.id} value={g.id} className="bg-[#1E293B]">{g.name}</option>)}
              </select>
            </div>
            <div className="flex-1">
              <label className="block text-xs text-slate-500 mb-1.5">التاريخ</label>
              <input type="date" value={selectedDate} onChange={(e) => setSelectedDate(e.target.value)} className="w-full px-4 py-3 bg-white/[0.05] border border-white/[0.08] rounded-xl text-white outline-none focus:border-indigo-500/50 transition-colors [color-scheme:dark]" />
            </div>
          </div>
        </div>
      </Section>

      {attendanceStats && (
        <div className="grid grid-cols-3 gap-2 md:gap-4">
          <Section delay={0.2}>
            <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] border-l-4 border-l-emerald-500 rounded-2xl p-5 text-center">
              <div className="text-2xl font-bold text-emerald-400">{attendanceStats.present}</div>
              <p className="text-xs text-slate-500 mt-1">حاضر</p>
            </div>
          </Section>
          <Section delay={0.3}>
            <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] border-l-4 border-l-red-500 rounded-2xl p-5 text-center">
              <div className="text-2xl font-bold text-red-400">{attendanceStats.absent}</div>
              <p className="text-xs text-slate-500 mt-1">غائب</p>
            </div>
          </Section>
          <Section delay={0.4}>
            <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] border-l-4 border-l-amber-500 rounded-2xl p-5 text-center">
              <div className="text-2xl font-bold text-amber-400">{attendanceStats.cancelled}</div>
              <p className="text-xs text-slate-500 mt-1">ملغي</p>
            </div>
          </Section>
        </div>
      )}

      <Section delay={0.3}>
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5">
          <h2 className="text-sm font-bold text-slate-400 mb-4">قائمة الطلاب</h2>
          <div className="space-y-2">
            {filteredStudents?.map((student: any, index: number) => {
              const currentStatus = attendanceRecords[student.id]
              return (
                <div key={student.id} className="flex items-center justify-between p-3 border border-white/[0.06] rounded-xl">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-indigo-500/10 flex items-center justify-center">
                      <span className="text-indigo-400 font-bold text-sm">{student.full_name.charAt(0)}</span>
                    </div>
                    <div>
                      <p className="text-sm font-medium text-white">{student.full_name}</p>
                      <p className="text-xs text-slate-500" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{student.code}</p>
                    </div>
                  </div>
                  <div className="flex gap-1.5">
                    {Object.entries(statusConfig).map(([status, config]) => {
                      const Icon = config.icon
                      const isActive = currentStatus === status
                      return (
                        <button key={status} onClick={() => handleMarkAttendance(student.id, status)} className={`flex items-center gap-1 px-2.5 py-1.5 text-xs border rounded-lg transition-colors ${isActive ? config.activeClass : 'text-slate-500 border-white/[0.06] hover:border-indigo-500/50 hover:text-indigo-400'}`}>
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
          {(!filteredStudents || filteredStudents.length === 0) && <div className="text-center py-8 text-slate-500">لا يوجد طلاب</div>}
        </div>
      </Section>
    </div>
  )
}
