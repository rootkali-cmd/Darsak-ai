'use client'

import { motion } from 'framer-motion'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Check, X, Minus, Loader2, Users, Calendar } from 'lucide-react'
import toast from 'react-hot-toast'
import { GlassCard, NeonButton, Section, CountUp } from '@/components/ui'
import { attendanceApi, studentsApi, groupsApi } from '@/lib/api'

export default function AttendancePage() {
  const [selectedGroup, setSelectedGroup] = useState('')
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0])
  const [attendanceRecords, setAttendanceRecords] = useState<Record<string, string>>({})
  const queryClient = useQueryClient()

  const { data: students } = useQuery({ queryKey: ['students'], queryFn: () => studentsApi.list().then((r) => r.data) })
  const { data: groups } = useQuery({ queryKey: ['groups'], queryFn: () => groupsApi.list().then((r) => r.data) })
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
    present: { icon: Check, color: 'bg-accent-green/20 text-accent-green border-accent-green/30', label: 'حاضر' },
    absent: { icon: X, color: 'bg-danger/20 text-danger border-danger/30', label: 'غائب' },
    cancelled: { icon: Minus, color: 'bg-warning/20 text-warning border-warning/30', label: 'ملغي' },
  }

  return (
    <div className="space-y-6">
      <Section>
        <h1 className="text-3xl font-bold">الحضور والغياب</h1>
        <p className="text-text-secondary mt-1">تسجيل ومتابعة حضور الطلاب</p>
      </Section>

      <Section delay={0.1}>
        <GlassCard>
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <label className="block text-sm text-text-muted mb-2">المجموعة</label>
              <select value={selectedGroup} onChange={(e) => setSelectedGroup(e.target.value)} className="input-glass w-full px-4 py-3 rounded-xl text-white">
                <option value="">جميع المجموعات</option>
                {groups?.map((g: any) => <option key={g.id} value={g.id}>{g.name}</option>)}
              </select>
            </div>
            <div className="flex-1">
              <label className="block text-sm text-text-muted mb-2">التاريخ</label>
              <input type="date" value={selectedDate} onChange={(e) => setSelectedDate(e.target.value)} className="input-glass w-full px-4 py-3 rounded-xl text-white" />
            </div>
          </div>
        </GlassCard>
      </Section>

      {attendanceStats && (
        <div className="grid grid-cols-3 gap-4">
          <Section delay={0.2}><GlassCard className="text-center border-accent-green/20"><div className="text-4xl font-black text-accent-green"><CountUp end={attendanceStats.present} /></div><p className="text-text-muted text-sm mt-1">حاضر</p></GlassCard></Section>
          <Section delay={0.3}><GlassCard className="text-center border-danger/20"><div className="text-4xl font-black text-danger"><CountUp end={attendanceStats.absent} /></div><p className="text-text-muted text-sm mt-1">غائب</p></GlassCard></Section>
          <Section delay={0.4}><GlassCard className="text-center border-warning/20"><div className="text-4xl font-black text-warning"><CountUp end={attendanceStats.cancelled} /></div><p className="text-text-muted text-sm mt-1">ملغي</p></GlassCard></Section>
        </div>
      )}

      <Section delay={0.3}>
        <GlassCard>
          <h2 className="text-lg font-bold mb-4 flex items-center gap-2">
            <Users className="w-5 h-5 text-primary" />
            قائمة الطلاب
          </h2>
          <div className="space-y-3">
            {filteredStudents?.map((student: any, index: number) => {
              const currentStatus = attendanceRecords[student.id]
              return (
                <motion.div key={student.id} initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: index * 0.05 }} className="flex items-center justify-between p-4 rounded-xl bg-bg-secondary/50 border border-white/5 hover:border-white/10 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-neon-gradient flex items-center justify-center">
                      <span className="text-white font-bold text-sm">{student.full_name.charAt(0)}</span>
                    </div>
                    <div>
                      <p className="font-medium">{student.full_name}</p>
                      <p className="text-sm text-text-muted font-mono">{student.code}</p>
                    </div>
                  </div>
                  <div className="flex gap-2">
                    {Object.entries(statusConfig).map(([status, config]) => {
                      const Icon = config.icon
                      const isActive = currentStatus === status
                      return (
                        <motion.button key={status} whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} onClick={() => handleMarkAttendance(student.id, status)} className={`flex items-center gap-1.5 px-3 py-2 rounded-lg border text-sm font-medium transition-all ${isActive ? config.color : 'bg-bg-card text-text-muted border-white/5 hover:border-primary/30'}`}>
                          <Icon className="w-4 h-4" />
                          <span className="hidden sm:inline">{config.label}</span>
                        </motion.button>
                      )
                    })}
                  </div>
                </motion.div>
              )
            })}
          </div>
          {(!filteredStudents || filteredStudents.length === 0) && <div className="text-center py-8 text-text-muted">لا يوجد طلاب</div>}
        </GlassCard>
      </Section>
    </div>
  )
}
