'use client'

import { useQuery } from '@tanstack/react-query'
import {
  Users,
  GraduationCap,
  CalendarCheck,
  TrendingUp,
  ArrowUpRight,
  ArrowDownRight,
} from 'lucide-react'
import { Section } from '@/components/ui'
import { studentsApi, gradesApi, attendanceApi } from '@/lib/api'
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
} from 'recharts'

const chartData = [
  { name: 'السبت', students: 12, attendance: 10 },
  { name: 'الأحد', students: 15, attendance: 13 },
  { name: 'الاثنين', students: 18, attendance: 16 },
  { name: 'الثلاثاء', students: 14, attendance: 12 },
  { name: 'الأربعاء', students: 20, attendance: 18 },
  { name: 'الخميس', students: 16, attendance: 14 },
]

export default function DashboardPage() {
  const { data: studentsCount } = useQuery({
    queryKey: ['students-count'],
    queryFn: () => studentsApi.count().then((r) => r.data.count),
  })

  const { data: gradeStats } = useQuery({
    queryKey: ['grade-stats'],
    queryFn: () => gradesApi.stats().then((r) => r.data),
  })

  const { data: attendanceStats } = useQuery({
    queryKey: ['attendance-stats'],
    queryFn: () => attendanceApi.stats().then((r) => r.data),
  })

  const stats = [
    {
      label: 'إجمالي الطلاب',
      value: studentsCount || 0,
      icon: Users,
      change: '+12%',
      positive: true,
      borderColor: 'border-l-indigo-500',
      iconBg: 'bg-indigo-500/10',
      iconColor: 'text-indigo-400',
    },
    {
      label: 'متوسط الدرجات',
      value: gradeStats?.average ? Math.round(gradeStats.average) : 0,
      suffix: '%',
      icon: TrendingUp,
      change: '+5%',
      positive: true,
      borderColor: 'border-l-emerald-500',
      iconBg: 'bg-emerald-500/10',
      iconColor: 'text-emerald-400',
    },
    {
      label: 'حضور اليوم',
      value: attendanceStats?.present || 0,
      icon: CalendarCheck,
      change: '-2%',
      positive: false,
      borderColor: 'border-l-amber-500',
      iconBg: 'bg-amber-500/10',
      iconColor: 'text-amber-400',
    },
    {
      label: 'إجمالي الامتحانات',
      value: gradeStats?.total || 0,
      icon: GraduationCap,
      change: '+8%',
      positive: true,
      borderColor: 'border-l-violet-500',
      iconBg: 'bg-violet-500/10',
      iconColor: 'text-violet-400',
    },
  ]

  return (
    <div className="space-y-8">

      <Section>
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 md:p-8">
          <h1 className="text-2xl md:text-3xl font-bold text-white mb-2">لوحة التحكم</h1>
          <p className="text-slate-400">نظرة شاملة على أداء طلابك وفصولك</p>
        </div>
      </Section>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        {stats.map((stat, index) => {
          const Icon = stat.icon
          return (
            <Section key={stat.label} delay={index * 0.08}>
              <div className={`bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5 border-l-4 ${stat.borderColor}`}>
                <div className="flex items-start justify-between mb-3">
                  <div className={`p-2 rounded-lg ${stat.iconBg}`}>
                    <Icon size={20} className={stat.iconColor} />
                  </div>
                  <div className={`flex items-center gap-1 text-xs ${stat.positive ? 'text-emerald-400' : 'text-red-400'}`}>
                    {stat.positive ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
                    {stat.change}
                  </div>
                </div>
                <div className="text-2xl font-bold text-white mb-0.5" style={{ fontFamily: "'JetBrains Mono', monospace" }}>
                  {stat.value}{stat.suffix || ''}
                </div>
                <p className="text-xs text-slate-400">{stat.label}</p>
              </div>
            </Section>
          )
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <Section delay={0.15}>
          <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5">
            <h2 className="text-sm font-bold mb-5 text-slate-400">الحضور الأسبوعي</h2>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData}>
                  <defs>
                    <linearGradient id="colorAttendance" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#6366f1" stopOpacity={0.2} />
                      <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                  <XAxis dataKey="name" stroke="#64748b" fontSize={11} />
                  <YAxis stroke="#64748b" fontSize={11} />
                  <Tooltip
                    contentStyle={{
                      background: '#1E293B',
                      border: '1px solid rgba(255,255,255,0.08)',
                      borderRadius: '12px',
                      color: '#fff',
                      fontSize: '12px',
                    }}
                  />
                  <Area type="monotone" dataKey="attendance" stroke="#6366f1" strokeWidth={2} fill="url(#colorAttendance)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </Section>

        <Section delay={0.2}>
          <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5">
            <h2 className="text-sm font-bold mb-5 text-slate-400">الطلاب الجدد</h2>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                  <XAxis dataKey="name" stroke="#64748b" fontSize={11} />
                  <YAxis stroke="#64748b" fontSize={11} />
                  <Tooltip
                    contentStyle={{
                      background: '#1E293B',
                      border: '1px solid rgba(255,255,255,0.08)',
                      borderRadius: '12px',
                      color: '#fff',
                      fontSize: '12px',
                    }}
                  />
                  <Bar dataKey="students" fill="#818cf8" radius={[2, 2, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </Section>
      </div>

      <Section delay={0.25}>
        <div className="bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-5">
          <h2 className="text-sm font-bold mb-5 text-slate-400">إجراءات سريعة</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'إضافة طالب', href: '/dashboard/students', icon: Users, iconBg: 'bg-indigo-500/10', iconColor: 'text-indigo-400' },
              { label: 'تسجيل حضور', href: '/dashboard/attendance', icon: CalendarCheck, iconBg: 'bg-emerald-500/10', iconColor: 'text-emerald-400' },
              { label: 'رفع درجات', href: '/dashboard/grades', icon: GraduationCap, iconBg: 'bg-amber-500/10', iconColor: 'text-amber-400' },
              { label: 'تحليل AI', href: '/dashboard/students', icon: TrendingUp, iconBg: 'bg-violet-500/10', iconColor: 'text-violet-400' },
            ].map((action) => {
              const Icon = action.icon
              return (
                <a
                  key={action.label}
                  href={action.href}
                  className="flex flex-col items-center gap-3 p-5 bg-white/[0.03] backdrop-blur-sm border border-white/[0.08] rounded-2xl hover:border-indigo-500/50 transition-colors"
                >
                  <div className={`p-2.5 rounded-lg ${action.iconBg}`}>
                    <Icon size={22} className={action.iconColor} />
                  </div>
                  <span className="text-sm font-medium text-white">{action.label}</span>
                </a>
              )
            })}
          </div>
        </div>
      </Section>
    </div>
  )
}
