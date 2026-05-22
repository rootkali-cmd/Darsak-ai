'use client'

import { motion } from 'framer-motion'
import { useQuery } from '@tanstack/react-query'
import {
  Users,
  GraduationCap,
  CalendarCheck,
  TrendingUp,
  ArrowUpRight,
  ArrowDownRight,
  Sparkles,
  Zap,
  Brain,
  Target,
} from 'lucide-react'
import { GlassCard, CountUp, Section } from '@/components/ui'
import { FloatingOrb, OrbScene } from '@/components/3d'
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
      gradient: 'from-primary to-accent-cyan',
      shadow: 'shadow-[0_0_30px_rgba(255,0,60,0.3)]',
      change: '+12%',
      positive: true,
    },
    {
      label: 'متوسط الدرجات',
      value: gradeStats?.average ? Math.round(gradeStats.average) : 0,
      suffix: '%',
      icon: TrendingUp,
      gradient: 'from-accent-green to-accent-cyan',
      shadow: 'shadow-[0_0_30px_rgba(0,243,255,0.3)]',
      change: '+5%',
      positive: true,
    },
    {
      label: 'حضور اليوم',
      value: attendanceStats?.present || 0,
      icon: CalendarCheck,
      gradient: 'from-accent-orange to-warning',
      shadow: 'shadow-[0_0_30px_rgba(245,158,11,0.3)]',
      change: '-2%',
      positive: false,
    },
    {
      label: 'إجمالي الامتحانات',
      value: gradeStats?.total || 0,
      icon: GraduationCap,
      gradient: 'from-accent-cyan to-primary',
      shadow: 'shadow-[0_0_30px_rgba(255,0,60,0.3)]',
      change: '+8%',
      positive: true,
    },
  ]

  return (
    <div className="space-y-8">
      {/* Welcome Section */}
      <Section>
        <motion.div
          className="relative overflow-hidden rounded-2xl p-8 md:p-10"
          style={{
            background: 'linear-gradient(135deg, rgba(255,0,60,0.15) 0%, rgba(0,243,255,0.1) 50%, rgba(0,0,0,0.05) 100%)',
            border: '1px solid rgba(255,0,60,0.2)',
          }}
        >
          <div className="relative z-10">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
            >
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full glass mb-4">
                <Sparkles className="w-4 h-4 text-primary" />
                <span className="text-sm text-primary">مرحباً بك</span>
              </div>
              <h1 className="text-3xl md:text-4xl font-bold mb-3">
                لوحة التحكم{' '}
                <span className="neon-text">الذكية</span>
              </h1>
              <p className="text-text-secondary text-lg max-w-xl">
                نظرة شاملة على أداء طلابك وفصولك مع تحليلات ذكية بالـ AI
              </p>
            </motion.div>
          </div>

          {/* 3D Orbs */}
          <div className="absolute left-0 top-0 w-72 h-full opacity-30 pointer-events-none">
            <OrbScene>
              <FloatingOrb position={[0, 0, 0]} color="#ff003c" size={1.5} distort={0.5} />
              <FloatingOrb position={[3, 1, -1]} color="#00f3ff" size={0.8} distort={0.3} speed={2} />
            </OrbScene>
          </div>

          {/* Decorative gradient */}
          <div className="absolute -right-20 -top-20 w-64 h-64 bg-primary/20 rounded-full blur-3xl" />
          <div className="absolute -left-20 -bottom-20 w-48 h-48 bg-secondary/20 rounded-full blur-3xl" />
        </motion.div>
      </Section>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat, index) => {
          const Icon = stat.icon
          return (
            <Section key={stat.label} delay={index * 0.1}>
              <GlassCard delay={index * 0.1} className="relative overflow-hidden group">
                <div className="flex items-start justify-between mb-4">
                  <motion.div
                    whileHover={{ scale: 1.1, rotate: 5 }}
                    className={`p-3 rounded-xl bg-gradient-to-br ${stat.gradient} ${stat.shadow}`}
                  >
                    <Icon className="w-6 h-6 text-white" />
                  </motion.div>
                  <div className={`flex items-center gap-1 text-sm ${stat.positive ? 'text-accent-green' : 'text-danger'}`}>
                    {stat.positive ? (
                      <ArrowUpRight className="w-4 h-4" />
                    ) : (
                      <ArrowDownRight className="w-4 h-4" />
                    )}
                    {stat.change}
                  </div>
                </div>
                <div className="text-3xl font-black mb-1 neon-text">
                  <CountUp end={stat.value} suffix={stat.suffix || ''} />
                </div>
                <p className="text-text-secondary text-sm">{stat.label}</p>

                {/* Glow effect on hover */}
                <div className={`absolute -bottom-4 -right-4 w-24 h-24 bg-gradient-to-br ${stat.gradient} opacity-0 group-hover:opacity-10 rounded-full blur-2xl transition-opacity duration-500`} />
              </GlassCard>
            </Section>
          )
        })}
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Attendance Chart */}
        <Section delay={0.2}>
          <GlassCard>
            <div className="flex items-center gap-3 mb-6">
              <div className="p-2 rounded-lg bg-accent-green/10">
                <CalendarCheck className="w-5 h-5 text-accent-green" />
              </div>
              <h2 className="text-lg font-bold">الحضور الأسبوعي</h2>
            </div>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData}>
                  <defs>
                    <linearGradient id="colorAttendance" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#ff003c" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#ff003c" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                  <XAxis dataKey="name" stroke="var(--text-muted)" fontSize={12} />
                  <YAxis stroke="var(--text-muted)" fontSize={12} />
                  <Tooltip
                    contentStyle={{
                      background: 'var(--card-bg)',
                      border: '1px solid var(--border)',
                      borderRadius: '12px',
                      color: 'var(--text)',
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="attendance"
                    stroke="#ff003c"
                    strokeWidth={3}
                    fill="url(#colorAttendance)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </GlassCard>
        </Section>

        {/* Students Chart */}
        <Section delay={0.3}>
          <GlassCard>
            <div className="flex items-center gap-3 mb-6">
              <div className="p-2 rounded-lg bg-accent-orange/10">
                <Users className="w-5 h-5 text-accent-orange" />
              </div>
              <h2 className="text-lg font-bold">الطلاب الجدد</h2>
            </div>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                  <XAxis dataKey="name" stroke="var(--text-muted)" fontSize={12} />
                  <YAxis stroke="var(--text-muted)" fontSize={12} />
                  <Tooltip
                    contentStyle={{
                      background: 'var(--card-bg)',
                      border: '1px solid var(--border)',
                      borderRadius: '12px',
                      color: 'var(--text)',
                    }}
                  />
                  <Bar dataKey="students" fill="#00f3ff" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </GlassCard>
        </Section>
      </div>

      {/* Quick Actions */}
      <Section delay={0.4}>
        <GlassCard>
          <h2 className="text-lg font-bold mb-6 flex items-center gap-2">
            <Zap className="w-5 h-5 text-warning" />
            إجراءات سريعة
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'إضافة طالب', href: '/dashboard/students', gradient: 'from-primary to-primary', icon: Users },
              { label: 'تسجيل حضور', href: '/dashboard/attendance', gradient: 'from-accent-green to-accent-cyan', icon: CalendarCheck },
              { label: 'رفع درجات', href: '/dashboard/grades', gradient: 'from-accent-orange to-warning', icon: GraduationCap },
              { label: 'تحليل AI', href: '/dashboard/students', gradient: 'from-secondary to-primary', icon: Brain },
            ].map((action, index) => {
              const Icon = action.icon
              return (
                <motion.a
                  key={action.label}
                  href={action.href}
                  whileHover={{ scale: 1.05, y: -5 }}
                  whileTap={{ scale: 0.95 }}
                  className="flex flex-col items-center gap-3 p-6 rounded-xl glass-card hover:border-primary/30 transition-all cursor-pointer group"
                >
                  <motion.div
                    whileHover={{ rotate: 360 }}
                    transition={{ duration: 0.5 }}
                    className={`w-12 h-12 rounded-xl bg-gradient-to-br ${action.gradient} flex items-center justify-center shadow-lg group-hover:shadow-neon transition-shadow`}
                  >
                    <Icon className="w-6 h-6 text-white" />
                  </motion.div>
                  <span className="font-medium text-sm text-center">{action.label}</span>
                </motion.a>
              )
            })}
          </div>
        </GlassCard>
      </Section>
    </div>
  )
}
