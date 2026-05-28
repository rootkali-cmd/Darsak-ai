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
    },
    {
      label: 'متوسط الدرجات',
      value: gradeStats?.average ? Math.round(gradeStats.average) : 0,
      suffix: '%',
      icon: TrendingUp,
      change: '+5%',
      positive: true,
    },
    {
      label: 'حضور اليوم',
      value: attendanceStats?.present || 0,
      icon: CalendarCheck,
      change: '-2%',
      positive: false,
    },
    {
      label: 'إجمالي الامتحانات',
      value: gradeStats?.total || 0,
      icon: GraduationCap,
      change: '+8%',
      positive: true,
    },
  ]

  return (
    <div className="space-y-8">
      <Section>
        <div className="p-6 md:p-8 card" style={{ borderColor: 'rgba(255,0,60,0.2)' }}>
          <h1 className="text-2xl md:text-3xl font-bold mb-2">لوحة التحكم</h1>
          <p className="text-[var(--text-muted)]">نظرة شاملة على أداء طلابك وفصولك</p>
        </div>
      </Section>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        {stats.map((stat, index) => {
          const Icon = stat.icon
          return (
            <Section key={stat.label} delay={index * 0.08}>
              <div className="card p-5">
                <div className="flex items-start justify-between mb-3">
                  <div className="p-2 bg-[rgba(255,0,60,0.08)]">
                    <Icon size={20} className="text-[var(--accent)]" />
                  </div>
                  <div className={`flex items-center gap-1 text-xs ${stat.positive ? 'text-green-500' : 'text-red-500'}`}>
                    {stat.positive ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
                    {stat.change}
                  </div>
                </div>
                <div className="text-2xl font-bold mb-0.5" style={{ fontFamily: "'JetBrains Mono', monospace" }}>
                  {stat.value}{stat.suffix || ''}
                </div>
                <p className="text-xs text-[var(--text-muted)]">{stat.label}</p>
              </div>
            </Section>
          )
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <Section delay={0.15}>
          <div className="card p-5">
            <h2 className="text-sm font-bold mb-5 text-[var(--text-muted)]">الحضور الأسبوعي</h2>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData}>
                  <defs>
                    <linearGradient id="colorAttendance" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#ff003c" stopOpacity={0.2} />
                    <stop offset="95%" stopColor="#ff003c" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--card-border)" />
                  <XAxis dataKey="name" stroke="var(--text-muted)" fontSize={11} />
                  <YAxis stroke="var(--text-muted)" fontSize={11} />
                  <Tooltip
                    contentStyle={{
                      background: 'var(--card-bg)',
                      border: '1px solid var(--card-border)',
                      color: 'var(--text)',
                      fontSize: '12px',
                    }}
                  />
                  <Area type="monotone" dataKey="attendance" stroke="#ff003c" strokeWidth={2} fill="url(#colorAttendance)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </Section>

        <Section delay={0.2}>
          <div className="card p-5">
            <h2 className="text-sm font-bold mb-5 text-[var(--text-muted)]">الطلاب الجدد</h2>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--card-border)" />
                  <XAxis dataKey="name" stroke="var(--text-muted)" fontSize={11} />
                  <YAxis stroke="var(--text-muted)" fontSize={11} />
                  <Tooltip
                    contentStyle={{
                      background: 'var(--card-bg)',
                      border: '1px solid var(--card-border)',
                      color: 'var(--text)',
                      fontSize: '12px',
                    }}
                  />
                  <Bar dataKey="students" fill="#00f3ff" radius={[2, 2, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </Section>
      </div>

      <Section delay={0.25}>
        <div className="card p-5">
          <h2 className="text-sm font-bold mb-5 text-[var(--text-muted)]">إجراءات سريعة</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'إضافة طالب', href: '/dashboard/students', icon: Users },
              { label: 'تسجيل حضور', href: '/dashboard/attendance', icon: CalendarCheck },
              { label: 'رفع درجات', href: '/dashboard/grades', icon: GraduationCap },
              { label: 'تحليل AI', href: '/dashboard/students', icon: TrendingUp },
            ].map((action) => {
              const Icon = action.icon
              return (
                <a
                  key={action.label}
                  href={action.href}
                  className="flex flex-col items-center gap-3 p-5 card hover:border-[var(--accent)] transition-colors"
                >
                  <div className="p-2.5 bg-[rgba(255,0,60,0.08)]">
                    <Icon size={22} className="text-[var(--accent)]" />
                  </div>
                  <span className="text-sm font-medium">{action.label}</span>
                </a>
              )
            })}
          </div>
        </div>
      </Section>
    </div>
  )
}
