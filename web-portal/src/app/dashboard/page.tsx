'use client'

import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import {
  Users,
  GraduationCap,
  CalendarCheck,
  TrendingUp,
  ArrowUpRight,
  ArrowDownRight,
  BookOpen,
  Brain,
  BarChart3,
  UserPlus,
  ClipboardList,
  Sparkles,
} from 'lucide-react'
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

const fadeInUp = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.5 },
}

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
      gradient: 'from-indigo-500 to-blue-600',
      glow: 'shadow-indigo-500/20',
    },
    {
      label: 'متوسط الدرجات',
      value: gradeStats?.average ? Math.round(gradeStats.average) : 0,
      suffix: '%',
      icon: TrendingUp,
      change: '+5%',
      positive: true,
      gradient: 'from-emerald-500 to-teal-600',
      glow: 'shadow-emerald-500/20',
    },
    {
      label: 'حضور اليوم',
      value: attendanceStats?.present || 0,
      icon: CalendarCheck,
      change: '-2%',
      positive: false,
      gradient: 'from-amber-500 to-orange-600',
      glow: 'shadow-amber-500/20',
    },
    {
      label: 'إجمالي الامتحانات',
      value: gradeStats?.total || 0,
      icon: GraduationCap,
      change: '+8%',
      positive: true,
      gradient: 'from-violet-500 to-purple-600',
      glow: 'shadow-violet-500/20',
    },
  ]

  const quickActions = [
    { label: 'إضافة طالب', href: '/dashboard/students', icon: UserPlus, gradient: 'from-indigo-500 to-blue-600' },
    { label: 'تسجيل حضور', href: '/dashboard/attendance', icon: ClipboardList, gradient: 'from-emerald-500 to-teal-600' },
    { label: 'رفع درجات', href: '/dashboard/grades', icon: BookOpen, gradient: 'from-amber-500 to-orange-600' },
    { label: 'تحليل AI', href: '/dashboard/students', icon: Brain, gradient: 'from-violet-500 to-purple-600' },
  ]

  return (
    <div className="space-y-8">
      {/* Welcome banner */}
      <motion.div {...fadeInUp}>
        <div className="relative overflow-hidden bg-gradient-to-l from-indigo-600/20 via-purple-600/10 to-transparent border border-white/[0.08] rounded-2xl p-8">
          <div className="absolute top-0 left-0 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl" />
          <div className="absolute bottom-0 right-0 w-48 h-48 bg-purple-500/10 rounded-full blur-3xl" />
          <div className="relative">
            <h1 className="text-2xl md:text-3xl font-bold text-white mb-2">لوحة التحكم</h1>
            <p className="text-slate-400 text-lg">نظرة شاملة على أداء طلابك وفصولك</p>
          </div>
        </div>
      </motion.div>

      {/* Stats grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        {stats.map((stat, index) => {
          const Icon = stat.icon
          return (
            <motion.div
              key={stat.label}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: index * 0.1 }}
            >
              <div className={`relative overflow-hidden bg-white/[0.04] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6 hover:border-white/[0.15] transition-all group ${stat.glow} hover:shadow-xl`}>
                <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-l opacity-60 ${stat.gradient}" />
                <div className="flex items-start justify-between mb-4">
                  <div className={`p-3 rounded-xl bg-gradient-to-br ${stat.gradient} shadow-lg ${stat.glow}`}>
                    <Icon size={22} className="text-white" />
                  </div>
                  <div className={`flex items-center gap-1 text-xs font-medium ${stat.positive ? 'text-emerald-400' : 'text-red-400'}`}>
                    {stat.positive ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
                    {stat.change}
                  </div>
                </div>
                <div className="text-3xl font-bold text-white mb-1" style={{ fontFamily: "'JetBrains Mono', monospace" }}>
                  {stat.value}{stat.suffix || ''}
                </div>
                <p className="text-sm text-slate-400">{stat.label}</p>
              </div>
            </motion.div>
          )
        })}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3 }}
        >
          <div className="bg-white/[0.04] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6">
            <div className="flex items-center gap-3 mb-6">
              <div className="p-2 rounded-lg bg-indigo-500/10">
                <BarChart3 size={18} className="text-indigo-400" />
              </div>
              <h2 className="text-sm font-bold text-white">الحضور الأسبوعي</h2>
            </div>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData}>
                  <defs>
                    <linearGradient id="colorAttendance" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#6366f1" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                  <XAxis dataKey="name" stroke="#64748b" fontSize={11} />
                  <YAxis stroke="#64748b" fontSize={11} />
                  <Tooltip
                    contentStyle={{
                      background: 'rgba(15,23,42,0.95)',
                      border: '1px solid rgba(255,255,255,0.1)',
                      borderRadius: '12px',
                      color: '#fff',
                      fontSize: '12px',
                      backdropFilter: 'blur(10px)',
                    }}
                  />
                  <Area type="monotone" dataKey="attendance" stroke="#818cf8" strokeWidth={2.5} fill="url(#colorAttendance)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.4 }}
        >
          <div className="bg-white/[0.04] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6">
            <div className="flex items-center gap-3 mb-6">
              <div className="p-2 rounded-lg bg-violet-500/10">
                <Users size={18} className="text-violet-400" />
              </div>
              <h2 className="text-sm font-bold text-white">الطلاب الجدد</h2>
            </div>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                  <XAxis dataKey="name" stroke="#64748b" fontSize={11} />
                  <YAxis stroke="#64748b" fontSize={11} />
                  <Tooltip
                    contentStyle={{
                      background: 'rgba(15,23,42,0.95)',
                      border: '1px solid rgba(255,255,255,0.1)',
                      borderRadius: '12px',
                      color: '#fff',
                      fontSize: '12px',
                      backdropFilter: 'blur(10px)',
                    }}
                  />
                  <Bar dataKey="students" fill="url(#barGradient)" radius={[6, 6, 0, 0]} />
                  <defs>
                    <linearGradient id="barGradient" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#818cf8" />
                      <stop offset="100%" stopColor="#6366f1" />
                    </linearGradient>
                  </defs>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Quick Actions */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.5 }}
      >
        <div className="bg-white/[0.04] backdrop-blur-sm border border-white/[0.08] rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 rounded-lg bg-amber-500/10">
              <Sparkles size={18} className="text-amber-400" />
            </div>
            <h2 className="text-sm font-bold text-white">إجراءات سريعة</h2>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {quickActions.map((action, i) => {
              const Icon = action.icon
              return (
                <motion.a
                  key={action.label}
                  href={action.href}
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.3, delay: 0.6 + i * 0.1 }}
                  className="flex flex-col items-center gap-3 p-6 bg-white/[0.03] border border-white/[0.08] rounded-2xl hover:border-white/[0.2] hover:bg-white/[0.06] transition-all group"
                >
                  <div className={`p-3 rounded-xl bg-gradient-to-br ${action.gradient} shadow-lg group-hover:scale-110 transition-transform`}>
                    <Icon size={24} className="text-white" />
                  </div>
                  <span className="text-sm font-medium text-white">{action.label}</span>
                </motion.a>
              )
            })}
          </div>
        </div>
      </motion.div>
    </div>
  )
}
