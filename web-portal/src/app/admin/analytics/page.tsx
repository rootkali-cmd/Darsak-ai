'use client'

import { motion } from 'framer-motion'
import { useQuery } from '@tanstack/react-query'
import {
  BarChart2,
  Download,
  AlertTriangle,
  Monitor,
  Smartphone,
  Activity,
  Users,
  XCircle,
  CheckCircle,
} from 'lucide-react'
import { api } from '@/lib/api'
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
} from 'recharts'
import { useState, useEffect } from 'react'

const COLORS = ['#ff003c', '#00f3ff', '#00ff88', '#f59e0b', '#8b5cf6', '#ec4899']

function SkeletonCard() {
  return <div className="card p-6 animate-pulse"><div className="h-4 w-24 bg-gray-700 mb-4" /><div className="h-8 w-16 bg-gray-700" /></div>
}

function SkeletonChart() {
  return <div className="card p-6 animate-pulse"><div className="h-4 w-32 bg-gray-700 mb-4" /><div className="h-64 bg-gray-700" /></div>
}

export default function AdminAnalyticsPage() {
  const [now, setNow] = useState(Date.now())

  useEffect(() => {
    const interval = setInterval(() => setNow(Date.now()), 30000)
    return () => clearInterval(interval)
  }, [])

  const { data: overview, isLoading: loadingOverview } = useQuery({
    queryKey: ['analytics-overview', now],
    queryFn: () => api.get('/analytics/overview').then(r => r.data),
    refetchInterval: 30000,
  })

  const { data: updates, isLoading: loadingUpdates } = useQuery({
    queryKey: ['analytics-updates', now],
    queryFn: () => api.get('/analytics/updates').then(r => r.data),
    refetchInterval: 30000,
  })

  const { data: crashes, isLoading: loadingCrashes } = useQuery({
    queryKey: ['analytics-crashes', now],
    queryFn: () => api.get('/analytics/crashes').then(r => r.data),
    refetchInterval: 30000,
  })

  const { data: platforms, isLoading: loadingPlatforms } = useQuery({
    queryKey: ['analytics-platforms', now],
    queryFn: () => api.get('/analytics/platforms').then(r => r.data),
    refetchInterval: 60000,
  })

  const { data: versionsData, isLoading: loadingVersions } = useQuery({
    queryKey: ['analytics-versions', now],
    queryFn: () => api.get('/analytics/versions-usage').then(r => r.data),
    refetchInterval: 60000,
  })

  const { data: channelsData, isLoading: loadingChannels } = useQuery({
    queryKey: ['analytics-channels', now],
    queryFn: () => api.get('/analytics/channels').then(r => r.data),
    refetchInterval: 60000,
  })

  const { data: eventsData, isLoading: loadingEvents } = useQuery({
    queryKey: ['analytics-events', now],
    queryFn: () => api.get('/analytics/events', { params: { limit: 30 } }).then(r => r.data),
    refetchInterval: 30000,
  })

  const statCards = [
    {
      label: 'المستخدمين النشطين',
      value: overview?.active_users ?? 0,
      icon: Users,
      color: '#ff003c',
      loading: loadingOverview,
    },
    {
      label: 'نسبة نجاح التحديث',
      value: `${overview?.update_success_rate ?? 0}%`,
      icon: CheckCircle,
      color: '#00ff88',
      loading: loadingOverview,
    },
    {
      label: 'نسبة الأعطال',
      value: `${overview?.crash_rate ?? 0}%`,
      icon: XCircle,
      color: overview?.crash_rate > 5 ? '#ff003c' : '#f59e0b',
      loading: loadingOverview,
    },
    {
      label: 'التثبيتات الفاشلة',
      value: overview?.failed_installs ?? 0,
      icon: AlertTriangle,
      color: '#ff003c',
      loading: loadingOverview,
    },
  ]

  const platformData = platforms?.platforms?.map((p: { key: string; count: number }) => ({
    name: p.key === 'windows' ? 'Windows' : p.key === 'android' ? 'Android' : p.key === 'linux' ? 'Linux' : p.key,
    value: p.count,
  })) ?? []

  const versionChartData = versionsData?.versions?.slice(0, 10).map((v: { key: string; count: number }) => ({
    name: v.key,
    count: v.count,
  })) ?? []

  const channelChartData = channelsData?.channels?.map((c: { key: string; count: number }) => ({
    name: c.key === 'stable' ? 'Stable' : c.key === 'beta' ? 'Beta' : c.key === 'dev' ? 'Dev' : c.key === 'nightly' ? 'Nightly' : c.key,
    value: c.count,
  })) ?? []

  const updateSteps = [
    { name: 'فحص', value: updates?.checks ?? 0, fill: '#6366f1' },
    { name: 'متاح', value: updates?.available ?? 0, fill: '#f59e0b' },
    { name: 'بدأ', value: updates?.started ?? 0, fill: '#3b82f6' },
    { name: 'تم التحميل', value: updates?.downloaded ?? 0, fill: '#8b5cf6' },
    { name: 'مثبت', value: updates?.installed ?? 0, fill: '#00ff88' },
    { name: 'فشل', value: updates?.failed ?? 0, fill: '#ff003c' },
  ]

  return (
    <div className="space-y-8">
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
        <h1 className="text-2xl md:text-3xl font-bold mb-2">لوحة المراقبة</h1>
        <p className="text-[var(--text-muted)]">إحصائيات وتحليلات شاملة لكل التطبيقات</p>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        {statCards.map((stat, i) => {
          const Icon = stat.icon
          return (
            <motion.div key={stat.label} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.1 }}>
              {stat.loading ? <SkeletonCard /> : (
                <div className="card p-5">
                  <div className="flex items-start justify-between mb-3">
                    <div className="p-2" style={{ background: `${stat.color}20` }}>
                      <Icon size={20} style={{ color: stat.color }} />
                    </div>
                  </div>
                  <div className="text-2xl font-bold mb-0.5" style={{ fontFamily: "'JetBrains Mono', monospace" }}>{stat.value}</div>
                  <p className="text-xs text-[var(--text-muted)]">{stat.label}</p>
                </div>
              )}
            </motion.div>
          )
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
          {loadingUpdates ? <SkeletonChart /> : (
            <div className="card p-5">
              <h2 className="text-sm font-bold text-[var(--text-muted)] mb-5">مسار التحديثات</h2>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={updateSteps} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="var(--card-border)" />
                    <XAxis type="number" stroke="var(--text-muted)" fontSize={11} />
                    <YAxis type="category" dataKey="name" stroke="var(--text-muted)" fontSize={11} width={60} />
                    <Tooltip contentStyle={{ background: 'var(--card-bg)', border: '1px solid var(--card-border)', color: 'var(--text)', fontSize: '12px' }} />
                    <Bar dataKey="value" radius={[0, 2, 2, 0]}>
                      {updateSteps.map((entry, idx) => <Cell key={idx} fill={entry.fill} />)}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }}>
          {loadingPlatforms ? <SkeletonChart /> : (
            <div className="card p-5">
              <h2 className="text-sm font-bold text-[var(--text-muted)] mb-5">توزيع المنصات</h2>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={platformData.length > 0 ? platformData : [{ name: 'Windows', value: 1 }, { name: 'Android', value: 1 }]} cx="50%" cy="50%" innerRadius={60} outerRadius={90} paddingAngle={5} dataKey="value">
                      {platformData.map((_: any, idx: number) => <Cell key={idx} fill={COLORS[idx % COLORS.length]} />)}
                    </Pie>
                    <Tooltip contentStyle={{ background: 'var(--card-bg)', border: '1px solid var(--card-border)', color: 'var(--text)', fontSize: '12px' }} />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </motion.div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4 }}>
          {loadingVersions ? <SkeletonChart /> : (
            <div className="card p-5">
              <h2 className="text-sm font-bold text-[var(--text-muted)] mb-5">الإصدارات الأكثر استخداماً</h2>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={versionChartData.length > 0 ? versionChartData : [{ name: '1.2.0', count: 1 }]} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="var(--card-border)" />
                    <XAxis type="number" stroke="var(--text-muted)" fontSize={11} />
                    <YAxis type="category" dataKey="name" stroke="var(--text-muted)" fontSize={10} width={70} />
                    <Tooltip contentStyle={{ background: 'var(--card-bg)', border: '1px solid var(--card-border)', color: 'var(--text)', fontSize: '12px' }} />
                    <Bar dataKey="count" fill="#00f3ff" radius={[0, 2, 2, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.5 }}>
          {loadingChannels ? <SkeletonChart /> : (
            <div className="card p-5">
              <h2 className="text-sm font-bold text-[var(--text-muted)] mb-5">قنوات التحديث</h2>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={channelChartData.length > 0 ? channelChartData : [{ name: 'Stable', value: 1 }]} cx="50%" cy="50%" outerRadius={80} dataKey="value" label={({ name, percent }: { name: string; percent: number }) => `${name} ${(percent * 100).toFixed(0)}%`}>
                      {channelChartData.map((_: any, idx: number) => <Cell key={idx} fill={COLORS[idx % COLORS.length]} />)}
                    </Pie>
                    <Tooltip contentStyle={{ background: 'var(--card-bg)', border: '1px solid var(--card-border)', color: 'var(--text)', fontSize: '12px' }} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.6 }}>
          {loadingCrashes ? <SkeletonChart /> : (
            <div className="card p-5">
              <h2 className="text-sm font-bold text-[var(--text-muted)] mb-5">حالة الأعطال</h2>
              <div className="space-y-5">
                <div>
                  <p className="text-xs text-[var(--text-muted)] mb-1">إجمالي الأعطال</p>
                  <p className="text-2xl font-bold">{crashes?.total_crashes ?? 0}</p>
                </div>
                <div>
                  <p className="text-xs text-[var(--text-muted)] mb-1">نسبة الأعطال لكل جلسة</p>
                  <p className={`text-2xl font-bold ${(crashes?.crash_rate_per_session ?? 0) > 5 ? 'text-red-500' : 'text-green-500'}`}>
                    {crashes?.crash_rate_per_session ?? 0}%
                  </p>
                </div>
              </div>
            </div>
          )}
        </motion.div>
      </div>

      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.7 }}>
        {loadingEvents ? <SkeletonChart /> : (
          <div className="card p-5">
            <h2 className="text-sm font-bold text-[var(--text-muted)] mb-5">آخر الأحداث</h2>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b" style={{ borderColor: 'var(--card-border)' }}>
                    <th className="text-right p-2 text-[var(--text-muted)] font-medium">الحدث</th>
                    <th className="text-right p-2 text-[var(--text-muted)] font-medium">المنصة</th>
                    <th className="text-right p-2 text-[var(--text-muted)] font-medium">الإصدار</th>
                    <th className="text-right p-2 text-[var(--text-muted)] font-medium">التوقيت</th>
                  </tr>
                </thead>
                <tbody>
                  {(eventsData?.events ?? []).slice(0, 15).map((event: any, idx: number) => (
                    <tr key={idx} className="border-b hover:bg-[rgba(0,0,0,0.02)]" style={{ borderColor: 'var(--card-border)' }}>
                      <td className="p-2">
                        <span className={`inline-flex items-center gap-1 px-2 py-0.5 text-xs ${
                          event.event?.includes('fail') || event.event?.includes('error') || event.event?.includes('crash') ? 'bg-red-500/10 text-red-500' : event.event?.includes('installed') || event.event?.includes('success') ? 'bg-green-500/10 text-green-500' : 'bg-[rgba(0,243,255,0.1)] text-[var(--accent-2)]'
                        }`}>{event.event}</span>
                      </td>
                      <td className="p-2 text-[var(--text-muted)]">{event.platform}</td>
                      <td className="p-2 text-[var(--text-muted)]">{event.version}</td>
                      <td className="p-2 text-[var(--text-muted)] text-xs">{event.timestamp ? new Date(event.timestamp).toLocaleString('ar-EG') : '-'}</td>
                    </tr>
                  ))}
                  {(!eventsData?.events || eventsData.events.length === 0) && <tr><td colSpan={4} className="p-4 text-center text-[var(--text-muted)]">لا توجد أحداث بعد</td></tr>}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </motion.div>
    </div>
  )
}
